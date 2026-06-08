# 08 — external-dns → Pi-hole

Automatically publishes DNS records to **Pi-hole** for your Ingress hosts and LoadBalancer
Services, so names like `grafana.home` resolve to the ingress-nginx LoadBalancer IP — no manual
Pi-hole "Local DNS" entries.

## Where it lives

| File | Role |
|------|------|
| `gitops/argocd/apps/external-dns.yaml` | ArgoCD Application (chart `external-dns` 1.21.1), project `platform` |
| `gitops/components/external-dns/values.yaml` | Helm values: Pi-hole provider, sources, domain filter |

## How it works

external-dns watches Ingresses/Services, and for each host it writes an A record into Pi-hole's
local DNS pointing at the resolved LB/ingress IP. Pi-hole can't store the TXT *ownership* records
external-dns normally uses, so it runs with `registry: noop` + `policy: upsert-only` — it
**creates/updates** records but never deletes (removing an Ingress won't remove the record;
delete it in Pi-hole if needed).

## One-time setup

1. **Edit the Pi-hole server URL** in `gitops/components/external-dns/values.yaml`
   (`--pihole-server=http://<your-pi-hole>`), and the `domainFilters` if your domain isn't `home`.
   Keep `--pihole-api-version=6` for Pi-hole v6; remove it for v5.

2. **Create the password Secret** (kept out of git — use your Pi-hole *web/admin* password, or an
   app password on v6). Create the namespace first so it exists before the pod starts:
   ```bash
   kubectl create namespace external-dns
   kubectl -n external-dns create secret generic external-dns-pihole \
     --from-literal=EXTERNAL_DNS_PIHOLE_PASSWORD='<your-pi-hole-password>'
   ```

3. **Commit + push** — ArgoCD deploys it (sync-wave `-1`, before apps):
   ```bash
   git add gitops docs && git commit -m "add external-dns + pihole" && git push
   ```

## Verify

```bash
kubectl -n external-dns get pods
kubectl -n external-dns logs deploy/external-dns | tail -30   # "add record" lines, no auth errors

# After Grafana's ingress is up, the record should resolve via Pi-hole:
dig +short grafana.home @<pi-hole-ip>
```

You can point your LAN clients' DNS at Pi-hole and `grafana.home` (and any future ingress host)
just works.

## Notes / troubleshooting

- **Login/auth errors** → wrong password or wrong `--pihole-api-version`. v6 uses the app/admin
  password and the new API; v5 uses the web password.
- **Record has no target** → the Ingress/Service has no external IP yet (check ingress-nginx has
  its Cilium LoadBalancer IP).
- **Secret management** → this is the first app secret created by hand. To bring it under GitOps
  later, adopt SOPS or Sealed Secrets (already flagged as a future step in the repo).
