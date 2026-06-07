output "controlplane_nodes" {
  description = "Control-plane node addresses keyed by hostname."
  value       = { for k, v in var.controlplane_nodes : k => v.address }
}

output "worker_nodes" {
  description = "Worker node addresses keyed by hostname."
  value       = { for k, v in var.worker_nodes : k => v.address }
}

output "image_id" {
  description = "Datastore file ID of the downloaded Talos image."
  value       = proxmox_download_file.talos.id
}

# Completes only after the boot-wait; depend on this to order the talos stage.
output "boot_wait_id" {
  description = "ID of the boot-wait resource (dependency anchor)."
  value       = time_sleep.boot_wait.id
}
