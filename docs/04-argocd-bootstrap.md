# 04 — ArgoCD bootstrap & app-of-apps

Installs ArgoCD with Terraform and creates the single **root** Application that turns this Git
repo into the source of truth for everything else.

## What this module does (`infrastructure/modules/argocd/`)

Part of the single root apply (runs after the cluster is up — `module.argocd` `depends_on`
`module.talos`, and its `kubernetes`/`helm` providers are wired from the Talos kubeconfig
outputs in `infrastructure/providers.tf`).

- `main.tf`: creates the `argocd` namespace and installs the **argo-cd** Helm chart
  (`wait = true`, so its CRDs are established before the next step).
- The **root app-of-apps** is created by a *second* `helm_release` using a tiny local chart
  (`charts/root-app`) that `depends_on` the ArgoCD release. This avoids the
  "no matches for kind Application / ensure CRDs are installed first" error you hit when the
  Application lived in the same release as its own CRD. It points at `gitops/argocd` (recursive).

## The app-of-apps pattern

```
root (Terraform)  ──▶  gitops/argocd/
                         ├── projects/   (AppProjects: platform, monitoring)
                         └── apps/        (one Application per component/tool)
                                ├── cilium-config        → gitops/components/cilium/manifests
                                ├── ingress-nginx        → Helm + gitops/components/ingress-nginx
                                ├── cert-manager         → Helm + gitops/components/cert-manager
                                └── kube-prometheus-stack → Helm + gitops/applications/...
```

After the apply, Terraform's job is done — new tools are added by committing to Git, not by
running Terraform.

## Run it

ArgoCD is installed by the **same `terraform apply`** as the cluster (see
[02](02-terraform-cluster.md)). Just set `gitops_repo_url` in `infrastructure/terraform.tfvars`
and make sure the repo URL is replaced in the GitOps manifests (see
[gitops/README](../gitops/README.md)) and pushed to GitHub.

```bash
terraform -chdir=infrastructure apply
terraform -chdir=infrastructure output -raw argocd_initial_admin_password   # login as admin
```

## Access the UI

```bash
kubectl -n argocd port-forward svc/argocd-server 8080:443
# open https://localhost:8080  (user: admin)
```

You should see the `root` app `Synced/Healthy`, with the child apps appearing underneath and
syncing in wave order.

## Notes

- The `kubernetes`/`helm` providers connect using the Talos-generated kubeconfig (wired in
  `infrastructure/providers.tf` from `module.talos` outputs) — no kubeconfig file path needed.
- `prune` + `selfHeal` are on: drift is auto-corrected, deletions in Git are pruned.
- Rotate the initial admin password after first login and delete
  `argocd-initial-admin-secret`.

➡️ Next: [05 — First GitOps tool: kube-prometheus-stack](05-gitops-prometheus.md)
