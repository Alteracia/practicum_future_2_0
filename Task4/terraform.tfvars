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

# Имя бакета глобально уникально — добавьте свой суффикс.
lakehouse_bucket_name   = "future20-dev-lakehouse-0001"
cold_storage_after_days = 90

portal_node        = "portal"
portal_target_port = 8080

###############################################################################
# Состав платформы.
#
# Размеры подобраны под среду dev: проверить конфигурацию и цифры первых
# витрин. Для prod меняются только значения в этом файле — main.tf остаётся
# тем же. Обоснование размеров — в justification.md.
###############################################################################

nodes = {
  bastion = {
    description       = "Точка входа по SSH, единственный узел с публичным адресом"
    zone              = "ru-central1-a"
    cores             = 2
    memory_gb         = 2
    core_fraction     = 20
    boot_disk_size_gb = 20
    public_ip         = true
  }

  dremio = {
    description       = "Движок запросов и семантический слой над Iceberg"
    zone              = "ru-central1-a"
    cores             = 8
    memory_gb         = 32
    boot_disk_size_gb = 40
    data_disk_size_gb = 200
    data_disk_type    = "network-ssd"
  }

  airflow = {
    description       = "Оркестрация загрузок и трансформаций"
    zone              = "ru-central1-b"
    cores             = 4
    memory_gb         = 16
    boot_disk_size_gb = 40
    data_disk_size_gb = 100
    data_disk_type    = "network-ssd"
  }

  portal = {
    description       = "Портал самообслуживания: каталог витрин и конструктор отчётов"
    zone              = "ru-central1-a"
    cores             = 4
    memory_gb         = 8
    boot_disk_size_gb = 30
  }

  keycloak = {
    description       = "Единый вход и ролевая модель доступа к витринам"
    zone              = "ru-central1-b"
    cores             = 2
    memory_gb         = 4
    core_fraction     = 50
    boot_disk_size_gb = 30
    data_disk_size_gb = 20
    data_disk_type    = "network-hdd"
  }
}
