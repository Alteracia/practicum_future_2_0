# Shareable sandbox sizing. No credentials, private keys or fictitious cloud IDs.
name_prefix  = "future20-task4"
zone         = "ru-central1-a"
subnet_cidr  = "10.40.10.0/24"
vm_cores     = 2
vm_memory_gb = 4
boot_disk_gb = 30
ssh_user     = "ubuntu"
image_id     = null

# Required target-specific values go in ignored local.auto.tfvars or TF_VAR_*:
# cloud_id, folder_id, admin_cidr, ssh_public_key
# Provider credentials: YC_TOKEN or YC_SERVICE_ACCOUNT_KEY_FILE.
