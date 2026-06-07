# 02 — Terraform: VMs + the Talos cluster

The whole stack lives in **one root** (`infrastructure/`) with **one state**, calling three
modules in order: `vms` → `talos` → `argocd`. This page covers the first two; ArgoCD is
[04](04-argocd-bootstrap.md). VMs, Talos config, Cilium, and the cluster all come up in a
single `terraform apply`.

## What the modules do

- **`modules/vms`** — `images.tf` builds a Talos Image Factory schematic with the
  `qemu-guest-agent` extension and downloads the uncompressed `nocloud` **qcow2** into the
  `import` datastore (Proxmox API — no decompression, no SSH). `main.tf` creates 1 control-plane
  + 2 workers via `for_each`; the qcow2 is imported as each boot disk (`disk.import_from`), and
  cloud-init assigns a deterministic static IP + hostname.
- **`modules/talos`** — generates secrets + machine configs, applies a per-node network patch
  (static IP, control-plane **VIP**), bootstraps etcd on the first control-plane node, retrieves
  the kubeconfig, and embeds **Cilium** as a Talos `inlineManifest` ([03](03-cilium.md)).

Module ordering is enforced with `depends_on` in `infrastructure/main.tf` (VM boot-wait
finishes before config apply; the cluster exists before ArgoCD). The `kubernetes`/`helm`
providers for ArgoCD are configured from the Talos module's kubeconfig outputs, so everything
converges in one apply.

## Run it

```bash
cd infrastructure
cp terraform.tfvars.example terraform.tfvars
$EDITOR terraform.tfvars   # Proxmox conn, datastores, network, VIP, node maps, gitops_repo_url
terraform init
terraform plan             # review
terraform apply
```

Writes `kubeconfig` and `talosconfig` into `infrastructure/` (both gitignored).

```bash
export KUBECONFIG=$PWD/kubeconfig
export TALOSCONFIG=$PWD/talosconfig
kubectl get nodes -o wide        # 1 control-plane + 2 workers, all Ready
talosctl -n <cp-ip> health       # cluster health
```

## Key variables

| Variable | Purpose | Default |
|----------|---------|---------|
| `proxmox_endpoint` / `proxmox_api_token` / `proxmox_node` | Proxmox connection | — |
| `proxmox_datastore` / `image_datastore` | VM disk / image storage | `local-lvm` / `local` |
| `network_bridge` / `network_vlan` / `network_cidr` / `gateway` / `dns_servers` | Networking | `vmbr0` / null / 24 |
| `cluster_vip` | Kubernetes API VIP | — |
| `talos_version` / `kubernetes_version` / `cilium_version` | Versions | `v1.13.2` / `v1.36.1` / `1.17.4` |
| `controlplane_nodes` / `worker_nodes` | Topology (key = hostname) | 1 CP + 2 workers |

## Scaling (future-proof)

Add an entry to `worker_nodes` (unique `vm_id` + `address`) in `infrastructure/terraform.tfvars`
and `terraform apply` — the new node is provisioned, configured, and joins automatically. Same
for control-plane nodes; the VIP means no endpoint change.

## Gotchas / notes

- **Static IP reachability:** nodes get their IP from cloud-init (nocloud). If your setup does
  not honor it, give the node MACs DHCP reservations matching the `address` values, or the
  first config apply can't reach the node.
- **Interface name:** the machine-config patches select the NIC via `deviceSelector.physical`,
  so they don't depend on `eth0` vs `enpXsY` naming.
- **Image storage:** `image_datastore` needs the `import` content type and must be file-based
  (Directory/NFS/CIFS/BTRFS). We download the uncompressed **qcow2** and attach it with
  `disk.import_from`, so the whole flow is API-only — no SSH. (Using the compressed `.raw.zst`
  here would fail with `decompression not supported for import`; qcow2 avoids that.)
- **No SSH:** the provider uses the API token only; there is no `ssh` block.
- **Re-running:** Talos config applies are idempotent; bootstrap runs once.

➡️ Next: [03 — Cilium CNI](03-cilium.md)
