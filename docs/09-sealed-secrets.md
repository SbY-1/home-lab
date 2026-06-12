# 09 — Sealed Secrets

Lets you keep secrets **in git, encrypted**. You seal a Secret with `kubeseal` against the
controller's public key and commit the resulting `SealedSecret`; the in-cluster controller is
the only thing that can decrypt it (its private key never leaves the cluster). This replaces the
hand-created secrets (e.g. the Pi-hole password).

## Where it lives

| File | Role |
|------|------|
| `gitops/argocd/apps/sealed-secrets.yaml` | ArgoCD Application (chart `sealed-secrets` 2.18.6), project `platform`, sync-wave `-2` |
| `gitops/components/sealed-secrets/values.yaml` | Controller name + resources |

The controller installs into the `sealed-secrets` namespace as `sealed-secrets-controller`.

## Install the `kubeseal` CLI (workstation)

```bash
brew install kubeseal     # macOS; or grab the release binary for your OS
```

## Verify the controller

```bash
kubectl -n sealed-secrets get pods
kubeseal --controller-namespace sealed-secrets --controller-name sealed-secrets-controller \
  --fetch-cert > /tmp/sealed-secrets.pem   # the public cert; safe to keep/commit
```

## Seal a secret (example: migrate the Pi-hole password)

Build the Secret locally (never committed), pipe it through `kubeseal`, commit the encrypted
output:

```bash
kubectl create secret generic external-dns-pihole -n external-dns \
  --from-literal=EXTERNAL_DNS_PIHOLE_PASSWORD='<your-pi-hole-password>' \
  --dry-run=client -o yaml \
| kubeseal --format yaml \
    --controller-namespace sealed-secrets --controller-name sealed-secrets-controller \
> gitops/components/external-dns/sealedsecret-pihole.yaml
```

`sealedsecret-pihole.yaml` is safe to commit. The controller decrypts it into the
`external-dns-pihole` Secret in the `external-dns` namespace — replacing the
`kubectl create secret` step in [08](08-external-dns.md).

> A `SealedSecret` is namespace+name scoped by default, so it only unseals to the exact
> namespace/name you built it for.

## Applying SealedSecrets via GitOps

Commit sealed manifests under [`gitops/secrets/`](../gitops/secrets/) named
`*.sealedsecret.yaml`. The **`secrets`** Application (`gitops/argocd/apps/secrets.yaml`) is a
directory source that applies them (sync-wave `-1`, after the controller). Each SealedSecret
declares its own `metadata.namespace`, so one folder feeds Secrets to any namespace.

```bash
# seal directly into the folder, then commit:
kubectl create secret generic external-dns-pihole -n external-dns \
  --from-literal=EXTERNAL_DNS_PIHOLE_PASSWORD='<pw>' --dry-run=client -o yaml \
| kubeseal --format yaml \
    --controller-namespace sealed-secrets --controller-name sealed-secrets-controller \
> gitops/secrets/external-dns-pihole.sealedsecret.yaml
git add gitops/secrets && git commit -m "seal pihole password" && git push
```

ArgoCD applies the SealedSecret → the controller unseals it into the `external-dns-pihole`
Secret → you can drop the manual `kubectl create secret` from [08](08-external-dns.md).
See [`gitops/secrets/external-dns-pihole.sealedsecret.yaml.example`](../gitops/secrets/external-dns-pihole.sealedsecret.yaml.example).

## ⚠️ Back up the sealing key

The controller's private key lives in a Secret in the `sealed-secrets` namespace. If you lose it
(cluster rebuild), committed SealedSecrets can't be decrypted. Back it up:

```bash
kubectl -n sealed-secrets get secret -l sealedsecrets.bitnami.com/sealed-secrets-key \
  -o yaml > sealed-secrets-key.backup.yaml   # store OFF-cluster, encrypted; never commit
```
