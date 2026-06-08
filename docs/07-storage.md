# 07 — Persistent storage (Proxmox CSI)

Talos ships no storage provisioner, so PVCs (Prometheus, Grafana, …) stay `Pending` until one
exists. We use the **Proxmox CSI plugin** so PersistentVolumes are real Proxmox disks — the
most integrated option for this infra.

## Components (all Terraform-managed, in the single root)

| Piece | Where | Role |
|-------|-------|------|
| `CSI` role + `kubernetes-csi@pve` user/token | `proxmox-iam` (`csi.tf`) | Least-priv: audit VMs, allocate/attach disks |
| `cluster.externalCloudProvider.enabled` **+** `machine.kubelet.extraArgs.cloud-provider=external` | `modules/talos` | Both are required: the kubelet flag is what adds the `uninitialized` taint so the CCM initializes nodes (sets providerID + topology labels). `enabled` alone is not enough. |
| proxmox-cloud-controller-manager | `modules/proxmox-csi` | Sets each node's `providerID` (`proxmox://region/vmid`) + topology labels |
| proxmox-csi-plugin | `modules/proxmox-csi` | Provisions/attaches Proxmox disks as PVs |
| `proxmox` StorageClass (default) | `modules/proxmox-csi` | `csi.proxmox.sinextra.dev`, backed by `proxmox_csi_storage` |

Why the CCM? The CSI needs to map a Kubernetes node to a Proxmox VM (its `vmid`). The CCM sets
that via the node `providerID`, which requires kubelet to run with an external cloud provider.

## ⚠️ Bootstrap impact

Enabling `externalCloudProvider` taints every node with
`node.cloudprovider.kubernetes.io/uninitialized:NoSchedule` until the CCM initializes them.
The CCM tolerates this taint and clears it on startup. In a single `terraform apply` the order
is handled for you: `module.talos` (applies the taint) → `module.proxmox_csi` (CCM clears it).
If the CCM can't reach Proxmox, **new** pods won't schedule — check the CCM first if so.

## Inputs (set in `infrastructure/terraform.tfvars`)

```hcl
proxmox_csi_token_id     = "kubernetes-csi@pve!csi"   # proxmox-iam output csi_token_id
proxmox_csi_token_secret = "..."                       # proxmox-iam output -raw csi_token_secret
proxmox_region           = "homelab"                   # any consistent label
proxmox_csi_storage      = "local-lvm"                 # Proxmox storage that backs the PVs
```

Get the token from the IAM stage — **either** path creates the CSI role/user/token:

- **pveum script** (if you have no admin token; run as root on the node):
  ```bash
  ssh root@pve 'bash -s' < infrastructure/proxmox-iam/bootstrap-pveum.sh
  # prints both tokens; for CSI use:
  #   proxmox_csi_token_id     = "kubernetes-csi@pve!csi"
  #   proxmox_csi_token_secret = <the 'value' it printed>
  ```
- **Terraform** (if you have an admin token):
  ```bash
  terraform -chdir=infrastructure/proxmox-iam apply
  terraform -chdir=infrastructure/proxmox-iam output csi_token_id
  terraform -chdir=infrastructure/proxmox-iam output -raw csi_token_secret
  ```

## Apply + verify

```bash
terraform -chdir=infrastructure apply

kubectl get nodes -o jsonpath='{range .items[*]}{.metadata.name}{"  "}{.spec.providerID}{"\n"}{end}'
#   talos-cp-01  proxmox://homelab/8001   ← providerID set = CCM working
kubectl -n csi-proxmox get pods            # ccm + csi-controller + csi-node Running
kubectl get storageclass                   # 'proxmox (default)'
```

Then the Prometheus PVCs bind (values reference `storageClassName: proxmox`):
```bash
kubectl -n monitoring get pvc
```

## If nodes have no providerID / topology labels (CSI: "Failed to get region or zone")

The CCM only initializes a node that carries the `node.cloudprovider.kubernetes.io/uninitialized`
taint, and the kubelet only adds that taint **when a node first registers**. Nodes that were
already running before `cloud-provider=external` was applied won't get it from a restart —
add it once by hand so the CCM picks them up:

```bash
kubectl taint node <node...> node.cloudprovider.kubernetes.io/uninitialized=true:NoSchedule --overwrite
# CCM then sets providerID + topology labels and removes the taint itself.
```

If the taint does NOT clear, the CCM can't initialize the node — check its logs
(`kubectl -n csi-proxmox logs deploy/proxmox-cloud-controller-manager`) for an auth/connection
error or a VM-name mismatch (CCM matches node name → Proxmox VM name), then remove the taint
with `kubectl taint node <node> node.cloudprovider.kubernetes.io/uninitialized-`.

## If Prometheus PVCs were already `Pending` on emptyDir/no-class

A PVC created before a default StorageClass existed is stuck with `storageClassName: ""`.
Delete the StatefulSets + their PVCs so they're recreated against `proxmox`:
```bash
kubectl -n monitoring delete pvc -l app.kubernetes.io/name=prometheus
kubectl -n monitoring delete pvc -l app.kubernetes.io/name=alertmanager
# ArgoCD recreates them on next sync.
```

➡️ Back to [05 — kube-prometheus-stack](05-gitops-prometheus.md)
