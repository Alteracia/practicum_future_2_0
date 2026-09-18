###############################################################################
# «Будущее 2.0» — облачный ландшафт платформы данных (Yandex Cloud, IaaS)
#
# Декларативное описание целевого состояния: сеть, NAT, группы безопасности,
# сервисный аккаунт, объектное хранилище lakehouse, виртуальные машины
# платформы данных и балансировщик перед порталом самообслуживания.
#
# Всё, что описано в этом файле, управляется Terraform. Компоненты, которые
# создаются вне Terraform (облако, каталог, backend для состояния, домен,
# установка ПО), перечислены в diagram.png и обоснованы в justification.md.
###############################################################################

terraform {
  required_version = ">= 1.7.0"

  required_providers {
    yandex = {
      source  = "yandex-cloud/yandex"
      version = "~> 0.140"
    }
  }

  # Состояние хранится в Object Storage: файл состояния содержит метаданные
  # инфраструктуры и не должен лежать на машине инженера. Бакет и сервисный
  # аккаунт под backend создаются один раз вручную (bootstrap) — см. README.md.
  #
  # backend "s3" {
  #   endpoints = { s3 = "https://storage.yandexcloud.net" }
  #   bucket    = "future20-tfstate"
  #   region    = "ru-central1"
  #   key       = "platform/terraform.tfstate"
  #
  #   skip_region_validation      = true
  #   skip_credentials_validation = true
  #   skip_requesting_account_id  = true
  #   skip_s3_checksum            = true
  # }
}

provider "yandex" {
  cloud_id  = var.cloud_id
  folder_id = var.folder_id
  zone      = var.default_zone
}

locals {
  prefix = "${var.project}-${var.environment}"

  labels = {
    project     = var.project
    environment = var.environment
    managed-by  = "terraform"
  }
}

# Актуальный образ ОС запрашивается у провайдера, а не фиксируется id-шником:
# идентификаторы образов меняются при выходе обновлений.
data "yandex_compute_image" "ubuntu" {
  family = var.image_family
}

###############################################################################
# Сеть
###############################################################################

resource "yandex_vpc_network" "platform" {
  name        = "${local.prefix}-net"
  description = "Сеть платформы данных «Будущее 2.0»"
  labels      = local.labels
}

# NAT-шлюз даёт исходящий доступ в интернет машинам без публичных адресов:
# обновления пакетов, обращения к внешним API. Входящие соединения при этом
# невозможны — это ключевое свойство для контура с медицинскими и
# финансовыми данными.
resource "yandex_vpc_gateway" "nat" {
  name   = "${local.prefix}-nat-gw"
  labels = local.labels

  shared_egress_gateway {}
}

resource "yandex_vpc_route_table" "private" {
  name       = "${local.prefix}-rt-private"
  network_id = yandex_vpc_network.platform.id
  labels     = local.labels

  static_route {
    destination_prefix = "0.0.0.0/0"
    gateway_id         = yandex_vpc_gateway.nat.id
  }
}

# Подсети создаются по одной на зону доступности. Добавление зоны — это
# добавление строки в terraform.tfvars, а не новый код.
resource "yandex_vpc_subnet" "private" {
  for_each = var.subnets

  name           = "${local.prefix}-subnet-${each.key}"
  description    = "Приватная подсеть платформы, зона ${each.key}"
  zone           = each.key
  network_id     = yandex_vpc_network.platform.id
  v4_cidr_blocks = [each.value]
  route_table_id = yandex_vpc_route_table.private.id
  labels         = local.labels
}

###############################################################################
# Группы безопасности
###############################################################################

resource "yandex_vpc_security_group" "bastion" {
  name        = "${local.prefix}-sg-bastion"
  description = "Единственная точка входа по SSH из корпоративной сети"
  network_id  = yandex_vpc_network.platform.id
  labels      = local.labels

  ingress {
    protocol       = "TCP"
    description    = "SSH из корпоративной сети"
    v4_cidr_blocks = var.admin_cidr_blocks
    port           = 22
  }

  egress {
    protocol       = "ANY"
    description    = "Исходящий трафик"
    v4_cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "yandex_vpc_security_group" "platform" {
  name        = "${local.prefix}-sg-platform"
  description = "Узлы платформы данных: обмен внутри группы, выход через NAT"
  network_id  = yandex_vpc_network.platform.id
  labels      = local.labels

  ingress {
    protocol          = "ANY"
    description       = "Обмен между узлами платформы"
    predefined_target = "self_security_group"
  }

  ingress {
    protocol          = "TCP"
    description       = "SSH только с бастиона"
    security_group_id = yandex_vpc_security_group.bastion.id
    port              = 22
  }

  ingress {
    protocol          = "TCP"
    description       = "Проверки состояния от балансировщика"
    predefined_target = "loadbalancer_healthchecks"
    port              = var.portal_target_port
  }

  # Сетевой балансировщик Yandex Cloud сохраняет исходный адрес клиента,
  # поэтому правило описывает корпоративные сети, а не подсети платформы.
  ingress {
    protocol       = "TCP"
    description    = "Трафик портала от пользователей через балансировщик"
    v4_cidr_blocks = var.admin_cidr_blocks
    port           = var.portal_target_port
  }

  egress {
    protocol       = "ANY"
    description    = "Исходящий трафик через NAT-шлюз"
    v4_cidr_blocks = ["0.0.0.0/0"]
  }
}

###############################################################################
# Сервисный аккаунт и права
###############################################################################

resource "yandex_iam_service_account" "platform" {
  name        = "${local.prefix}-sa"
  description = "Сервисный аккаунт узлов платформы данных"
  folder_id   = var.folder_id
}

resource "yandex_resourcemanager_folder_iam_member" "platform" {
  for_each = toset(var.service_account_roles)

  folder_id = var.folder_id
  role      = each.value
  member    = "serviceAccount:${yandex_iam_service_account.platform.id}"
}

# Ключ для доступа к бакету по протоколу S3 — им пользуются Dremio и Airflow.
resource "yandex_iam_service_account_static_access_key" "lakehouse" {
  service_account_id = yandex_iam_service_account.platform.id
  description        = "Доступ к бакету lakehouse по S3 API"
}

###############################################################################
# Объектное хранилище — физический слой lakehouse
###############################################################################

resource "yandex_storage_bucket" "lakehouse" {
  bucket     = var.lakehouse_bucket_name
  access_key = yandex_iam_service_account_static_access_key.lakehouse.access_key
  secret_key = yandex_iam_service_account_static_access_key.lakehouse.secret_key

  # Публичный доступ закрыт полностью: в бакете лежат финансовые витрины
  # и обезличенные медицинские данные.
  anonymous_access_flags {
    read = false
    list = false
  }

  versioning {
    enabled = true
  }

  # Холодные партиции уезжают в дешёвый класс хранения — на сотнях терабайт
  # это основная статья экономии.
  lifecycle_rule {
    id      = "cold-storage"
    enabled = true

    filter {
      prefix = "bronze/"
    }

    transition {
      days          = var.cold_storage_after_days
      storage_class = "COLD"
    }
  }
}

###############################################################################
# Виртуальные машины платформы
###############################################################################

# Отдельные диски под данные создаются только там, где они заявлены в nodes.
# Диск отделён от машины: пересоздание ВМ не уничтожает данные.
resource "yandex_compute_disk" "data" {
  for_each = { for name, node in var.nodes : name => node if node.data_disk_size_gb > 0 }

  name        = "${local.prefix}-${each.key}-data"
  description = "Диск данных узла ${each.key}"
  type        = each.value.data_disk_type
  zone        = each.value.zone
  size        = each.value.data_disk_size_gb
  labels      = merge(local.labels, { role = each.key })
}

resource "yandex_compute_instance" "node" {
  for_each = var.nodes

  name                      = "${local.prefix}-${each.key}"
  hostname                  = "${local.prefix}-${each.key}"
  description               = each.value.description
  zone                      = each.value.zone
  platform_id               = each.value.platform_id
  service_account_id        = yandex_iam_service_account.platform.id
  allow_stopping_for_update = true
  labels                    = merge(local.labels, { role = each.key })

  resources {
    cores         = each.value.cores
    memory        = each.value.memory_gb
    core_fraction = each.value.core_fraction
  }

  boot_disk {
    initialize_params {
      image_id = data.yandex_compute_image.ubuntu.image_id
      type     = each.value.boot_disk_type
      size     = each.value.boot_disk_size_gb
    }
  }

  # Диск данных подключается, только если он объявлен для этого узла.
  dynamic "secondary_disk" {
    for_each = try([yandex_compute_disk.data[each.key].id], [])

    content {
      disk_id     = secondary_disk.value
      auto_delete = false
    }
  }

  network_interface {
    subnet_id = yandex_vpc_subnet.private[each.value.zone].id

    # nat = true выдаёт машине публичный адрес. Включён только на бастионе;
    # остальные узлы выходят наружу через NAT-шлюз и извне недоступны.
    nat = each.value.public_ip

    security_group_ids = [each.value.public_ip ? yandex_vpc_security_group.bastion.id : yandex_vpc_security_group.platform.id]
  }

  scheduling_policy {
    preemptible = each.value.preemptible
  }

  metadata = {
    ssh-keys           = "${var.ssh_user}:${var.ssh_public_key}"
    serial-port-enable = "1"
  }
}

###############################################################################
# Балансировщик перед порталом самообслуживания
###############################################################################

resource "yandex_lb_target_group" "portal" {
  name      = "${local.prefix}-portal-tg"
  folder_id = var.folder_id
  labels    = local.labels

  # Проверка согласованности переменных: portal_node должен существовать
  # в карте nodes. Ошибка ловится на plan, а не на apply.
  lifecycle {
    precondition {
      condition     = contains(keys(var.nodes), var.portal_node)
      error_message = "portal_node = \"${var.portal_node}\" отсутствует в карте nodes."
    }
  }

  target {
    subnet_id = yandex_vpc_subnet.private[var.nodes[var.portal_node].zone].id
    address   = yandex_compute_instance.node[var.portal_node].network_interface[0].ip_address
  }
}

resource "yandex_lb_network_load_balancer" "portal" {
  name      = "${local.prefix}-portal-lb"
  folder_id = var.folder_id
  labels    = local.labels

  listener {
    name        = "https"
    port        = 443
    target_port = var.portal_target_port

    external_address_spec {
      ip_version = "ipv4"
    }
  }

  attached_target_group {
    target_group_id = yandex_lb_target_group.portal.id

    healthcheck {
      name                = "portal-http"
      interval            = 5
      timeout             = 2
      healthy_threshold   = 2
      unhealthy_threshold = 3

      http_options {
        port = var.portal_target_port
        path = "/healthz"
      }
    }
  }
}
