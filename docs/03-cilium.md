# 03 — Cilium CNI

Talos ships with **no default CNI**, so the cluster has no pod networking until one is
installed. We use **Cilium** as both the CNI and the **kube-proxy replacement**.

## How it's installed

`infrastructure/modules/talos/cilium.tf` renders the Cilium chart client-side
(`helm_template` data source) and the result is embedded into the control-plane machine config
as a Talos **inlineManifest** (`modules/talos/main.tf` → `cilium_inline_patch`). When the cluster
bootstraps, Talos applies that manifest automatically — so Cilium comes up as part of the same
`terraform apply`, with no chicken-and-egg.

The matching Talos settings (in `cluster_shared_patch`):

- `cluster.network.cni.name: none` — Talos installs no CNI; Cilium owns it.
- `cluster.proxy.disabled: true` — no kube-proxy; Cilium replaces it.

## Talos-specific Helm values (why they're needed)

| Value | Reason |
|-------|--------|
| `kubeProxyReplacement: true` | Cilium provides Service load-balancing in eBPF |
| `k8sServiceHost: localhost`, `k8sServicePort: 7445` | Reach the API via Talos **KubePrism** (local API load balancer) without kube-proxy |
| `cgroup.autoMount.enabled: false`, `cgroup.hostRoot: /sys/fs/cgroup` | Talos mounts cgroup v2 itself |
| `securityContext.capabilities.*` | Required under Talos' locked-down, read-only rootfs |
| `ipam.mode: kubernetes` | Use the node PodCIDRs |
| `l2announcements.enabled: true` | Announce LoadBalancer IPs on the LAN (config in GitOps) |

## LAN exposure (LoadBalancer without MetalLB)

Cilium's **L2 announcements + LoadBalancer IPAM** replace MetalLB. The runtime config lives in
GitOps (`gitops/components/cilium/manifests/`) and is reconciled by ArgoCD:

- `CiliumLoadBalancerIPPool` — the LAN IP range handed to `type: LoadBalancer` Services.
  **Edit the range** to match free IPs on your network.
- `CiliumL2AnnouncementPolicy` — answers ARP for those IPs from all nodes.

## Verify

```bash
kubectl -n kube-system get pods -l k8s-app=cilium      # agents Running
kubectl get nodes                                       # Ready == CNI healthy
# Optional, with the Cilium CLI:
cilium status
cilium config view | grep -i kube-proxy-replacement     # true
# Confirm no kube-proxy DaemonSet exists:
kubectl -n kube-system get ds kube-proxy 2>&1 | grep -q NotFound && echo "kube-proxy absent (good)"
```

## Upgrading Cilium

Bump `cilium_version` and `terraform apply` to update the inline manifest, then let Talos
reconcile — or, for finer control, migrate Cilium management to a GitOps Application later
(the L2/IPAM config already lives in `gitops/`).

➡️ Next: [04 — ArgoCD bootstrap & app-of-apps](04-argocd-bootstrap.md)
