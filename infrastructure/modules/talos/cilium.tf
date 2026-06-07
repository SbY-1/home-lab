# Render the Cilium install manifest client-side. The output is embedded into
# the control-plane machine config as an inlineManifest, so the CNI is applied
# automatically when the cluster bootstraps (single `terraform apply`).
#
# Talos-specific values:
#   - kubeProxyReplacement: Cilium replaces kube-proxy (which we disable in Talos)
#   - k8sServiceHost/Port = localhost:7445 -> Talos KubePrism (API LB)
#   - cgroup.autoMount disabled + hostRoot: Talos mounts cgroup v2 itself
#   - securityContext capabilities: required under Talos' locked-down rootfs
#   - l2announcements: enabled so LoadBalancer IPs are announced on the LAN
#     (actual IP pools + L2 policy are managed via GitOps in gitops/components/cilium)
data "helm_template" "cilium" {
  name         = "cilium"
  namespace    = "kube-system"
  repository   = "https://helm.cilium.io"
  chart        = "cilium"
  version      = var.cilium_version
  kube_version = var.kubernetes_version

  values = [
    yamlencode({
      ipam = {
        mode = "kubernetes"
      }
      kubeProxyReplacement = true
      k8sServiceHost       = "localhost"
      k8sServicePort       = 7445

      securityContext = {
        capabilities = {
          ciliumAgent = [
            "CHOWN", "KILL", "NET_ADMIN", "NET_RAW", "IPC_LOCK", "SYS_ADMIN",
            "SYS_RESOURCE", "DAC_OVERRIDE", "FOWNER", "SETGID", "SETUID",
          ]
          cleanCiliumState = ["NET_ADMIN", "SYS_ADMIN", "SYS_RESOURCE"]
        }
      }

      cgroup = {
        autoMount = {
          enabled = false
        }
        hostRoot = "/sys/fs/cgroup"
      }

      l2announcements = {
        enabled = true
      }

      # Modest defaults for a small homelab cluster.
      operator = {
        replicas = 1
      }
    })
  ]
}
