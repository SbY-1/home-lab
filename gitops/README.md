# GitOps tree

Everything in the cluster (beyond the bootstrap) is declared here and reconciled by ArgoCD.

```
gitops/
├── argocd/
│   ├── projects/      AppProjects (platform, monitoring) — logical separation/RBAC
│   ├── apps/          The app-of-apps: one ArgoCD Application per component/tool
│   └── applicationsets/  (reserved for future multi-app / multi-env generators)
├── components/        Platform building blocks
│   ├── cilium/manifests/   CiliumLoadBalancerIPPool + L2 announcement policy
│   ├── ingress-nginx/      Helm values for the ingress controller
│   └── cert-manager/       Helm values for cert-manager
└── applications/      Deployed tools
    └── monitoring/kube-prometheus-stack/   Helm values (Prometheus/Grafana/Alertmanager)
```

## How it fits together

1. `infrastructure/modules/argocd` (part of the single root apply) creates a single **root**
   Application pointing at `gitops/argocd` (recursive). That is the only thing Terraform puts in
   the cluster.
2. The root app applies everything under `gitops/argocd/`: the **AppProjects** and the
   **child Applications** in `apps/`.
3. Each child Application pulls its target — raw manifests (`components/cilium/manifests`)
   or a Helm chart + a `values.yaml` from this repo (multi-source `$values`).
4. **Sync waves** order the rollout: `cilium-config` (-2) → `ingress-nginx`/`cert-manager`
   (-1) → `kube-prometheus-stack` (0).

## ⚠️ Before first sync: set the repo URL

The child Applications reference this repository by URL. Replace the placeholder once:

```bash
# from the repo root, after creating your GitHub repo
grep -rl 'github.com/CHANGEME/home-lab' gitops \
  | xargs sed -i '' 's#https://github.com/CHANGEME/home-lab.git#https://github.com/<you>/home-lab.git#g'
```

Use the **same** URL in `infrastructure/terraform.tfvars` (`gitops_repo_url`).

## Adding a new tool

Drop a `values.yaml` under `applications/<area>/<tool>/`, add one Application manifest in
`gitops/argocd/apps/<tool>.yaml`, commit, push. ArgoCD does the rest.
