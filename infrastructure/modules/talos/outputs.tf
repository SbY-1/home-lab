output "kubeconfig_raw" {
  description = "Raw kubeconfig contents."
  value       = talos_cluster_kubeconfig.this.kubeconfig_raw
  sensitive   = true
}

output "kubeconfig_path" {
  description = "Path to the written kubeconfig."
  value       = local_sensitive_file.kubeconfig.filename
}

output "talosconfig_path" {
  description = "Path to the written talosconfig."
  value       = local_sensitive_file.talosconfig.filename
}

output "cluster_endpoint" {
  description = "Kubernetes API endpoint (control-plane VIP)."
  value       = local.cluster_endpoint
}

# Structured client creds for configuring kubernetes/helm providers in the root.
output "kube_host" {
  description = "Kubernetes API host URL."
  value       = talos_cluster_kubeconfig.this.kubernetes_client_configuration.host
}

output "kube_ca_certificate" {
  description = "Base64 cluster CA certificate."
  value       = talos_cluster_kubeconfig.this.kubernetes_client_configuration.ca_certificate
  sensitive   = true
}

output "kube_client_certificate" {
  description = "Base64 client certificate."
  value       = talos_cluster_kubeconfig.this.kubernetes_client_configuration.client_certificate
  sensitive   = true
}

output "kube_client_key" {
  description = "Base64 client key."
  value       = talos_cluster_kubeconfig.this.kubernetes_client_configuration.client_key
  sensitive   = true
}
