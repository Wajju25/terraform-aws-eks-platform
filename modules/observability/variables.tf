variable "cluster_name" {
  description = "Name of the EKS cluster to instrument."
  type        = string
}

variable "oidc_provider_arn" {
  description = "ARN of the cluster IAM OIDC provider, used to build the CloudWatch agent IRSA role."
  type        = string
}

variable "enable_container_insights" {
  description = "Whether to install the amazon-cloudwatch-observability addon for Container Insights."
  type        = bool
  default     = true
}

variable "container_insights_addon_version" {
  description = "Pin for the amazon-cloudwatch-observability addon version. Null resolves the most recent compatible release."
  type        = string
  default     = null
}

variable "enable_prometheus_stack" {
  description = "Whether to install kube-prometheus-stack (Prometheus, Grafana, and exporters) via Helm."
  type        = bool
  default     = true
}

variable "prometheus_stack_chart_version" {
  description = "Version of the kube-prometheus-stack Helm chart."
  type        = string
  default     = "61.3.2"
}

variable "monitoring_namespace" {
  description = "Kubernetes namespace for the Prometheus stack."
  type        = string
  default     = "monitoring"
}

variable "prometheus_retention" {
  description = "Metric retention period for Prometheus, for example 15d."
  type        = string
  default     = "15d"

  validation {
    condition     = can(regex("^[0-9]+(h|d|w|y)$", var.prometheus_retention))
    error_message = "prometheus_retention must be a duration such as 24h, 15d, or 4w."
  }
}

variable "prometheus_storage_class" {
  description = "StorageClass used for Prometheus and Grafana persistent volumes. Requires the EBS CSI driver."
  type        = string
  default     = "gp2"
}

variable "prometheus_storage_size" {
  description = "Persistent volume size for Prometheus."
  type        = string
  default     = "50Gi"
}

variable "enable_alertmanager" {
  description = "Whether to deploy Alertmanager as part of the Prometheus stack."
  type        = bool
  default     = true
}

variable "grafana_admin_password" {
  description = "Admin password for Grafana. Null keeps the chart default; set a real value through tfvars or a secrets manager in anything beyond a sandbox."
  type        = string
  default     = null
  sensitive   = true
}

variable "tags" {
  description = "Tags applied to every AWS resource created by this module."
  type        = map(string)
  default     = {}
}
