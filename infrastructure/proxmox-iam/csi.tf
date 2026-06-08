# ---------------------------------------------------------------------------
# Identity for the Proxmox CSI plugin + cloud-controller-manager (storage).
# Least-privilege role to audit VMs and allocate/attach disks.
# Shared by both the CCM (reads VMs to set providerID) and the CSI (disks).
# ---------------------------------------------------------------------------
resource "proxmox_virtual_environment_role" "csi" {
  role_id = var.csi_role_id

  privileges = [
    "Datastore.Allocate",
    "Datastore.AllocateSpace",
    "Datastore.Audit",
    "Sys.Audit",
    "VM.Audit",
    "VM.Config.Disk",
  ]
}

resource "proxmox_virtual_environment_user" "csi" {
  user_id = var.csi_user_id
  comment = "Proxmox CSI + CCM identity (managed by infrastructure/proxmox-iam)"
  enabled = true
}

resource "proxmox_virtual_environment_acl" "csi" {
  user_id   = proxmox_virtual_environment_user.csi.user_id
  role_id   = proxmox_virtual_environment_role.csi.role_id
  path      = "/"
  propagate = true
}

resource "proxmox_virtual_environment_user_token" "csi" {
  user_id               = proxmox_virtual_environment_user.csi.user_id
  token_name            = var.csi_token_id
  comment               = "Used by proxmox-csi-plugin + proxmox-cloud-controller-manager"
  privileges_separation = false
}
