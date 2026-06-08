#!/usr/bin/env bash
# ---------------------------------------------------------------------------
# One-time bootstrap of the least-privilege identities on Proxmox VE, for when
# you have no admin API token to run the Terraform proxmox-iam module with.
# Run it AS root ON the Proxmox host (or: ssh root@pve bash -s < bootstrap-pveum.sh).
#
# It creates and prints TWO tokens:
#   1) terraform@pve!provisioner  -> infrastructure/terraform.tfvars : proxmox_api_token
#   2) kubernetes-csi@pve!csi      -> infrastructure/terraform.tfvars :
#        proxmox_csi_token_id     = "kubernetes-csi@pve!csi"
#        proxmox_csi_token_secret = <the value printed>
# ---------------------------------------------------------------------------
set -euo pipefail

# Avoid perl/pveum locale warnings when a locale is forwarded over SSH.
export LC_ALL=C LANG=C

# Recreate a token idempotently: Proxmox only reveals the secret at creation,
# and `token add` errors if it exists — so remove first, then add (prints value).
recreate_token() { # <user> <tokenid>
  pveum user token remove "$1" "$2" >/dev/null 2>&1 || true
  pveum user token add "$1" "$2" --privsep 0
}

ROLE_ID="${ROLE_ID:-TerraformProv}"
USER_ID="${USER_ID:-terraform@pve}"
TOKEN_ID="${TOKEN_ID:-provisioner}"
ACL_PATH="${ACL_PATH:-/}"

# Proxmox CSI + cloud-controller-manager identity (persistent storage).
CSI_ROLE_ID="${CSI_ROLE_ID:-CSI}"
CSI_USER_ID="${CSI_USER_ID:-kubernetes-csi@pve}"
CSI_TOKEN_ID="${CSI_TOKEN_ID:-csi}"
CSI_PRIVS="VM.Audit VM.Config.Disk Datastore.Allocate Datastore.AllocateSpace Datastore.Audit Sys.Audit"

# Proxmox VE 9 privilege changes:
#  - VM.Monitor was REMOVED (folded into Sys.Audit/Sys.Modify).
#  - VM.GuestAgent was split into VM.GuestAgent.* ; .Audit reads guest-agent
#    info (VM IPs) used by qemu-guest-agent.
PRIVS="Datastore.Allocate Datastore.AllocateSpace Datastore.AllocateTemplate Datastore.Audit \
Pool.Allocate SDN.Use Sys.Audit Sys.Console Sys.Modify User.Modify \
VM.Allocate VM.Audit VM.Clone VM.Config.CDROM VM.Config.Cloudinit VM.Config.CPU \
VM.Config.Disk VM.Config.HWType VM.Config.Memory VM.Config.Network VM.Config.Options \
VM.GuestAgent.Audit VM.Migrate VM.PowerMgmt VM.Snapshot"

echo ">> Creating role ${ROLE_ID}"
pveum role add "${ROLE_ID}" -privs "${PRIVS}" 2>/dev/null \
  || pveum role modify "${ROLE_ID}" -privs "${PRIVS}"

echo ">> Creating user ${USER_ID}"
pveum user add "${USER_ID}" --comment "Least-privilege Terraform identity" 2>/dev/null || true

echo ">> Granting ${ROLE_ID} on ${ACL_PATH}"
pveum acl modify "${ACL_PATH}" -user "${USER_ID}" -role "${ROLE_ID}"

echo ">> Creating API token ${USER_ID}!${TOKEN_ID} (privilege separation off)"
echo "   Set in terraform.tfvars (note the format is tokenid=value):"
echo "     proxmox_api_token = \"${USER_ID}!${TOKEN_ID}=<the 'value' printed below>\""
recreate_token "${USER_ID}" "${TOKEN_ID}"

# ---------------------------------------------------------------------------
# Proxmox CSI + cloud-controller-manager identity (persistent storage).
# ---------------------------------------------------------------------------
echo ">> Creating role ${CSI_ROLE_ID}"
pveum role add "${CSI_ROLE_ID}" -privs "${CSI_PRIVS}" 2>/dev/null \
  || pveum role modify "${CSI_ROLE_ID}" -privs "${CSI_PRIVS}"

echo ">> Creating user ${CSI_USER_ID}"
pveum user add "${CSI_USER_ID}" --comment "Proxmox CSI + CCM identity" 2>/dev/null || true

echo ">> Granting ${CSI_ROLE_ID} on / (propagate)"
pveum acl modify / -user "${CSI_USER_ID}" -role "${CSI_ROLE_ID}"

echo ">> Creating API token ${CSI_USER_ID}!${CSI_TOKEN_ID} (privilege separation off)"
echo "   Set in terraform.tfvars:"
echo "     proxmox_csi_token_id     = \"${CSI_USER_ID}!${CSI_TOKEN_ID}\""
echo "     proxmox_csi_token_secret = <the 'value' printed below>"
recreate_token "${CSI_USER_ID}" "${CSI_TOKEN_ID}"
