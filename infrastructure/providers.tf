provider "proxmox" {
  endpoint  = var.proxmox_endpoint
  insecure  = var.proxmox_insecure
  api_token = var.proxmox_api_token
  # No `ssh` block: VM disk import uses the qcow2 + disk.import_from (API only).
}

provider "talos" {}

# Default helm provider: client-side templating only (Cilium manifest). No
# cluster connection — used by module.talos.
provider "helm" {}

# Cluster-connected providers, configured from the Talos-generated kubeconfig.
# These are evaluated only after module.talos creates the cluster (their config
# references its outputs), so the whole stack converges in a single apply.
provider "helm" {
  alias = "cluster"
  kubernetes {
    host                   = module.talos.kube_host
    cluster_ca_certificate = base64decode(module.talos.kube_ca_certificate)
    client_certificate     = base64decode(module.talos.kube_client_certificate)
    client_key             = base64decode(module.talos.kube_client_key)
  }
}

provider "kubernetes" {
  alias                  = "cluster"
  host                   = module.talos.kube_host
  cluster_ca_certificate = base64decode(module.talos.kube_ca_certificate)
  client_certificate     = base64decode(module.talos.kube_client_certificate)
  client_key             = base64decode(module.talos.kube_client_key)
}
