# Home Lab — Talos Kubernetes on Proxmox (Terraform + GitOps)

A future-proof, scalable home lab: a [Talos Linux](https://www.talos.dev/) Kubernetes cluster
running on **Proxmox VE**, provisioned with **Terraform** and configured with **GitOps**
(ArgoCD, app-of-apps pattern).

- **Provisioning:** Terraform (`infrastructure/`) — Proxmox IAM, Talos VMs, cluster bootstrap, ArgoCD.
- **Configuration:** GitOps (`gitops/`) — everything inside the cluster is reconciled by ArgoCD from Git.
- **CNI:** Cilium (kube-proxy replacement) installed at bootstrap via Talos inline manifests.
- **LAN exposure:** Cilium L2 announcements + LoadBalancer IPAM (no MetalLB) + ingress controller.

## Architecture

```
                         Proxmox VE 9.x host(s)
  ┌───────────────────────────────────────────────────────────────┐
  │  talos-cp-01 (CP)      talos-worker-01      talos-worker-02     │
  │  2 vCPU / 4Gi / 40G    2 vCPU / 4Gi / 40G   2 vCPU / 4Gi / 40G  │
  │  Talos v1.13.2 (qemu-guest-agent), control-plane VIP            │
  └───────────────────────────────────────────────────────────────┘
            │ Terraform: bpg/proxmox + siderolabs/talos
            ▼
   Kubernetes 1.36  ── CNI: Cilium (kube-proxy replacement, KubePrism :7445)
            │                  └ L2 announcements + LB IPAM (LAN VIPs)
            ▼
   ArgoCD (Terraform-bootstrapped Helm) ── root "app-of-apps" → this Git repo
            │
            ├─ gitops/components/    (Cilium runtime config, ingress, cert-manager)
            └─ gitops/applications/  (kube-prometheus-stack = first tool)
```

The control-plane endpoint is a **Talos VIP**, so adding control-plane nodes later is just a
map entry — no re-architecture.

## Repository layout

| Path | Purpose |
|------|---------|
| `infrastructure/proxmox-iam/` | **Bootstrap (separate state):** least-privilege Proxmox role + user + API token. Run once with admin creds. |
| `infrastructure/` (root) | **Main stack (single state):** calls the three modules below in one `terraform apply`. |
| `infrastructure/modules/vms/` | Talos image download + Proxmox VM creation. |
| `infrastructure/modules/talos/` | Talos machine config, Cilium inline manifest, bootstrap, kubeconfig. |
| `infrastructure/modules/argocd/` | Installs ArgoCD via Helm + the root app-of-apps. |
| `gitops/argocd/` | Root Application, AppProjects, ApplicationSets. |
| `gitops/components/` | Platform building blocks (Cilium config, ingress, cert-manager). |
| `gitops/applications/` | Deployed tools (kube-prometheus-stack first). |
| `docs/` | Step-by-step guides for every stage. |

> **Why is `proxmox-iam` separate?** It mints the API token the main stack authenticates with,
> so it must run first, with different (admin) credentials. The three functional modules
> (`vms` → `talos` → `argocd`) share **one state** under `infrastructure/`.

## Version matrix (June 2026)

| Component | Version | Notes |
|-----------|---------|-------|
| Talos Linux | `v1.13.2` | Bundles Kubernetes `v1.36`. |
| Kubernetes | `v1.36` | Set by the Talos release. |
| `bpg/proxmox` provider | `~> 0.108` | Proxmox VE 9.x. |
| `siderolabs/talos` provider | `~> 0.7` | Talos machine config + bootstrap. |
| Cilium | `1.17.x` | kube-proxy replacement, L2 LB. |
| ArgoCD (argo-cd chart) | `~> 7.x` | App-of-apps. |
| kube-prometheus-stack | `~> 70.x` | Prometheus + Grafana + Alertmanager. |

All versions are Terraform variables / Helm `targetRevision` values — override as needed.

## Quickstart

> Prerequisites: `terraform`, `talosctl`, `kubectl`, `helm` on your workstation, a reachable
> Proxmox VE 9.x, and a (new, public) GitHub repo for this code. See [`docs/`](docs/).

```bash
# 0. Bootstrap the least-privilege Proxmox identity (separate state; see docs/01)
#    — pveum script OR:
terraform -chdir=infrastructure/proxmox-iam init
terraform -chdir=infrastructure/proxmox-iam apply
terraform -chdir=infrastructure/proxmox-iam output -raw tf_api_token   # -> proxmox_api_token

# 1. Set the GitOps repo URL in the manifests, then push this repo to GitHub
grep -rl 'github.com/CHANGEME/home-lab' gitops \
  | xargs sed -i '' 's#https://github.com/CHANGEME/home-lab.git#https://github.com/<you>/home-lab.git#g'
git add -A && git commit -m "init" && git push

# 2. Provision EVERYTHING in one apply: VMs -> Talos + Cilium -> ArgoCD (single state)
cd infrastructure
cp terraform.tfvars.example terraform.tfvars
$EDITOR terraform.tfvars      # Proxmox token, network, VIP, gitops_repo_url
terraform init
terraform apply

export KUBECONFIG=$PWD/kubeconfig
kubectl get nodes             # 1 control-plane + 2 workers Ready → Cilium is up
terraform output -raw argocd_initial_admin_password
```

After the apply, ArgoCD reconciles `gitops/` (Cilium config, ingress, Prometheus) and **Git
becomes the source of truth** — add tools by committing under `gitops/applications/`. See
[`docs/05-gitops-prometheus.md`](docs/05-gitops-prometheus.md).

> Already ran the old per-stage layout? See
> [`infrastructure/talos-cluster/README.MIGRATION.md`](infrastructure/talos-cluster/README.MIGRATION.md).

## Documentation

1. [Proxmox setup & least-privilege IAM](docs/01-proxmox-setup.md)
2. [Terraform: the Talos cluster](docs/02-terraform-cluster.md)
3. [Cilium CNI](docs/03-cilium.md)
4. [ArgoCD bootstrap & app-of-apps](docs/04-argocd-bootstrap.md)
5. [First GitOps tool: kube-prometheus-stack](docs/05-gitops-prometheus.md)
6. [Day-2 operations: scale, upgrade, teardown](docs/06-operations.md)
7. [Persistent storage (Proxmox CSI)](docs/07-storage.md)
