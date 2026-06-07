#!/usr/bin/env bash
# ---------------------------------------------------------------------------
# One-time bootstrap of the least-privilege Terraform identity on Proxmox VE.
#
# Use this ALTERNATIVE to the Terraform module when you don't yet have any
# admin API token to run Terraform with. Run it AS root ON the Proxmox host
# (or via `ssh root@pve bash -s < bootstrap-pveum.sh`).
#
# It prints an API token at the end — put that into
# infrastructure/talos-cluster/terraform.tfvars : proxmox_api_token
# ---------------------------------------------------------------------------
set -euo pipefail

ROLE_ID="${ROLE_ID:-TerraformProv}"
USER_ID="${USER_ID:-terraform@pve}"
TOKEN_ID="${TOKEN_ID:-provisioner}"
ACL_PATH="${ACL_PATH:-/}"

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
echo "   Copy the value below into terraform.tfvars (proxmox_api_token):"
pveum user token add "${USER_ID}" "${TOKEN_ID}" --privsep 0
