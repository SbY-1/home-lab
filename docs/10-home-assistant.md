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

## HACS (Home Assistant Community Store)

HACS is a custom integration installed into `/config/custom_components/hacs`. An **init
container** (`install-hacs`, in the values) downloads the latest HACS release into the config
volume before HA starts — idempotent (skips if already present; HACS self-updates from the UI
afterward, so it's never overwritten).

After the pod is running, finish setup in the UI (one-time, interactive — it can't be automated
because it needs your GitHub login):

1. **Settings → Devices & Services → Add Integration → "HACS"**.
2. Tick the acknowledgement boxes, then complete the **GitHub device authorization**
   (it shows a code + opens github.com/login/device).
3. HACS appears in the sidebar; you can now install community integrations/cards.

Verify the files landed:
```bash
kubectl -n home-assistant exec deploy/home-assistant -- ls /config/custom_components/hacs
kubectl -n home-assistant logs deploy/home-assistant -c install-hacs   # "HACS installed"
```

> The init container needs egress to `github.com` to download the release — fine on a normal
> LAN. HACS itself also reaches the GitHub API at runtime to list/install community content.

## Notes

- **Single replica / RWO volume** — HA is stateful (SQLite); don't scale it past 1.
- **Device discovery** (mDNS, Bluetooth, Zigbee/Z-Wave USB) needs host networking or device
  passthrough, which a plain Deployment doesn't do. For LAN/IP-based integrations this install is
  fine; for radios you'd add `hostNetwork`/device mounts or run those on a dedicated node.
- **Backups** — the `/config` PVC holds all state; include it in your volume backup strategy.
