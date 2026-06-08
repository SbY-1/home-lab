# 01 — Proxmox setup & least-privilege IAM

Goal: a dedicated Proxmox **API user** `terraform@pve` + token (custom role with the minimum
privileges). Everything — including the Talos disk-image import — runs over the **API only**;
no SSH to the node is used.

## Why least privilege?

Terraform automation should never run as `root@pam`. We create a custom role with exactly the
privileges the `bpg/proxmox` provider needs to download the Talos image and create/configure
VMs — nothing more. Blast radius can be reduced further by granting the role on a resource
**pool** instead of `/`.

## Prerequisites on Proxmox

- Proxmox VE **9.x**.
- A datastore for VM disks (e.g. `local-lvm`).
- A datastore for the Talos image (`image_datastore`) with the **`import`** content type
  enabled. This must be **file-based** storage (Directory/NFS/CIFS/BTRFS) — block storage
  (LVM/LVM-thin/ZFS/Ceph) can't hold `import` images. Enable it via
  *Datacenter → Storage → (storage) → Content → check "Import"*, or:
  ```bash
  pvesm set local --content iso,vztmpl,backup,snippets,import   # keep existing types, add import
  ```
  `image_datastore` is independent from `proxmox_datastore` (where VM disks live).
- A free IP for the API **VIP** and free IPs for each node + a small range for LoadBalancers.

No SSH to the node is required — the qcow2 disk import uses the Proxmox API.

## Option A — one-time `pveum` bootstrap (no admin token needed)

Run on the Proxmox host as root:

```bash
ssh root@pve 'bash -s' < infrastructure/proxmox-iam/bootstrap-pveum.sh
```

It creates **both** least-privilege identities and prints their tokens:
- `terraform@pve!provisioner` → `infrastructure/terraform.tfvars` `proxmox_api_token`
- `kubernetes-csi@pve!csi` (for the Proxmox CSI storage, see [07](07-storage.md)) →
  `proxmox_csi_token_id = "kubernetes-csi@pve!csi"` + `proxmox_csi_token_secret = <value>`

## Option B — manage the identity with Terraform

Requires an existing admin API token to run with (chicken-and-egg: use Option A's token, or a
temporary root token you delete afterwards).

```bash
cd infrastructure/proxmox-iam
cp terraform.tfvars.example terraform.tfvars
$EDITOR terraform.tfvars          # endpoint + admin token
terraform init
terraform apply
terraform output -raw tf_api_token   # -> infrastructure/terraform.tfvars proxmox_api_token
```

## The role's privileges

| Area | Privileges | Why |
|------|-----------|-----|
| Datastore | `Datastore.Allocate*`, `Datastore.Audit` | Download image, allocate disks |
| VM lifecycle | `VM.Allocate/Clone/Migrate/PowerMgmt/Audit/Snapshot` | Create & manage VMs |
| VM config | `VM.Config.*` | CPU/mem/disk/NIC/cloud-init/options |
| Guest agent | `VM.GuestAgent.Audit` | Read VM IPs via qemu-guest-agent (PVE 9+) |
| Network | `Sys.Modify`, `SDN.Use` | Attach NIC / use bridge / SDN |
| Misc | `Pool.Allocate`, `Sys.Audit`, `Sys.Console`, `User.Modify` | Pools, token side-effects |

The API token (least-privilege role) covers **all** operations, including importing the Talos
qcow2 image into each VM disk (`disk.import_from`). No SSH to the node is used.

> **Proxmox VE 9 note:** two privilege changes vs PVE 8 — `VM.Monitor` was **removed** (its
> access moved into `Sys.Audit`/`Sys.Modify`), and `VM.GuestAgent` was **split** into granular
> `VM.GuestAgent.*` privileges. The list here uses `VM.GuestAgent.Audit` (read-only guest-agent
> info, i.e. VM IPs). If you see `invalid privilege 'VM.Monitor'` or `'VM.GuestAgent'`, you're
> on an older privilege list — use this one.

➡️ Next: [02 — Terraform: the Talos cluster](02-terraform-cluster.md)
