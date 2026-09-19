###############################################################################
# Автотесты конфигурации.
#
# mock_provider подменяет провайдер Yandex Cloud: terraform test прогоняет
# настоящие plan и apply по графу ресурсов, но никуда не ходит и ничего не
# создаёт. Это позволяет проверить конфигурацию в CI на каждом merge request,
# не имея облачных учётных данных и не платя за ресурсы.
#
# Запуск:  terraform test
###############################################################################

mock_provider "yandex" {}

variables {
  cloud_id  = "b1gtest00000000000000"
  folder_id = "b1gtest11111111111111"

  project     = "future20"
  environment = "dev"

  subnets = {
    "ru-central1-a" = "10.10.1.0/24"
    "ru-central1-b" = "10.10.2.0/24"
  }

  admin_cidr_blocks = ["10.200.0.0/16", "10.201.0.0/16"]

  ssh_public_key        = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAITESTKEYFORAUTOMATEDTESTSONLY000000000 test"
  lakehouse_bucket_name = "future20-test-lakehouse"

  nodes = {
    bastion = {
      description   = "Точка входа по SSH"
      zone          = "ru-central1-a"
      cores         = 2
      memory_gb     = 2
      core_fraction = 20
      public_ip     = true
    }
    dremio = {
      description       = "Движок запросов"
      zone              = "ru-central1-a"
      cores             = 8
      memory_gb         = 32
      data_disk_size_gb = 200
    }
    portal = {
      description = "Портал самообслуживания"
      zone        = "ru-central1-b"
      cores       = 4
      memory_gb   = 8
    }
  }
}

###############################################################################
# 1. Сеть и NAT
###############################################################################

run "network_and_nat" {
  command = plan

  assert {
    condition     = length(yandex_vpc_subnet.private) == length(var.subnets)
    error_message = "На каждую зону из subnets должна создаваться ровно одна подсеть."
  }

  assert {
    condition     = length(yandex_vpc_route_table.private.static_route) == 1
    error_message = "В таблице маршрутов должен быть один статический маршрут."
  }

  assert {
    condition = alltrue([
      for route in yandex_vpc_route_table.private.static_route :
      route.destination_prefix == "0.0.0.0/0"
    ])
    error_message = "Маршрут по умолчанию должен вести весь исходящий трафик на NAT-шлюз."
  }
}

###############################################################################
# 2. Публичные адреса: nat = true допустим только на бастионе
###############################################################################

run "single_public_node" {
  command = plan

  assert {
    condition = length([
      for name, node in yandex_compute_instance.node :
      name if node.network_interface[0].nat
    ]) == 1
    error_message = "Публичный адрес должен быть ровно у одного узла."
  }

  assert {
    condition     = yandex_compute_instance.node["bastion"].network_interface[0].nat
    error_message = "Публичный адрес должен быть именно у бастиона."
  }

  assert {
    condition     = !yandex_compute_instance.node["dremio"].network_interface[0].nat
    error_message = "Узел dremio не должен иметь публичного адреса — только выход через NAT."
  }
}

###############################################################################
# 3. Диски данных создаются только там, где заявлены
###############################################################################

run "data_disks" {
  command = plan

  assert {
    condition     = length(yandex_compute_disk.data) == 1
    error_message = "Диск данных должен создаваться только для узлов с data_disk_size_gb > 0."
  }

  assert {
    condition     = yandex_compute_disk.data["dremio"].size == 200
    error_message = "Размер диска данных dremio должен совпадать с заявленным в nodes."
  }

  assert {
    condition = alltrue([
      for disk in yandex_compute_disk.data : disk.labels["managed-by"] == "terraform"
    ])
    error_message = "Все ресурсы должны нести метки для разнесения стоимости."
  }
}

###############################################################################
# 4. Полный apply на мок-провайдере
###############################################################################

run "apply_platform" {
  command = apply

  assert {
    condition     = yandex_storage_bucket.lakehouse.bucket == var.lakehouse_bucket_name
    error_message = "Имя бакета должно браться из переменной."
  }

  assert {
    condition     = length(yandex_compute_instance.node) == length(var.nodes)
    error_message = "Должна создаваться виртуальная машина на каждый узел из карты nodes."
  }

  assert {
    condition     = length(yandex_resourcemanager_folder_iam_member.platform) == length(var.service_account_roles)
    error_message = "Сервисному аккаунту должны выдаваться все перечисленные роли."
  }

  assert {
    condition     = yandex_lb_network_load_balancer.portal.name == "future20-dev-portal-lb"
    error_message = "Имя балансировщика должно собираться из префикса проекта и среды."
  }

  assert {
    condition     = length(output.node_internal_ips) == length(var.nodes)
    error_message = "Вывод должен содержать адрес каждого узла."
  }

  # Идентификатор таблицы маршрутов известен только после создания,
  # поэтому привязка подсетей проверяется на apply, а не на plan.
  assert {
    condition = alltrue([
      for subnet in yandex_vpc_subnet.private :
      subnet.route_table_id == yandex_vpc_route_table.private.id
    ])
    error_message = "Каждая подсеть должна быть привязана к таблице маршрутов с NAT."
  }
}

###############################################################################
# 5. Отрицательные проверки: валидации переменных должны срабатывать
###############################################################################

run "reject_open_ssh_to_internet" {
  command = plan

  variables {
    admin_cidr_blocks = ["0.0.0.0/0"]
  }

  expect_failures = [var.admin_cidr_blocks]
}

run "reject_second_public_node" {
  command = plan

  variables {
    nodes = {
      bastion = {
        description = "Бастион"
        zone        = "ru-central1-a"
        cores       = 2
        memory_gb   = 2
        public_ip   = true
      }
      portal = {
        description = "Портал с ошибочно открытым публичным адресом"
        zone        = "ru-central1-a"
        cores       = 4
        memory_gb   = 8
        public_ip   = true
      }
    }
  }

  expect_failures = [var.nodes]
}

run "reject_invalid_ssh_key" {
  command = plan

  variables {
    ssh_public_key = "не-ключ-а-просто-строка"
  }

  expect_failures = [var.ssh_public_key]
}
