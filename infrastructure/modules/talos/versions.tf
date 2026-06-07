terraform {
  required_version = ">= 1.6"

  required_providers {
    talos = {
      source  = "siderolabs/talos"
      version = "~> 0.7"
    }
    # Default helm provider: client-side Cilium manifest templating (no cluster).
    helm = {
      source  = "hashicorp/helm"
      version = "~> 2.17"
    }
    local = {
      source  = "hashicorp/local"
      version = "~> 2.5"
    }
  }
}
