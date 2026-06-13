# GitOps tree

Everything in the cluster (beyond the bootstrap) is declared here and reconciled by ArgoCD.

```
gitops/
├── argocd/
│   ├── projects/      AppProjects (platform, monitoring, apps) — logical separation/RBAC
│   ├── apps/          The app-of-apps: one ArgoCD Application per component/app
│   └── applicationsets/  (reserved for future multi-app / multi-env generators)
├── components/        Cluster TOOLING / addons (platform building blocks)
│   ├── cilium/manifests/      CiliumLoadBalancerIPPool + L2 announcement policy
│   ├── ingress-nginx/         Helm values for the ingress controller
│   ├── cert-manager/          Helm values for cert-manager
│   ├── external-dns/          Helm values (Pi-hole provider)
│   ├── sealed-secrets/        Helm values (secrets controller)
│   ├── metrics-server/        Helm values
│   └── kube-prometheus-stack/ Helm values (Prometheus/Grafana/Alertmanager)
├── applications/      Real user-facing APPLICATIONS (project: apps)
│   └── home-assistant/        Helm values (Home Assistant)
└── secrets/           Committed SealedSecret manifests (encrypted)
```

**`components/` vs `applications/`** — `components/` is cluster tooling/addons (CNI, ingress,
DNS, storage, secrets, observability) in the `platform`/`monitoring` projects; `applications/`
is the actual workloads you run (e.g. Home Assistant) in the `apps` project.

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
  | xargs sed -i '' 's#https://github.com/SbY-1/home-lab.git#https://github.com/<you>/home-lab.git#g'
```

Use the **same** URL in `infrastructure/terraform.tfvars` (`gitops_repo_url`).

## Adding something new

- **Cluster tool/addon** → `components/<tool>/values.yaml`, Application in
  `gitops/argocd/apps/<tool>.yaml` with `project: platform` (or `monitoring`).
- **Real application** → `applications/<app>/values.yaml`, Application in
  `gitops/argocd/apps/<app>.yaml` with `project: apps`.

Then commit + push — ArgoCD does the rest.
