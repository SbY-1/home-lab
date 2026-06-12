output "namespace" {
  description = "Namespace ArgoCD is installed into."
  value       = var.argocd_namespace
}

output "initial_admin_password" {
  description = "Initial 'admin' password. Rotate/delete the secret after first login."
  value       = try(data.kubernetes_secret.argocd_admin.data["password"], null)
  sensitive   = true
}

output "access_hint" {
  description = "How to reach the ArgoCD UI."
  value = var.argocd_hostname != "" ? "http://${var.argocd_hostname}" : (
    "kubectl -n ${var.argocd_namespace} port-forward svc/argocd-server 8080:443  # then https://localhost:8080"
  )
}
