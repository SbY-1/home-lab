# 06 — Day-2 operations

## Scale the cluster

Add a node by editing the maps in `infrastructure/terraform.tfvars`:

```hcl
worker_nodes = {
  "talos-worker-01" = { vm_id = 8011, address = "192.168.1.111" }
  "talos-worker-02" = { vm_id = 8012, address = "192.168.1.112" }
  "talos-worker-03" = { vm_id = 8013, address = "192.168.1.113" } # new
}
```

```bash
terraform -chdir=infrastructure apply
```

The VIP means adding control-plane nodes needs no endpoint change (use an **odd** count for
etcd quorum: 1 → 3 → 5).

## Bump resources

Override per node in the map, e.g. `{ vm_id = ..., address = ..., cores = 4, memory = 8192,
disk_gb = 80 }`, then `apply`.

## Upgrade Talos / Kubernetes

- **Kubernetes:** `talosctl upgrade-k8s --to <version>` (or bump `kubernetes_version`).
- **Talos:** bump `talos_version` and upgrade nodes with
  `talosctl upgrade --image factory.talos.dev/...:<version>`.

Check compatibility (Talos ↔ Kubernetes) before upgrading. Upgrade control plane first, one
node at a time.

## Upgrade Cilium

Bump `cilium_version` in `infrastructure/terraform.tfvars` and `apply` (re-renders the inline manifest).

## Upgrade GitOps-managed apps

Bump the chart `targetRevision` (and values) in `gitops/argocd/apps/<tool>.yaml` /
`values.yaml`, commit, push — ArgoCD rolls it out.

## Secrets in GitOps (recommended next step)

Plain Secrets shouldn't be committed. Add **Sealed Secrets** or **SOPS + age** under
`gitops/components/` and reference encrypted secrets from apps. The `.gitignore` already
excludes `*.secret*`.

## Backups

- **etcd:** `talosctl etcd snapshot db.snapshot` (store off-cluster).
- **PVs:** back the storage class with snapshots, or add Velero as a GitOps app.

## Teardown (reverse order)

```bash
terraform -chdir=infrastructure destroy            # ArgoCD + cluster + VMs (one state)
terraform -chdir=infrastructure/proxmox-iam destroy # the IAM identity (if managed via Terraform)
```

## Troubleshooting

| Symptom | Check |
|---------|-------|
| Config apply can't reach a node | Node IP (cloud-init vs DHCP); `talosctl -n <ip> dmesg` |
| Nodes `NotReady` | Cilium pods in `kube-system`; `cilium status` |
| API unreachable | VIP assigned? `talosctl -n <cp-ip> get addresses` |
| LoadBalancer stuck `<pending>` | `CiliumLoadBalancerIPPool` range + L2 policy; pool not exhausted |
| ArgoCD app `OutOfSync`/`Unknown` | repo URL replaced? `kubectl -n argocd logs deploy/argocd-repo-server` |
| Image download fails | `import` content type enabled on `image_datastore`? |
