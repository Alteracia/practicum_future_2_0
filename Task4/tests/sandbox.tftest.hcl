# MOCK ONLY: these runs never contact Yandex Cloud or prove a real deployment.
mock_provider "yandex" {
  mock_data "yandex_compute_image" {
    defaults = {
      id = "fd800000000000000000"
    }
  }
}

variables {
  cloud_id       = "b1g00000000000000000"
  folder_id      = "b1g11111111111111111"
  admin_cidr     = "192.0.2.10/32"
  ssh_public_key = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA test-only"
}

run "mock_resource_wiring" {
  command = apply

  assert {
    condition = (
      yandex_compute_instance.sandbox.network_interface[0].subnet_id == yandex_vpc_subnet.sandbox.id &&
      contains(yandex_compute_instance.sandbox.network_interface[0].security_group_ids, yandex_vpc_security_group.sandbox.id) &&
      yandex_vpc_subnet.sandbox.network_id == yandex_vpc_network.sandbox.id &&
      yandex_vpc_security_group.sandbox.network_id == yandex_vpc_network.sandbox.id
    )
    error_message = "VM, subnet and security group must reference the same Terraform-managed network."
  }

  assert {
    condition = (
      yandex_compute_instance.sandbox.boot_disk[0].disk_id == yandex_compute_disk.boot.id &&
      yandex_compute_instance.sandbox.zone == yandex_compute_disk.boot.zone &&
      yandex_compute_instance.sandbox.zone == yandex_vpc_subnet.sandbox.zone &&
      !yandex_compute_instance.sandbox.boot_disk[0].auto_delete
    )
    error_message = "The separately managed disk must be attached in the VM's zone and survive VM-only deletion."
  }

  assert {
    condition = (
      length(yandex_vpc_security_group.sandbox.ingress) == 1 &&
      one(yandex_vpc_security_group.sandbox.ingress).port == 22 &&
      one(yandex_vpc_security_group.sandbox.ingress).protocol == "TCP" &&
      toset(one(yandex_vpc_security_group.sandbox.ingress).v4_cidr_blocks) == toset([var.admin_cidr])
    )
    error_message = "Only SSH from the administrator /32 may be exposed."
  }

  assert {
    condition = (
      yandex_compute_instance.sandbox.network_interface[0].nat &&
      !yamldecode(yandex_compute_instance.sandbox.metadata["user-data"]).ssh_pwauth &&
      yamldecode(yandex_compute_instance.sandbox.metadata["user-data"]).disable_root &&
      yamldecode(yandex_compute_instance.sandbox.metadata["user-data"]).users[0].ssh_authorized_keys[0] == var.ssh_public_key
    )
    error_message = "NAT and key-only non-root SSH must be configured."
  }
}

run "reject_worldwide_ssh" {
  command = plan
  variables {
    admin_cidr = "0.0.0.0/0"
  }
  expect_failures = [var.admin_cidr]
}

run "reject_non_network_subnet" {
  command = plan
  variables {
    subnet_cidr = "10.40.10.5/24"
  }
  expect_failures = [var.subnet_cidr]
}

run "reject_private_key_input" {
  command = plan
  variables {
    ssh_public_key = "-----BEGIN OPENSSH PRIVATE KEY-----"
  }
  expect_failures = [var.ssh_public_key]
}

run "reject_root_login" {
  command = plan
  variables {
    ssh_user = "root"
  }
  expect_failures = [var.ssh_user]
}

run "reject_insufficient_memory" {
  command = plan
  variables {
    vm_cores     = 4
    vm_memory_gb = 4
  }
  expect_failures = [yandex_compute_instance.sandbox]
}

run "pinned_image" {
  command = plan
  variables {
    image_id = "fd811111111111111111"
  }
  assert {
    condition     = length(data.yandex_compute_image.ubuntu) == 0 && yandex_compute_disk.boot.image_id == var.image_id
    error_message = "A pinned image must not resolve the mutable image family."
  }
}
