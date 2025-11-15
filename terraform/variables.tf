variable "pm_api_url" {
  description = "Proxmox API URL"
  type        = string
  default     = "https://192.168.0.4:8006/api2/json"
}

variable "pm_api_token_id" {
  description = "Proxmox API Token ID (format: user@realm!tokenid)"
  type        = string
}

variable "pm_api_token_secret" {
  description = "Proxmox API Token Secret"
  type        = string
  sensitive   = true
}

variable "target_node" {
  description = "Proxmox node name"
  type        = string
  default     = "pve"
}

variable "template_name" {
  description = "Cloud-init template name"
  type        = string
  default     = "ubuntu-cloudinit-template"
}

variable "storage" {
  description = "Default storage for disks"
  type        = string
  default     = "local-lvm"
}

variable "ssh_pubkey_path" {
  description = "Path to public SSH key file"
  type        = string
  default     = "keys/id_rsa.pub"
}