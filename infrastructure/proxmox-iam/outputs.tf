output "tf_user_id" {
  description = "The provisioning user id."
  value       = proxmox_virtual_environment_user.terraform.user_id
}

output "tf_role_id" {
  description = "The least-privilege role id."
  value       = proxmox_virtual_environment_role.terraform_prov.role_id
}

# Full API token string 'USER@REALM!TOKENID=SECRET' — feed this into
# infrastructure/talos-cluster's proxmox_api_token variable.
output "tf_api_token" {
  description = "Full API token for the provisioning user (sensitive)."
  value       = proxmox_virtual_environment_user_token.terraform.value
  sensitive   = true
}

# --- Proxmox CSI / CCM identity → feed into the main stack ---
output "csi_token_id" {
  description = "CSI token id, e.g. 'kubernetes-csi@pve!csi' (-> proxmox_csi_token_id)."
  value       = proxmox_virtual_environment_user_token.csi.id
}

output "csi_token_secret" {
  description = "CSI token secret (-> proxmox_csi_token_secret)."
  value       = element(split("=", proxmox_virtual_environment_user_token.csi.value), 1)
  sensitive   = true
}
