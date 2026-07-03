variable "role_name" {
  description = "Name of the IAM role. Convention: <cluster-name>-<workload>, for example eks-platform-prod-external-dns."
  type        = string

  validation {
    condition     = length(var.role_name) <= 64
    error_message = "IAM role names are limited to 64 characters."
  }
}

variable "role_description" {
  description = "Description attached to the IAM role."
  type        = string
  default     = "IRSA role managed by Terraform"
}

variable "oidc_provider_arn" {
  description = "ARN of the cluster IAM OIDC provider, as exported by the eks module."
  type        = string

  validation {
    condition     = can(regex(":oidc-provider/", var.oidc_provider_arn))
    error_message = "oidc_provider_arn must be an IAM OIDC provider ARN."
  }
}

variable "service_accounts" {
  description = "Kubernetes service accounts allowed to assume this role."
  type = list(object({
    namespace = string
    name      = string
  }))

  validation {
    condition     = length(var.service_accounts) > 0
    error_message = "Provide at least one namespace/service-account pair."
  }
}

variable "policy_arns" {
  description = "Managed policy ARNs to attach to the role."
  type        = list(string)
  default     = []
}

variable "inline_policies" {
  description = "Inline policies keyed by policy name, with JSON policy documents as values."
  type        = map(string)
  default     = {}
}

variable "permissions_boundary_arn" {
  description = "Optional permissions boundary ARN applied to the role."
  type        = string
  default     = null
}

variable "max_session_duration" {
  description = "Maximum session duration in seconds for the role."
  type        = number
  default     = 3600

  validation {
    condition     = var.max_session_duration >= 3600 && var.max_session_duration <= 43200
    error_message = "max_session_duration must be between 3600 and 43200 seconds."
  }
}

variable "tags" {
  description = "Tags applied to the IAM role."
  type        = map(string)
  default     = {}
}
