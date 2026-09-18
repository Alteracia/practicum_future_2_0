###############################################################################
# Переменные конфигурации.
#
# Каждая среда (dev / stage / prod) и каждый домен получают свой .tfvars —
# сам код при этом не меняется. Это и есть механизм, которым один и тот же
# ландшафт воспроизводится столько раз, сколько нужно бизнесу.
###############################################################################

variable "cloud_id" {
  description = "Идентификатор облака Yandex Cloud (создаётся вне Terraform)"
  type        = string
}

variable "folder_id" {
  description = "Идентификатор каталога, в котором разворачивается платформа"
  type        = string
}

variable "project" {
  description = "Короткое имя проекта, используется как префикс имён ресурсов"
  type        = string
  default     = "future20"

  validation {
    condition     = can(regex("^[a-z][a-z0-9-]{1,18}$", var.project))
    error_message = "Префикс: строчные латинские буквы, цифры и дефис, от 2 до 19 символов."
  }
}

variable "environment" {
  description = "Среда развёртывания"
  type        = string
  default     = "dev"

  validation {
    condition     = contains(["dev", "stage", "prod"], var.environment)
    error_message = "Допустимые значения: dev, stage, prod."
  }
}

variable "default_zone" {
  description = "Зона доступности по умолчанию для провайдера"
  type        = string
  default     = "ru-central1-a"
}

variable "image_family" {
  description = "Семейство образов ОС для загрузочных дисков"
  type        = string
  default     = "ubuntu-2204-lts"
}

variable "subnets" {
  description = "Приватные подсети: ключ — зона доступности, значение — CIDR"
  type        = map(string)

  default = {
    "ru-central1-a" = "10.10.1.0/24"
    "ru-central1-b" = "10.10.2.0/24"
  }

  validation {
    condition     = length(var.subnets) > 0
    error_message = "Нужна хотя бы одна подсеть."
  }
}

variable "admin_cidr_blocks" {
  description = "Сети, из которых разрешён SSH на бастион и доступ к порталу"
  type        = list(string)

  validation {
    condition     = !contains(var.admin_cidr_blocks, "0.0.0.0/0")
    error_message = "Открывать доступ всему интернету нельзя: укажите корпоративные сети."
  }
}

variable "ssh_user" {
  description = "Пользователь ОС, которому прописывается SSH-ключ"
  type        = string
  default     = "ubuntu"
}

variable "ssh_public_key" {
  description = "Публичная часть SSH-ключа администраторов платформы"
  type        = string

  validation {
    condition     = can(regex("^(ssh-ed25519|ssh-rsa|ecdsa-sha2-) ", var.ssh_public_key))
    error_message = "Ожидается публичный ключ в формате OpenSSH (ssh-ed25519, ssh-rsa, ecdsa-sha2-*)."
  }
}

variable "service_account_roles" {
  description = "Роли сервисного аккаунта узлов платформы в каталоге"
  type        = list(string)

  default = [
    "storage.editor",    # чтение и запись витрин в бакете lakehouse
    "monitoring.editor", # отправка метрик
    "logging.writer",    # отправка логов
    "kms.keys.encrypterDecrypter",
  ]
}

variable "lakehouse_bucket_name" {
  description = "Имя бакета объектного хранилища под lakehouse (глобально уникально)"
  type        = string

  validation {
    condition     = can(regex("^[a-z0-9][a-z0-9.-]{2,62}$", var.lakehouse_bucket_name))
    error_message = "Имя бакета: строчные латинские буквы, цифры, точка и дефис, от 3 до 63 символов."
  }
}

variable "cold_storage_after_days" {
  description = "Через сколько дней сырой слой переводится в холодное хранение"
  type        = number
  default     = 90

  validation {
    condition     = var.cold_storage_after_days >= 1
    error_message = "Значение должно быть не меньше одного дня."
  }
}

variable "portal_node" {
  description = "Ключ узла из nodes, на который балансировщик направляет трафик портала"
  type        = string
  default     = "portal"
}

variable "portal_target_port" {
  description = "Порт приложения портала на виртуальной машине"
  type        = number
  default     = 8080
}

variable "nodes" {
  description = <<-EOT
    Узлы платформы. Ключ карты — роль узла, она же попадает в имя ресурсов
    и в метку role. Добавление узла или изменение его размера выполняется
    правкой этой карты в .tfvars, без изменения кода в main.tf.
  EOT

  type = map(object({
    description       = string
    zone              = string
    cores             = number
    memory_gb         = number
    platform_id       = optional(string, "standard-v3")
    core_fraction     = optional(number, 100)
    boot_disk_type    = optional(string, "network-ssd")
    boot_disk_size_gb = optional(number, 30)
    data_disk_type    = optional(string, "network-ssd")
    data_disk_size_gb = optional(number, 0)
    public_ip         = optional(bool, false)
    preemptible       = optional(bool, false)
  }))

  validation {
    condition     = alltrue([for n in var.nodes : contains([5, 20, 50, 100], n.core_fraction)])
    error_message = "core_fraction принимает значения 5, 20, 50 или 100."
  }

  validation {
    condition     = length([for n in var.nodes : n if n.public_ip]) <= 1
    error_message = "Публичный адрес допустим только у одного узла — бастиона."
  }
}
