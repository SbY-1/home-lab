output "cluster_endpoint" {
  description = "Kubernetes API endpoint (control-plane VIP)."
  value       = module.talos.cluster_endpoint
}

output "kubeconfig_path" {
  description = "Path to the generated kubeconfig."
  value       = module.talos.kubeconfig_path
}

output "talosconfig_path" {
  description = "Path to the generated talosconfig."
  value       = module.talos.talosconfig_path
}

output "control_plane_nodes" {
  description = "Control-plane node addresses."
  value       = module.vms.controlplane_nodes
}

output "worker_nodes" {
  description = "Worker node addresses."
  value       = module.vms.worker_nodes
}

output "argocd_namespace" {
  description = "Namespace ArgoCD is installed into."
  value       = module.argocd.namespace
}

output "argocd_initial_admin_password" {
  description = "ArgoCD initial admin password (rotate after first login)."
  value       = module.argocd.initial_admin_password
  sensitive   = true
}

output "argocd_access_hint" {
  description = "How to reach the ArgoCD UI."
  value       = module.argocd.access_hint
}
