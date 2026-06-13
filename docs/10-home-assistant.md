# 10 — Home Assistant

The first **application** (vs cluster tooling) — home automation hub, in the `applications/`
tree and the `apps` AppProject.

## Where it lives

| File | Role |
|------|------|
| `gitops/argocd/apps/home-assistant.yaml` | ArgoCD Application (chart `home-assistant` 0.3.65), project `apps` |
| `gitops/applications/home-assistant/values.yaml` | Helm values (persistence, ingress, config) |

## Config choices

- **Storage:** 10Gi PVC on the `proxmox` StorageClass for `/config` (settings + SQLite history).
- **Ingress:** `home-assistant.home` via ingress-nginx; external-dns publishes it to Pi-hole.
- **Reverse-proxy fix:** `configuration.enabled: true` writes a `configuration.yaml` on first
  init with `http.use_x_forwarded_for` + `trusted_proxies`. Without it, HA returns **400 Bad
  Request** behind the ingress. `forceInit: false` means HA's own UI-managed config is never
  overwritten afterward. The chart's default `trusted_proxies` (`10.0.0.0/8`, …) already covers
  the Talos pod CIDR `10.244.0.0/16`.

## Deploy + verify

```bash
git add gitops docs README.md && git commit -m "add home-assistant" && git push

kubectl -n home-assistant get pods,pvc,ingress
dig +short home-assistant.home @192.168.30.53     # external-dns -> Pi-hole record
```

Open **http://home-assistant.home** and complete the onboarding wizard.

## Notes

- **Single replica / RWO volume** — HA is stateful (SQLite); don't scale it past 1.
- **Device discovery** (mDNS, Bluetooth, Zigbee/Z-Wave USB) needs host networking or device
  passthrough, which a plain Deployment doesn't do. For LAN/IP-based integrations this install is
  fine; for radios you'd add `hostNetwork`/device mounts or run those on a dedicated node.
- **Backups** — the `/config` PVC holds all state; include it in your volume backup strategy.
