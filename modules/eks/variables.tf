variable "cluster_name" {
  description = "Name of the EKS cluster."
  type        = string

  validation {
    condition     = can(regex("^[a-zA-Z][a-zA-Z0-9-_]{0,99}$", var.cluster_name))
    error_message = "cluster_name must start with a letter and contain only alphanumerics, hyphens, and underscores (max 100 characters)."
  }
}

variable "cluster_version" {
  description = "Kubernetes minor version for the control plane, for example 1.30."
  type        = string

  validation {
    condition     = can(regex("^1\\.(2[7-9]|3[0-9])$", var.cluster_version))
    error_message = "cluster_version must be a supported EKS version between 1.27 and 1.39."
  }
}

variable "vpc_id" {
  description = "ID of the VPC the cluster runs in."
  type        = string
}

variable "subnet_ids" {
  description = "Private subnet IDs for the control plane ENIs and worker nodes."
  type        = list(string)

  validation {
    condition     = length(var.subnet_ids) >= 2
    error_message = "EKS requires subnets in at least two availability zones."
  }
}

variable "endpoint_public_access" {
  description = "Whether the cluster API endpoint is reachable from the internet. The private endpoint is always enabled."
  type        = bool
  default     = true
}

variable "endpoint_public_access_cidrs" {
  description = "CIDR blocks allowed to reach the public API endpoint. Narrow this to office or VPN ranges in production."
  type        = list(string)
  default     = ["0.0.0.0/0"]
}

variable "authentication_mode" {
  description = "Cluster authentication mode. API_AND_CONFIG_MAP keeps aws-auth compatibility while enabling EKS access entries."
  type        = string
  default     = "API_AND_CONFIG_MAP"

  validation {
    condition     = contains(["API", "API_AND_CONFIG_MAP", "CONFIG_MAP"], var.authentication_mode)
    error_message = "authentication_mode must be API, API_AND_CONFIG_MAP, or CONFIG_MAP."
  }
}

variable "cluster_enabled_log_types" {
  description = "Control plane log types shipped to CloudWatch Logs."
  type        = list(string)
  default     = ["api", "audit", "authenticator", "controllerManager", "scheduler"]

  validation {
    condition = alltrue([
      for t in var.cluster_enabled_log_types :
      contains(["api", "audit", "authenticator", "controllerManager", "scheduler"], t)
    ])
    error_message = "Valid log types are api, audit, authenticator, controllerManager, and scheduler."
  }
}

variable "cluster_log_retention_days" {
  description = "Retention period in days for control plane logs."
  type        = number
  default     = 90
}

variable "kms_deletion_window_in_days" {
  description = "Waiting period before the secret-encryption KMS key is deleted after destroy."
  type        = number
  default     = 30

  validation {
    condition     = var.kms_deletion_window_in_days >= 7 && var.kms_deletion_window_in_days <= 30
    error_message = "kms_deletion_window_in_days must be between 7 and 30."
  }
}

variable "node_groups" {
  description = "Map of managed node groups keyed by a short name. Supports on-demand and spot capacity, labels, and taints."
  type = map(object({
    instance_types  = list(string)
    capacity_type   = optional(string, "ON_DEMAND")
    min_size        = number
    max_size        = number
    desired_size    = number
    disk_size       = optional(number, 50)
    ami_type        = optional(string, "AL2023_x86_64_STANDARD")
    max_unavailable = optional(number, 1)
    labels          = optional(map(string), {})
    taints = optional(list(object({
      key    = string
      value  = optional(string)
      effect = string
    })), [])
  }))

  validation {
    condition = alltrue([
      for ng in values(var.node_groups) : contains(["ON_DEMAND", "SPOT"], ng.capacity_type)
    ])
    error_message = "capacity_type must be ON_DEMAND or SPOT."
  }

  validation {
    condition = alltrue([
      for ng in values(var.node_groups) : ng.min_size <= ng.desired_size && ng.desired_size <= ng.max_size
    ])
    error_message = "Each node group must satisfy min_size <= desired_size <= max_size."
  }
}

variable "cluster_addons" {
  description = "EKS managed addons to install. Leave addon_version null to resolve the most recent compatible release."
  type = map(object({
    addon_version               = optional(string)
    resolve_conflicts_on_update = optional(string, "OVERWRITE")
    configuration_values        = optional(string)
  }))
  default = {
    vpc-cni            = {}
    coredns            = {}
    kube-proxy         = {}
    aws-ebs-csi-driver = {}
  }
}

variable "tags" {
  description = "Tags applied to every resource created by this module."
  type        = map(string)
  default     = {}
}
