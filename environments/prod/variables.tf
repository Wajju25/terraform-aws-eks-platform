variable "project" {
  description = "Project slug used in resource names and tags."
  type        = string
  default     = "eks-platform"
}

variable "owner" {
  description = "Team or person responsible for these resources, recorded in the Owner tag."
  type        = string
  default     = "platform-engineering"
}

variable "cost_center" {
  description = "Cost allocation tag value."
  type        = string
  default     = "engineering"
}

variable "region" {
  description = "AWS region for all resources."
  type        = string
  default     = "us-east-1"
}

variable "vpc_cidr" {
  description = "CIDR block for the prod VPC. Keep it disjoint from dev to allow future peering."
  type        = string
  default     = "10.1.0.0/16"
}

variable "cluster_version" {
  description = "Kubernetes version for the EKS control plane."
  type        = string
  default     = "1.30"
}

variable "cluster_endpoint_public_access" {
  description = "Whether the cluster API endpoint is reachable from the internet. Set false once private connectivity (VPN or Direct Connect) exists."
  type        = bool
  default     = true
}

variable "cluster_endpoint_allowed_cidrs" {
  description = "CIDR blocks allowed to reach the public cluster API endpoint. Must not be 0.0.0.0/0 in production."
  type        = list(string)

  validation {
    condition     = !contains(var.cluster_endpoint_allowed_cidrs, "0.0.0.0/0")
    error_message = "Refusing 0.0.0.0/0 for the prod API endpoint. List explicit office or VPN CIDR ranges."
  }
}

variable "grafana_admin_password" {
  description = "Grafana admin password. Set through TF_VAR_grafana_admin_password or a secrets manager, never committed."
  type        = string
  sensitive   = true
}
