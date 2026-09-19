###############################################################################
# Значения переменных для среды dev.
#
# В файле нет секретов: cloud_id и folder_id — это идентификаторы, а не ключи;
# SSH-ключ указан публичной частью. Авторизация Terraform в облаке идёт через
# переменную окружения YC_TOKEN или ключ сервисного аккаунта — см. README.md.
#
# ВНИМАНИЕ: перед запуском подставьте идентификаторы своего каталога и свой
# SSH-ключ. Значения ниже — заполнители.
###############################################################################

cloud_id  = "b1gxxxxxxxxxxxxxxxxx" # заполнитель: ваш cloud_id
folder_id = "b1gyyyyyyyyyyyyyyyyy" # заполнитель: ваш folder_id

project      = "future20"
environment  = "dev"
default_zone = "ru-central1-a"

# Две зоны доступности: размещение узлов в разных зонах — основа требования
# бизнеса к отказоустойчивости и гео-распределённому развёртыванию.
subnets = {
  "ru-central1-a" = "10.10.1.0/24"
  "ru-central1-b" = "10.10.2.0/24"
}

# Сети головного офиса и клиник. Доступ из интернета целиком запрещён
# валидацией переменной.
admin_cidr_blocks = [
  "10.200.0.0/16", # корпоративная сеть головного офиса
  "10.201.0.0/16", # сеть клиник
]

ssh_user = "ubuntu"

# Заполнитель. Подставьте содержимое своего ~/.ssh/id_ed25519.pub
ssh_public_key = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIREPLACEWITHYOUROWNPUBLICKEY00000000000 platform-admin"

# Имя бакета уникально во всём Yandex Object Storage — замените суффикс на свой.
lakehouse_bucket_name   = "future20-dev-lakehouse-0001"
cold_storage_after_days = 90

# Среда dev сносится одной командой после проверки, поэтому terraform destroy
# разрешено удалить бакет вместе с содержимым.
bucket_force_destroy = true

portal_node        = "portal"
portal_target_port = 8080

###############################################################################
# Состав платформы.
#
# Итого: 8 vCPU, 18 ГБ RAM, 80 ГБ network-hdd, 20 ГБ network-ssd.
# Обоснование размеров — в justification.md.
###############################################################################

nodes = {
  bastion = {
    description       = "Точка входа по SSH, единственный узел с публичным адресом"
    zone              = "ru-central1-a"
    cores             = 2
    memory_gb         = 2
    core_fraction     = 20
    boot_disk_type    = "network-hdd"
    boot_disk_size_gb = 20
    public_ip         = true
  }

  dremio = {
    description       = "Движок запросов и семантический слой над Iceberg"
    zone              = "ru-central1-a"
    cores             = 2
    memory_gb         = 8
    boot_disk_type    = "network-hdd"
    boot_disk_size_gb = 20
    data_disk_size_gb = 20
    data_disk_type    = "network-ssd"
  }

  airflow = {
    description       = "Оркестрация загрузок и трансформаций"
    zone              = "ru-central1-b"
    cores             = 2
    memory_gb         = 4
    core_fraction     = 20
    boot_disk_type    = "network-hdd"
    boot_disk_size_gb = 20
  }

  portal = {
    description       = "Портал самообслуживания: каталог витрин и конструктор отчётов"
    zone              = "ru-central1-a"
    cores             = 2
    memory_gb         = 4
    core_fraction     = 20
    boot_disk_type    = "network-hdd"
    boot_disk_size_gb = 20
  }
}
