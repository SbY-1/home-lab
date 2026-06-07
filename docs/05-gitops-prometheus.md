# 05 — First GitOps tool: kube-prometheus-stack

The first application deployed purely via GitOps: **kube-prometheus-stack** (Prometheus,
Grafana, Alertmanager, node-exporter, kube-state-metrics).

## Where it lives

| File | Role |
|------|------|
| `gitops/argocd/apps/kube-prometheus-stack.yaml` | ArgoCD Application (chart ref + sync policy), project `monitoring` |
| `gitops/applications/monitoring/kube-prometheus-stack/values.yaml` | Helm values (retention, resources, Grafana ingress) |

The Application is **multi-source**: the chart comes from the prometheus-community Helm repo,
the values come from this repo via the `$values` reference.

## Deploy it

It deploys automatically once the root app is synced (see [04](04-argocd-bootstrap.md)). To
trigger/inspect manually:

```bash
kubectl -n argocd get applications
argocd app sync kube-prometheus-stack      # if you have the argocd CLI
kubectl -n monitoring get pods
```

## Access Grafana

Grafana is exposed through ingress-nginx at `grafana.homelab.lan`.

1. Find the ingress controller's LoadBalancer IP (from the Cilium pool):
   ```bash
   kubectl -n ingress-nginx get svc ingress-nginx-controller
   ```
2. Point DNS (or `/etc/hosts`) for `grafana.homelab.lan` at that IP.
3. Open `http://grafana.homelab.lan`. Get the admin password:
   ```bash
   kubectl -n monitoring get secret kube-prometheus-stack-grafana \
     -o jsonpath='{.data.admin-password}' | base64 -d; echo
   ```

> No DNS? Set `grafana.service.type: LoadBalancer` in `values.yaml` to reach Grafana directly
> on a pool IP instead of via ingress.

## Verify the stack

```bash
kubectl -n monitoring get pods
# Prometheus targets should be UP (port-forward and open /targets):
kubectl -n monitoring port-forward svc/kube-prometheus-stack-prometheus 9090:9090
```

## Talos-specific notes

- `kubeProxy` scraping is **disabled** — Cilium replaced kube-proxy.
- etcd / scheduler / controller-manager scraping is enabled; if a target is unreachable on
  your Talos version, set the matching `kube*.enabled: false` in `values.yaml`.

## Adding the next tool

1. `gitops/applications/<area>/<tool>/values.yaml`
2. `gitops/argocd/apps/<tool>.yaml` (Application; pick a project + sync-wave)
3. Commit & push — ArgoCD deploys it.

➡️ Next: [06 — Day-2 operations](06-operations.md)
