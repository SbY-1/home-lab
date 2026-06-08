variable "namespace" {
  description = "Namespace for the CCM + CSI (privileged pod security)."
  type        = string
  default     = "csi-proxmox"
}

variable "ccm_chart_version" {
  description = "proxmox-cloud-controller-manager chart version."
  type        = string
  default     = "0.2.28"
}

variable "csi_chart_version" {
  description = "proxmox-csi-plugin chart version."
  type        = string
  default     = "0.5.7"
}

# --- Proxmox API connection for CCM + CSI ---
variable "proxmox_url" {
  description = "Proxmox API URL ending in /api2/json."
  type        = string
}

variable "proxmox_insecure" {
  description = "Skip TLS verification to the Proxmox API."
  type        = bool
  default     = true
}

variable "proxmox_token_id" {
  description = "CSI token id, e.g. 'kubernetes-csi@pve!csi'."
  type        = string
}

variable "proxmox_token_secret" {
  description = "CSI token secret."
  type        = string
  sensitive   = true
}

variable "region" {
  description = "Logical Proxmox cluster name (topology region). Must match across CCM/CSI."
  type        = string
}

# --- Default StorageClass ---
variable "storage_class_name" {
  description = "Name of the StorageClass to create (set as cluster default)."
  type        = string
  default     = "proxmox"
}

variable "proxmox_storage" {
  description = "Proxmox storage ID that backs the PVs (e.g. 'local-lvm')."
  type        = string
  default     = "local-lvm"
}

variable "fstype" {
  description = "Filesystem for provisioned volumes."
  type        = string
  default     = "ext4"
}

variable "ssd" {
  description = "Mark volumes as SSD-backed (enables discard/cache tuning)."
  type        = bool
  default     = true
}
