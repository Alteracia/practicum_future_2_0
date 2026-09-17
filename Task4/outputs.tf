output "network_id" {
  description = "Terraform-managed VPC network."
  value       = yandex_vpc_network.sandbox.id
}

output "subnet_id" {
  description = "Subnet in the selected availability zone."
  value       = yandex_vpc_subnet.sandbox.id
}

output "security_group_id" {
  description = "Group restricting inbound access to SSH from admin_cidr."
  value       = yandex_vpc_security_group.sandbox.id
}

output "vm_id" {
  description = "Created virtual machine ID."
  value       = yandex_compute_instance.sandbox.id
}

output "boot_disk_id" {
  description = "Separately managed boot disk; destroy still deletes it."
  value       = yandex_compute_disk.boot.id
}

output "private_ip" {
  description = "VM address within the VPC."
  value       = yandex_compute_instance.sandbox.network_interface[0].ip_address
}

output "public_ip" {
  description = "Dynamic IPv4 assigned through one-to-one NAT."
  value       = yandex_compute_instance.sandbox.network_interface[0].nat_ip_address
}

output "ssh_command" {
  description = "Run from admin_cidr using the matching local private key or SSH agent."
  value       = "ssh ${var.ssh_user}@${yandex_compute_instance.sandbox.network_interface[0].nat_ip_address}"
}

output "resolved_image_id" {
  description = "Record as image_id in local.auto.tfvars to pin the selected image."
  value       = yandex_compute_disk.boot.image_id
}
