output "namespace" {
  description = "Namespace the CCM + CSI run in."
  value       = kubernetes_namespace.csi.metadata[0].name
}

output "storage_class" {
  description = "Default StorageClass name backed by Proxmox."
  value       = kubernetes_storage_class_v1.proxmox.metadata[0].name
}
