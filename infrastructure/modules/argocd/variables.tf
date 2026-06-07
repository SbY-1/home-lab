variable "argocd_namespace" {
  description = "Namespace ArgoCD is installed into."
  type        = string
}

variable "argocd_chart_version" {
  description = "argo-cd Helm chart version."
  type        = string
}

variable "gitops_repo_url" {
  description = "HTTPS URL of the GitOps repository ArgoCD syncs from."
  type        = string
}

variable "gitops_repo_revision" {
  description = "Git branch/tag/revision ArgoCD tracks."
  type        = string
}

variable "gitops_root_path" {
  description = "Path in the repo holding the app-of-apps root resources."
  type        = string
}
