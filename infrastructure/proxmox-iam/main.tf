provider "proxmox" {
  endpoint  = var.proxmox_endpoint
  insecure  = var.proxmox_insecure
  api_token = var.proxmox_admin_api_token
}

# ---------------------------------------------------------------------------
# Least-privilege role for Terraform-driven VM provisioning.
#
# These are the minimum privileges the bpg/proxmox provider needs to:
#   - download the Talos image to a datastore (Datastore.Allocate*),
#   - create/clone/configure/power VMs (VM.*),
#   - attach NICs / use SDN bridges (Sys.Modify, SDN.Use),
#   - create the token/user side-effects (User.Modify).
# The cluster stage imports the Talos qcow2 via the API (disk.import_from), so
# no SSH to the node is needed — this API token alone is sufficient.
# ---------------------------------------------------------------------------
resource "proxmox_virtual_environment_role" "terraform_prov" {
  role_id = var.tf_role_id

  privileges = [
    "Datastore.Allocate",
    "Datastore.AllocateSpace",
    "Datastore.AllocateTemplate",
    "Datastore.Audit",
    "Pool.Allocate",
    "SDN.Use",
    "Sys.Audit",
    "Sys.Console",
    "Sys.Modify",
    "User.Modify",
    "VM.Allocate",
    "VM.Audit",
    "VM.Clone",
    "VM.Config.CDROM",
    "VM.Config.Cloudinit",
    "VM.Config.CPU",
    "VM.Config.Disk",
    "VM.Config.HWType",
    "VM.Config.Memory",
    "VM.Config.Network",
    "VM.Config.Options",
    # PVE 9: VM.Monitor was removed; VM.GuestAgent was split into VM.GuestAgent.*
    # (.Audit reads guest-agent info / VM IPs used by qemu-guest-agent).
    "VM.GuestAgent.Audit",
    "VM.Migrate",
    "VM.PowerMgmt",
    "VM.Snapshot",
  ]
}

resource "proxmox_virtual_environment_user" "terraform" {
  user_id = var.tf_user_id
  comment = "Least-privilege identity for Terraform (managed by infrastructure/proxmox-iam)"
  enabled = true
}

# Grant the role to the user at the configured ACL path.
resource "proxmox_virtual_environment_acl" "terraform" {
  user_id   = proxmox_virtual_environment_user.terraform.user_id
  role_id   = proxmox_virtual_environment_role.terraform_prov.role_id
  path      = var.acl_path
  propagate = true
}

# API token for the user. privileged_separation = false means the token inherits
# the user's privileges (simplest); set true + a dedicated ACL for tighter control.
resource "proxmox_virtual_environment_user_token" "terraform" {
  user_id               = proxmox_virtual_environment_user.terraform.user_id
  token_name            = var.tf_token_id
  comment               = "Used by infrastructure/talos-cluster"
  privileges_separation = false
}
