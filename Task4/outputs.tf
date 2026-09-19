###############################################################################
# Ключевые параметры развёрнутой инфраструктуры.
#
# Выводится то, что нужно смежным командам: адрес входа, адреса узлов, имя
# бакета и идентификаторы сети для следующих шагов (Ansible, CI/CD, настройка
# домена). Секреты не выводятся в открытом виде.
###############################################################################

output "network_id" {
  description = "Идентификатор сети платформы"
  value       = yandex_vpc_network.platform.id
}

output "subnet_ids" {
  description = "Идентификаторы подсетей по зонам доступности"
  value       = { for zone, subnet in yandex_vpc_subnet.private : zone => subnet.id }
}

output "nat_gateway_id" {
  description = "Идентификатор NAT-шлюза, через который узлы выходят в интернет"
  value       = yandex_vpc_gateway.nat.id
}

output "bastion_public_ip" {
  description = "Публичный адрес бастиона — единственная точка входа по SSH"
  value = one([
    for name, node in yandex_compute_instance.node :
    node.network_interface[0].nat_ip_address if var.nodes[name].public_ip
  ])
}

output "node_internal_ips" {
  description = "Внутренние адреса узлов платформы"
  value = {
    for name, node in yandex_compute_instance.node :
    name => node.network_interface[0].ip_address
  }
}

output "node_summary" {
  description = "Состав платформы: роль, зона, ресурсы и диски"
  value = {
    for name, node in var.nodes : name => format(
      "%s | %s | %d vCPU (%d%%) | %d GB RAM | boot %d GB %s | data %s",
      name,
      node.zone,
      node.cores,
      node.core_fraction,
      node.memory_gb,
      node.boot_disk_size_gb,
      node.boot_disk_type,
      node.data_disk_size_gb > 0 ? format("%d GB %s", node.data_disk_size_gb, node.data_disk_type) : "—"
    )
  }
}

output "portal_endpoint" {
  description = "Точка входа в портал самообслуживания"
  value = one(flatten([
    for listener in yandex_lb_network_load_balancer.portal.listener : [
      for spec in listener.external_address_spec : "https://${spec.address}"
    ]
  ]))
}

output "lakehouse_bucket" {
  description = "Имя бакета объектного хранилища под lakehouse"
  value       = yandex_storage_bucket.lakehouse.bucket
}

output "lakehouse_endpoint" {
  description = "S3-совместимая точка доступа к бакету lakehouse"
  value       = "https://storage.yandexcloud.net/${yandex_storage_bucket.lakehouse.bucket}"
}

output "platform_service_account_id" {
  description = "Идентификатор сервисного аккаунта узлов платформы"
  value       = yandex_iam_service_account.platform.id
}

output "lakehouse_access_key_id" {
  description = "Идентификатор статического ключа доступа к бакету"
  value       = yandex_iam_service_account_static_access_key.lakehouse.access_key
}

# Секретная часть ключа помечена sensitive: Terraform не покажет её в выводе
# apply и в логах CI. Забрать значение можно только явной командой
# `terraform output -raw lakehouse_secret_key` — и дальше положить в Vault.
output "lakehouse_secret_key" {
  description = "Секретная часть ключа доступа к бакету"
  value       = yandex_iam_service_account_static_access_key.lakehouse.secret_key
  sensitive   = true
}

output "ssh_command" {
  description = "Готовая команда подключения к бастиону"
  value = format(
    "ssh %s@%s",
    var.ssh_user,
    one([
      for name, node in yandex_compute_instance.node :
      node.network_interface[0].nat_ip_address if var.nodes[name].public_ip
    ])
  )
}
