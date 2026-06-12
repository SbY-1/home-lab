# gitops/secrets

Committed **SealedSecret** manifests. The `secrets` ArgoCD Application
(`gitops/argocd/apps/secrets.yaml`) applies every `*.yaml` here; the Sealed Secrets controller
(see [docs/09](../../docs/09-sealed-secrets.md)) decrypts each into a real `Secret` in its target
namespace.

Safe to commit — the encrypted payload can only be decrypted by the in-cluster controller.
**Never** commit a plain `Secret` here.

## Add a secret

```bash
kubectl create secret generic <name> -n <namespace> \
  --from-literal=<key>='<value>' --dry-run=client -o yaml \
| kubeseal --format yaml \
    --controller-namespace sealed-secrets --controller-name sealed-secrets-controller \
> gitops/secrets/<name>.sealedsecret.yaml

git add gitops/secrets/<name>.sealedsecret.yaml && git commit -m "add sealed <name>" && git push
```

Files ending in `.example` and this README are ignored by ArgoCD.
