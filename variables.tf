variable "qovery_access_token" {
  description = "Qovery API token"
  type        = string
}

variable "qovery_organization_id" {
    description = "Qovery Organization ID where you will deploy your Airbyte stack"
    type        = string
}

variable "qovery_project_id" {
  description = "Qovery Project ID where you will deploy your Airbyte stack"
  type        = string
}

variable "qovery_cluster_id" {
  description = "Qovery Cluster ID where you will deploy your Airbyte stack"
  type        = string
}

variable "airbyte_helm_version" {
    description = "Airbyte Helm chart version"
    type        = string
    default     = "0.293.4"
}