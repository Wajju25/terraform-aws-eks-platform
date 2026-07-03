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
  description = "CIDR block for the dev VPC."
  type        = string
  default     = "10.0.0.0/16"
}

variable "cluster_version" {
  description = "Kubernetes version for the EKS control plane."
  type        = string
  default     = "1.30"
}

variable "cluster_endpoint_allowed_cidrs" {
  description = "CIDR blocks allowed to reach the public cluster API endpoint. Narrow this to office or VPN ranges."
  type        = list(string)
  default     = ["0.0.0.0/0"]
}

variable "enable_prometheus_stack" {
  description = "Whether to install kube-prometheus-stack in dev. Container Insights is always on."
  type        = bool
  default     = false
}

variable "grafana_admin_password" {
  description = "Grafana admin password, only used when the Prometheus stack is enabled. Set through terraform.tfvars or TF_VAR_grafana_admin_password."
  type        = string
  default     = null
  sensitive   = true
}
