variable "proxmox_endpoint" {
  description = "Proxmox VE API endpoint, e.g. https://pve.lan:8006/"
  type        = string
}

variable "proxmox_insecure" {
  description = "Skip TLS verification (true for self-signed homelab certs)."
  type        = bool
  default     = true
}

# Admin credentials used ONLY to create the least-privilege identity.
# Use a real admin token (root@pam!token=...) here; this module then mints the
# scoped terraform@pve user/token used by the rest of the stack.
variable "proxmox_admin_api_token" {
  description = "Admin API token 'USER@REALM!TOKENID=SECRET' used to create the scoped identity."
  type        = string
  sensitive   = true
}

variable "tf_user_id" {
  description = "User id (with realm) to create for Terraform provisioning."
  type        = string
  default     = "terraform@pve"
}

variable "tf_role_id" {
  description = "Custom role id holding the least-privilege provisioning permissions."
  type        = string
  default     = "TerraformProv"
}

variable "tf_token_id" {
  description = "Token id created under the Terraform user."
  type        = string
  default     = "provisioner"
}

variable "acl_path" {
  description = "ACL path the role is granted on. '/' is simplest; scope to a pool/node to reduce blast radius."
  type        = string
  default     = "/"
}

# --- Proxmox CSI / CCM identity (storage) ---
variable "csi_role_id" {
  description = "Custom role id for the Proxmox CSI + CCM identity."
  type        = string
  default     = "CSI"
}

variable "csi_user_id" {
  description = "User id (with realm) for the Proxmox CSI + CCM identity."
  type        = string
  default     = "kubernetes-csi@pve"
}

variable "csi_token_id" {
  description = "Token id created under the CSI user."
  type        = string
  default     = "csi"
}
