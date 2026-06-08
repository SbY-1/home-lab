locals {
  cluster_endpoint = "https://${var.cluster_vip}:6443"
  all_nodes        = merge(var.controlplane_nodes, var.worker_nodes)

  # First control-plane node (used for bootstrap + kubeconfig retrieval).
  first_cp_address = values(var.controlplane_nodes)[0]

  # Shared cluster-level patch applied to every node:
  #  - Cilium owns the CNI and kube-proxy, so disable Talos' defaults.
  #  - Add the VIP to the API server cert SANs.
  #  - externalCloudProvider: kubelet runs with --cloud-provider=external so the
  #    Proxmox cloud-controller-manager can set each node's providerID
  #    (proxmox://region/vmid) + topology labels — required by the Proxmox CSI.
  #    Nodes carry the 'uninitialized' taint until the CCM initializes them.
  cluster_shared_patch = yamlencode({
    cluster = {
      network = {
        cni = {
          name = "none"
        }
      }
      proxy = {
        disabled = true
      }
      apiServer = {
        certSANs = [var.cluster_vip]
      }
      externalCloudProvider = {
        enabled = var.external_cloud_provider
      }
    }
  })

  # Run kubelet with --cloud-provider=external so each node gets the
  # 'uninitialized' taint and the Proxmox CCM can set its providerID + topology
  # labels. Without this, the CSI node plugin fails with empty region/zone.
  kubelet_external_patch = var.external_cloud_provider ? yamlencode({
    machine = {
      kubelet = {
        extraArgs = {
          "cloud-provider" = "external"
        }
      }
    }
  }) : ""

  # Cilium is bootstrapped as an inlineManifest on the control plane only.
  cilium_inline_patch = yamlencode({
    cluster = {
      inlineManifests = [
        {
          name     = "cilium"
          contents = data.helm_template.cilium.manifest
        }
      ]
    }
  })
}

resource "talos_machine_secrets" "this" {
  talos_version = var.talos_version
}

data "talos_machine_configuration" "controlplane" {
  cluster_name       = var.cluster_name
  cluster_endpoint   = local.cluster_endpoint
  machine_type       = "controlplane"
  machine_secrets    = talos_machine_secrets.this.machine_secrets
  talos_version      = var.talos_version
  kubernetes_version = var.kubernetes_version

  config_patches = compact([
    local.cluster_shared_patch,
    local.kubelet_external_patch,
    local.cilium_inline_patch,
  ])
}

data "talos_machine_configuration" "worker" {
  cluster_name       = var.cluster_name
  cluster_endpoint   = local.cluster_endpoint
  machine_type       = "worker"
  machine_secrets    = talos_machine_secrets.this.machine_secrets
  talos_version      = var.talos_version
  kubernetes_version = var.kubernetes_version

  config_patches = compact([
    local.cluster_shared_patch,
    local.kubelet_external_patch,
  ])
}

# Client config (talosctl) targeting all control-plane endpoints.
data "talos_client_configuration" "this" {
  cluster_name         = var.cluster_name
  client_configuration = talos_machine_secrets.this.client_configuration
  endpoints            = values(var.controlplane_nodes)
  nodes                = values(local.all_nodes)
}

# Apply machine config to each control-plane node (per-node network patch).
resource "talos_machine_configuration_apply" "controlplane" {
  for_each = var.controlplane_nodes

  client_configuration        = talos_machine_secrets.this.client_configuration
  machine_configuration_input = data.talos_machine_configuration.controlplane.machine_configuration
  node                        = each.value
  endpoint                    = each.value

  config_patches = [
    templatefile("${path.module}/patches/cp.yaml.tftpl", {
      address      = each.value
      network_cidr = var.network_cidr
      gateway      = var.gateway
      cluster_vip  = var.cluster_vip
      install_disk = var.install_disk
    })
  ]
}

# Apply machine config to each worker node.
resource "talos_machine_configuration_apply" "worker" {
  for_each = var.worker_nodes

  client_configuration        = talos_machine_secrets.this.client_configuration
  machine_configuration_input = data.talos_machine_configuration.worker.machine_configuration
  node                        = each.value
  endpoint                    = each.value

  config_patches = [
    templatefile("${path.module}/patches/worker.yaml.tftpl", {
      address      = each.value
      network_cidr = var.network_cidr
      gateway      = var.gateway
      install_disk = var.install_disk
    })
  ]
}

# Bootstrap etcd on the first control-plane node (run once).
resource "talos_machine_bootstrap" "this" {
  node                 = local.first_cp_address
  endpoint             = local.first_cp_address
  client_configuration = talos_machine_secrets.this.client_configuration

  depends_on = [talos_machine_configuration_apply.controlplane]
}

# Retrieve the kubeconfig once the API server (and Cilium) are up.
resource "talos_cluster_kubeconfig" "this" {
  node                 = local.first_cp_address
  endpoint             = var.cluster_vip
  client_configuration = talos_machine_secrets.this.client_configuration

  depends_on = [talos_machine_bootstrap.this]
}

# Wait for the cluster to be healthy (all nodes + control plane ready).
data "talos_cluster_health" "this" {
  client_configuration = talos_machine_secrets.this.client_configuration
  control_plane_nodes  = values(var.controlplane_nodes)
  worker_nodes         = values(var.worker_nodes)
  endpoints            = values(var.controlplane_nodes)

  depends_on = [
    talos_cluster_kubeconfig.this,
    talos_machine_configuration_apply.worker,
  ]
}

# Persist kubeconfig + talosconfig to disk (both gitignored).
resource "local_sensitive_file" "kubeconfig" {
  filename        = var.kubeconfig_path
  content         = talos_cluster_kubeconfig.this.kubeconfig_raw
  file_permission = "0600"
}

resource "local_sensitive_file" "talosconfig" {
  filename        = var.talosconfig_path
  content         = data.talos_client_configuration.this.talos_config
  file_permission = "0600"
}
