variable "cluster_name" {
  description = "Kubernetes cluster name."
  type        = string
}

variable "cluster_vip" {
  description = "Virtual IP for the Kubernetes API (Talos VIP)."
  type        = string
}

variable "talos_version" {
  description = "Talos Linux version."
  type        = string
}

variable "kubernetes_version" {
  description = "Kubernetes version to deploy."
  type        = string
}

variable "cilium_version" {
  description = "Cilium Helm chart version."
  type        = string
}

variable "network_cidr" {
  description = "Prefix length of the node network."
  type        = number
}

variable "gateway" {
  description = "Default gateway for the nodes."
  type        = string
}

variable "install_disk" {
  description = "Disk Talos installs to / upgrades on."
  type        = string
}

variable "controlplane_nodes" {
  description = "Control-plane node addresses keyed by hostname."
  type        = map(string)
}

variable "worker_nodes" {
  description = "Worker node addresses keyed by hostname."
  type        = map(string)
}

variable "kubeconfig_path" {
  description = "Where to write the generated kubeconfig file."
  type        = string
}

variable "talosconfig_path" {
  description = "Where to write the generated talosconfig file."
  type        = string
}
