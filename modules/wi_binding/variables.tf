variable "gsa_name" {
  description = "GSA fully-qualified name (projects/PROJECT/serviceAccounts/EMAIL)"
  type        = string
}

variable "project_id" {
  description = "GCP project ID (used to construct the Workload Identity pool domain)"
  type        = string
}

variable "k8s_namespace" {
  description = "Kubernetes namespace where the KSA lives"
  type        = string
}

variable "ksa_name" {
  description = "Kubernetes Service Account name"
  type        = string
}
