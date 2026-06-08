# ---------------------------------------------------------------------------
# Proxmox connection
# ---------------------------------------------------------------------------
variable "proxmox_endpoint" {
  description = "Proxmox VE API endpoint, e.g. https://pve.lan:8006/"
  type        = string
}

variable "proxmox_insecure" {
  description = "Skip TLS verification (true for self-signed homelab certs)."
  type        = bool
  default     = true
}

variable "proxmox_api_token" {
  description = "Scoped API token from infrastructure/proxmox-iam: 'terraform@pve!provisioner=SECRET'."
  type        = string
  sensitive   = true
}

variable "proxmox_node" {
  description = "Proxmox node name the VMs are created on."
  type        = string
}

variable "proxmox_datastore" {
  description = "Datastore for VM disks (e.g. 'local-lvm')."
  type        = string
  default     = "local-lvm"
}

variable "image_datastore" {
  description = "Datastore with the 'import' content type (file-based) for the Talos qcow2 image."
  type        = string
  default     = "local"
}

# ---------------------------------------------------------------------------
# Networking
# ---------------------------------------------------------------------------
variable "network_bridge" {
  description = "Proxmox network bridge for the VM NIC."
  type        = string
  default     = "vmbr0"
}

variable "network_vlan" {
  description = "VLAN tag for the VM NIC, or null for untagged."
  type        = number
  default     = null
}

variable "network_cidr" {
  description = "Prefix length of the node network (e.g. 24 for /24)."
  type        = number
  default     = 24
}

variable "gateway" {
  description = "Default gateway for the nodes."
  type        = string
}

variable "dns_servers" {
  description = "DNS servers for the nodes."
  type        = list(string)
  default     = ["1.1.1.1", "9.9.9.9"]
}

variable "cluster_vip" {
  description = "Virtual IP for the Kubernetes API (Talos VIP). Free IP on the node network."
  type        = string
}

# ---------------------------------------------------------------------------
# Cluster / versions
# ---------------------------------------------------------------------------
variable "cluster_name" {
  description = "Kubernetes cluster name."
  type        = string
  default     = "homelab"
}

variable "talos_version" {
  description = "Talos Linux version."
  type        = string
  default     = "v1.13.2"
}

variable "kubernetes_version" {
  description = "Kubernetes version to deploy (must be supported by the Talos version)."
  type        = string
  default     = "v1.36.1"
}

variable "talos_extensions" {
  description = "Talos Image Factory official system extensions to bake into the image."
  type        = list(string)
  default     = ["siderolabs/qemu-guest-agent"]
}

variable "install_disk" {
  description = "Disk Talos installs to / upgrades on (the imported boot disk)."
  type        = string
  default     = "/dev/sda"
}

variable "cilium_version" {
  description = "Cilium Helm chart version."
  type        = string
  default     = "1.17.4"
}

variable "boot_wait_seconds" {
  description = "Seconds to wait after VM creation for Talos to reach maintenance mode."
  type        = number
  default     = 90
}

# ---------------------------------------------------------------------------
# Node topology — scale by editing these maps (key = hostname).
# ---------------------------------------------------------------------------
variable "controlplane_nodes" {
  description = "Control-plane nodes keyed by hostname."
  type = map(object({
    vm_id   = number
    address = string
    cores   = optional(number, 2)
    memory  = optional(number, 4096)
    disk_gb = optional(number, 40)
  }))
  default = {
    "talos-cp-01" = { vm_id = 8001, address = "192.168.1.101" }
  }
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
  default = {
    "talos-worker-01" = { vm_id = 8011, address = "192.168.1.111" }
    "talos-worker-02" = { vm_id = 8012, address = "192.168.1.112" }
  }
}

# ---------------------------------------------------------------------------
# ArgoCD / GitOps
# ---------------------------------------------------------------------------
variable "argocd_namespace" {
  description = "Namespace ArgoCD is installed into."
  type        = string
  default     = "argocd"
}

variable "argocd_chart_version" {
  description = "argo-cd Helm chart version."
  type        = string
  default     = "7.8.2"
}

variable "gitops_repo_url" {
  description = "HTTPS URL of the GitOps repository ArgoCD syncs from."
  type        = string
}

variable "gitops_repo_revision" {
  description = "Git branch/tag/revision ArgoCD tracks."
  type        = string
  default     = "main"
}

variable "gitops_root_path" {
  description = "Path in the repo holding the app-of-apps root resources."
  type        = string
  default     = "gitops/argocd"
}

# ---------------------------------------------------------------------------
# Proxmox CSI / CCM (persistent storage). Token from the proxmox-iam stage.
# ---------------------------------------------------------------------------
variable "proxmox_csi_token_id" {
  description = "CSI token id from proxmox-iam, e.g. 'kubernetes-csi@pve!csi'."
  type        = string
}

variable "proxmox_csi_token_secret" {
  description = "CSI token secret from proxmox-iam."
  type        = string
  sensitive   = true
}

variable "proxmox_region" {
  description = "Logical Proxmox cluster name used as the CSI/CCM topology region (any consistent value)."
  type        = string
  default     = "homelab"
}

variable "proxmox_csi_storage" {
  description = "Proxmox storage ID that backs persistent volumes (e.g. 'local-lvm')."
  type        = string
  default     = "local-lvm"
}

variable "storage_class_name" {
  description = "Name of the default StorageClass created by the Proxmox CSI."
  type        = string
  default     = "proxmox"
}
