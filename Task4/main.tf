terraform {
  required_version = ">= 1.7.0, < 2.0.0"

  required_providers {
    yandex = {
      source  = "yandex-cloud/yandex"
      version = "= 0.161.0"
    }
  }
}

# Credentials are read by the provider from YC_TOKEN or
# YC_SERVICE_ACCOUNT_KEY_FILE. Never put credentials in HCL or tfvars.
provider "yandex" {
  cloud_id  = var.cloud_id
  folder_id = var.folder_id
  zone      = var.zone
}

locals {
  labels = {
    project     = "future-2-0"
    environment = "sandbox"
    managed_by  = "terraform"
    task        = "task4"
  }
}

# Pin image_id after the first successful plan to reproduce the exact image.
data "yandex_compute_image" "ubuntu" {
  count  = var.image_id == null ? 1 : 0
  family = "ubuntu-2204-lts"
}

resource "yandex_vpc_network" "sandbox" {
  name        = "${var.name_prefix}-network"
  description = "Isolated educational sandbox; no clinical or financial records"
  labels      = local.labels
}

resource "yandex_vpc_subnet" "sandbox" {
  name           = "${var.name_prefix}-subnet"
  zone           = var.zone
  network_id     = yandex_vpc_network.sandbox.id
  v4_cidr_blocks = [var.subnet_cidr]
  labels         = local.labels
}

resource "yandex_vpc_security_group" "sandbox" {
  name        = "${var.name_prefix}-sg"
  description = "SSH from one administrator IPv4 address; outbound Internet access"
  network_id  = yandex_vpc_network.sandbox.id
  labels      = local.labels

  ingress {
    description    = "SSH from the administrator only"
    protocol       = "TCP"
    port           = 22
    v4_cidr_blocks = [var.admin_cidr]
  }

  # Allows package repositories, DNS and time synchronization in this sandbox.
  # Security groups are stateful: reply traffic does not require extra ingress.
  egress {
    description    = "Outbound access for sandbox maintenance"
    protocol       = "ANY"
    from_port      = 0
    to_port        = 65535
    v4_cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "yandex_compute_disk" "boot" {
  name     = "${var.name_prefix}-boot"
  zone     = var.zone
  type     = "network-ssd"
  size     = var.boot_disk_gb
  image_id = var.image_id != null ? var.image_id : data.yandex_compute_image.ubuntu[0].id
  labels   = local.labels
}

resource "yandex_compute_instance" "sandbox" {
  name                      = "${var.name_prefix}-vm"
  hostname                  = "${var.name_prefix}-vm"
  zone                      = var.zone
  platform_id               = "standard-v3"
  allow_stopping_for_update = true
  labels                    = local.labels

  resources {
    cores         = var.vm_cores
    memory        = var.vm_memory_gb
    core_fraction = 100
  }

  boot_disk {
    disk_id     = yandex_compute_disk.boot.id
    auto_delete = false
  }

  network_interface {
    subnet_id          = yandex_vpc_subnet.sandbox.id
    security_group_ids = [yandex_vpc_security_group.sandbox.id]
    nat                = true
  }

  scheduling_policy {
    preemptible = false
  }

  lifecycle {
    precondition {
      condition     = var.vm_memory_gb >= var.vm_cores * 2
      error_message = "The sandbox requires at least 2 GiB RAM per vCPU."
    }
  }

  # Cloud-init creates the OS user; no remote-exec or private key is needed.
  metadata = {
    serial-port-enable = "0"
    user-data = join("\n", ["#cloud-config", yamlencode({
      disable_root = true
      ssh_pwauth   = false
      users = [{
        name                = var.ssh_user
        groups              = ["sudo"]
        shell               = "/bin/bash"
        sudo                = ["ALL=(ALL) NOPASSWD:ALL"]
        lock_passwd         = true
        ssh_authorized_keys = [trimspace(var.ssh_public_key)]
      }]
    })])
  }
}
