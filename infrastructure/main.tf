# ---------------------------------------------------------------------------
# Single root, single state: VMs -> Talos cluster (+Cilium) -> ArgoCD.
# Ordering is enforced by module-level depends_on (the VM boot-wait must finish
# before config apply; the cluster must exist before ArgoCD).
# ---------------------------------------------------------------------------

module "vms" {
  source = "./modules/vms"

  proxmox_node      = var.proxmox_node
  proxmox_datastore = var.proxmox_datastore
  image_datastore   = var.image_datastore

  network_bridge = var.network_bridge
  network_vlan   = var.network_vlan
  network_cidr   = var.network_cidr
  gateway        = var.gateway
  dns_servers    = var.dns_servers

  talos_version     = var.talos_version
  talos_extensions  = var.talos_extensions
  boot_wait_seconds = var.boot_wait_seconds

  controlplane_nodes = var.controlplane_nodes
  worker_nodes       = var.worker_nodes
}

module "talos" {
  source     = "./modules/talos"
  depends_on = [module.vms] # wait for VMs to boot into maintenance mode

  cluster_name       = var.cluster_name
  cluster_vip        = var.cluster_vip
  talos_version      = var.talos_version
  kubernetes_version = var.kubernetes_version
  cilium_version     = var.cilium_version

  network_cidr = var.network_cidr
  gateway      = var.gateway
  install_disk = var.install_disk

  # Node address maps (hostname -> address) from the vms module.
  controlplane_nodes = module.vms.controlplane_nodes
  worker_nodes       = module.vms.worker_nodes

  kubeconfig_path  = "${path.root}/kubeconfig"
  talosconfig_path = "${path.root}/talosconfig"
}

module "argocd" {
  source     = "./modules/argocd"
  depends_on = [module.talos] # cluster (and Cilium) must be up first

  providers = {
    helm       = helm.cluster
    kubernetes = kubernetes.cluster
  }

  argocd_namespace     = var.argocd_namespace
  argocd_chart_version = var.argocd_chart_version
  gitops_repo_url      = var.gitops_repo_url
  gitops_repo_revision = var.gitops_repo_revision
  gitops_root_path     = var.gitops_root_path
}
