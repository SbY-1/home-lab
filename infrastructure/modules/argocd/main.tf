resource "kubernetes_namespace" "argocd" {
  metadata {
    name = var.argocd_namespace
  }
}

# 1) Install ArgoCD itself (controllers + CRDs).
resource "helm_release" "argocd" {
  name       = "argocd"
  namespace  = kubernetes_namespace.argocd.metadata[0].name
  repository = "https://argoproj.github.io/argo-helm"
  chart      = "argo-cd"
  version    = var.argocd_chart_version

  # wait=true so the Application CRD is established before the root app below.
  wait    = true
  timeout = 600

  values = [
    yamlencode({
      configs = {
        cm = {
          # Use Server-Side Diff for all apps: diffing is delegated to the
          # kube-apiserver's schema instead of ArgoCD's older bundled schema.
          # Fixes "field not declared in schema" errors (e.g. status.terminatingReplicas)
          # that the structured-merge diff hits with ServerSideApply on newer K8s.
          "controller.diff.server.side" = "true"
        }
      }
    })
  ]
}

# 2) Create the app-of-apps root Application in a SEPARATE release that runs
#    AFTER ArgoCD's CRDs exist (a local chart keeps this helm-only — the root
#    Application can't live in the release that installs its own CRD).
resource "helm_release" "root_app" {
  name      = "argocd-root-app"
  namespace = kubernetes_namespace.argocd.metadata[0].name
  chart     = "${path.module}/charts/root-app"

  depends_on = [helm_release.argocd]

  values = [
    yamlencode({
      namespace      = var.argocd_namespace
      repoURL        = var.gitops_repo_url
      targetRevision = var.gitops_repo_revision
      path           = var.gitops_root_path
    })
  ]
}

# Initial admin password (deferred to apply via depends_on so it isn't read at
# plan time before the cluster/secret exist).
data "kubernetes_secret" "argocd_admin" {
  metadata {
    name      = "argocd-initial-admin-secret"
    namespace = var.argocd_namespace
  }
  depends_on = [helm_release.argocd]
}
