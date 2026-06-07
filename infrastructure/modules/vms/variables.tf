variable "proxmox_node" {
  description = "Proxmox node name the VMs are created on."
  type        = string
}

variable "proxmox_datastore" {
  description = "Datastore for VM disks."
  type        = string
}

variable "image_datastore" {
  description = "Datastore (with 'import' content type, file-based) for the Talos qcow2 image."
  type        = string
}

variable "network_bridge" {
  description = "Proxmox bridge for the VM NIC."
  type        = string
}

variable "network_vlan" {
  description = "VLAN tag for the VM NIC, or null."
  type        = number
  default     = null
}

variable "network_cidr" {
  description = "Prefix length of the node network."
  type        = number
}

variable "gateway" {
  description = "Default gateway for the nodes."
  type        = string
}

variable "dns_servers" {
  description = "DNS servers for the nodes."
  type        = list(string)
}

variable "talos_version" {
  description = "Talos Linux version (image)."
  type        = string
}

variable "talos_extensions" {
  description = "Talos Image Factory official system extensions to bake into the image."
  type        = list(string)
}

variable "boot_wait_seconds" {
  description = "Seconds to wait after VM creation for Talos to reach maintenance mode."
  type        = number
}

variable "controlplane_nodes" {
  description = "Control-plane nodes keyed by hostname."
  type = map(object({
    vm_id   = number
    address = string
    cores   = optional(number, 2)
    memory  = optional(number, 4096)
    disk_gb = optional(number, 40)
  }))
}

variable "worker_nodes" {
  description = "Worker nodes keyed by hostname."
  type = map(object({
    vm_id   = number
    address = string
    cores   = optional(number, 2)
    memory  = optional(number, 4096)
    disk_gb = optional(number, 40)
  }))
}
