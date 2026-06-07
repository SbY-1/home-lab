resource "proxmox_virtual_environment_vm" "controlplane" {
  for_each = var.controlplane_nodes

  name      = each.key
  node_name = var.proxmox_node
  vm_id     = each.value.vm_id
  tags      = ["talos", "k8s", "controlplane"]
  on_boot   = true

  agent {
    enabled = true
  }

  operating_system {
    type = "l26"
  }

  cpu {
    cores = each.value.cores
    type  = "host"
  }

  memory {
    dedicated = each.value.memory
  }

  # Boot disk created from the downloaded Talos nocloud qcow2 image (API import).
  disk {
    datastore_id = var.proxmox_datastore
    import_from  = proxmox_download_file.talos.id
    interface    = "scsi0"
    size         = each.value.disk_gb
    file_format  = "raw"
  }

  network_device {
    bridge  = var.network_bridge
    vlan_id = var.network_vlan
  }

  # cloud-init (nocloud) provides a deterministic IP + hostname so the node is
  # reachable in Talos maintenance mode before the machine config is applied.
  initialization {
    datastore_id = var.proxmox_datastore
    ip_config {
      ipv4 {
        address = "${each.value.address}/${var.network_cidr}"
        gateway = var.gateway
      }
    }
    dns {
      servers = var.dns_servers
    }
  }

  serial_device {}
}

resource "proxmox_virtual_environment_vm" "worker" {
  for_each = var.worker_nodes

  name      = each.key
  node_name = var.proxmox_node
  vm_id     = each.value.vm_id
  tags      = ["talos", "k8s", "worker"]
  on_boot   = true

  agent {
    enabled = true
  }

  operating_system {
    type = "l26"
  }

  cpu {
    cores = each.value.cores
    type  = "host"
  }

  memory {
    dedicated = each.value.memory
  }

  disk {
    datastore_id = var.proxmox_datastore
    import_from  = proxmox_download_file.talos.id
    interface    = "scsi0"
    size         = each.value.disk_gb
    file_format  = "raw"
  }

  network_device {
    bridge  = var.network_bridge
    vlan_id = var.network_vlan
  }

  initialization {
    datastore_id = var.proxmox_datastore
    ip_config {
      ipv4 {
        address = "${each.value.address}/${var.network_cidr}"
        gateway = var.gateway
      }
    }
    dns {
      servers = var.dns_servers
    }
  }

  serial_device {}
}

# Give Talos time to boot into maintenance mode before config is applied
# (consumed by the talos module via the module-level dependency).
resource "time_sleep" "boot_wait" {
  depends_on = [
    proxmox_virtual_environment_vm.controlplane,
    proxmox_virtual_environment_vm.worker,
  ]
  create_duration = "${var.boot_wait_seconds}s"
}
