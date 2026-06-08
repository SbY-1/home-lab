locals {
  # Shared Proxmox connection block consumed by both CCM and CSI charts.
  proxmox_config = {
    features = {
      provider = "default"
    }
    clusters = [
      {
        url          = var.proxmox_url
        insecure     = var.proxmox_insecure
        token_id     = var.proxmox_token_id
        token_secret = var.proxmox_token_secret
        region       = var.region
      }
    ]
  }
}

resource "kubernetes_namespace" "csi" {
  metadata {
    name = var.namespace
    labels = {
      # CSI node plugin is privileged (host mounts) — Talos enforces PodSecurity.
      "pod-security.kubernetes.io/enforce" = "privileged"
    }
  }
}

# Cloud-controller-manager: assigns providerID (proxmox://region/vmid) + topology
# labels and clears the 'uninitialized' taint. Runs on control-plane nodes and
# tolerates the uninitialized taint (chart defaults).
resource "helm_release" "ccm" {
  name       = "proxmox-cloud-controller-manager"
  namespace  = kubernetes_namespace.csi.metadata[0].name
  repository = "oci://ghcr.io/sergelogvinov/charts"
  chart      = "proxmox-cloud-controller-manager"
  version    = var.ccm_chart_version

  wait    = true
  timeout = 300

  values = [
    yamlencode({
      config = local.proxmox_config
    })
  ]
}

# CSI plugin: provisions + attaches Proxmox disks as PVs.
resource "helm_release" "csi" {
  name       = "proxmox-csi-plugin"
  namespace  = kubernetes_namespace.csi.metadata[0].name
  repository = "oci://ghcr.io/sergelogvinov/charts"
  chart      = "proxmox-csi-plugin"
  version    = var.csi_chart_version

  depends_on = [helm_release.ccm]

  values = [
    yamlencode({
      config = local.proxmox_config
      # Run the node DaemonSet on every node regardless of taints.
      node = {
        tolerations = [
          { operator = "Exists" }
        ]
      }
      # StorageClass is managed separately (below) so we can mark it default.
      storageClass = []
    })
  ]
}

# Default StorageClass backed by Proxmox storage.
resource "kubernetes_storage_class_v1" "proxmox" {
  metadata {
    name = var.storage_class_name
    annotations = {
      "storageclass.kubernetes.io/is-default-class" = "true"
    }
  }

  storage_provisioner    = "csi.proxmox.sinextra.dev"
  reclaim_policy         = "Delete"
  volume_binding_mode    = "WaitForFirstConsumer"
  allow_volume_expansion = true

  parameters = {
    "storage"                   = var.proxmox_storage
    "csi.storage.k8s.io/fstype" = var.fstype
    "ssd"                       = tostring(var.ssd)
    "cache"                     = "writethrough"
  }

  depends_on = [helm_release.csi]
}
