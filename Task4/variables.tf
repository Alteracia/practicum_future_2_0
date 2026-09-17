variable "cloud_id" {
  description = "Target Yandex Cloud ID; set TF_VAR_cloud_id or local.auto.tfvars."
  type        = string
  nullable    = false
  validation {
    condition     = can(regex("^[a-z0-9]{20}$", var.cloud_id))
    error_message = "cloud_id must be a real 20-character Yandex Cloud ID."
  }
}

variable "folder_id" {
  description = "Existing dedicated sandbox folder; Terraform does not create it."
  type        = string
  nullable    = false
  validation {
    condition     = can(regex("^[a-z0-9]{20}$", var.folder_id))
    error_message = "folder_id must be a real 20-character Yandex Cloud folder ID."
  }
}

variable "zone" {
  description = "Availability zone shared by the VM, disk and subnet."
  type        = string
  default     = "ru-central1-a"
  validation {
    condition     = contains(["ru-central1-a", "ru-central1-b", "ru-central1-d"], var.zone)
    error_message = "Select ru-central1-a, ru-central1-b or ru-central1-d."
  }
}

variable "name_prefix" {
  description = "Resource name prefix; use a separate folder and state for each environment."
  type        = string
  default     = "future20-task4"
  validation {
    condition     = can(regex("^[a-z][a-z0-9-]{0,38}[a-z0-9]$", var.name_prefix))
    error_message = "Use 2-40 lowercase letters, digits and hyphens, starting with a letter and ending with a letter or digit."
  }
}

variable "subnet_cidr" {
  description = "Private IPv4 /24 subnet for the sandbox."
  type        = string
  default     = "10.40.10.0/24"
  validation {
    condition = (
      can(cidrnetmask(var.subnet_cidr)) &&
      can(regex("^10\\.", var.subnet_cidr)) &&
      endswith(var.subnet_cidr, "/24") &&
      try(cidrhost(var.subnet_cidr, 0) == split("/", var.subnet_cidr)[0], false)
    )
    error_message = "Use an aligned private 10.x.x.0/24 IPv4 network."
  }
}

variable "admin_cidr" {
  description = "Administrator's real public IPv4 address in /32 form; no default."
  type        = string
  nullable    = false
  validation {
    condition = (
      can(cidrnetmask(var.admin_cidr)) &&
      endswith(var.admin_cidr, "/32") &&
      var.admin_cidr != "0.0.0.0/32"
    )
    error_message = "SSH requires one IPv4 /32 address. Broad networks such as 0.0.0.0/0 are prohibited."
  }
}

variable "ssh_user" {
  description = "Non-root OS account created by cloud-init."
  type        = string
  default     = "ubuntu"
  validation {
    condition     = can(regex("^[a-z][a-z0-9_-]{0,30}$", var.ssh_user)) && var.ssh_user != "root"
    error_message = "Use a Linux username other than root."
  }
}

variable "ssh_public_key" {
  description = "One OpenSSH Ed25519 public key, never the private key."
  type        = string
  nullable    = false
  validation {
    condition     = can(regex("^ssh-ed25519 [A-Za-z0-9+/]+={0,3}( [^\\r\\n]*)?$", trimspace(var.ssh_public_key)))
    error_message = "Provide a single-line ssh-ed25519 public key from a .pub file."
  }
}

variable "vm_cores" {
  description = "Sandbox vCPU count; deliberate small range to control resource use."
  type        = number
  default     = 2
  validation {
    condition     = contains([2, 4], var.vm_cores)
    error_message = "This sandbox supports 2 or 4 vCPUs."
  }
}

variable "vm_memory_gb" {
  description = "RAM in GiB; keep at least 2 GiB per vCPU."
  type        = number
  default     = 4
  validation {
    condition     = contains([4, 8, 16], var.vm_memory_gb)
    error_message = "Select 4, 8 or 16 GiB RAM."
  }
}

variable "boot_disk_gb" {
  description = "SSD boot disk capacity in GiB; synthetic test data only."
  type        = number
  default     = 30
  validation {
    condition     = var.boot_disk_gb >= 20 && var.boot_disk_gb <= 100 && floor(var.boot_disk_gb) == var.boot_disk_gb
    error_message = "Use an integer boot disk size from 20 to 100 GiB."
  }
}

variable "image_id" {
  description = "Optional immutable image ID. Null resolves the current Ubuntu 22.04 LTS family image."
  type        = string
  default     = null
  validation {
    condition     = var.image_id == null ? true : can(regex("^[a-z0-9]{20}$", var.image_id))
    error_message = "Use null or a valid 20-character image ID."
  }
}
