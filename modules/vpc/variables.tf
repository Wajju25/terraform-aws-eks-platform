variable "name" {
  description = "Name prefix applied to all VPC resources, for example eks-platform-dev."
  type        = string

  validation {
    condition     = can(regex("^[a-z][a-z0-9-]{1,40}$", var.name))
    error_message = "Name must start with a letter, use lowercase letters, digits, and hyphens, and be 2-41 characters."
  }
}

variable "cluster_name" {
  description = "Name of the EKS cluster that will run in this VPC. Used for kubernetes.io subnet discovery tags."
  type        = string
}

variable "vpc_cidr" {
  description = "CIDR block for the VPC."
  type        = string

  validation {
    condition     = can(cidrhost(var.vpc_cidr, 0)) && tonumber(split("/", var.vpc_cidr)[1]) <= 20
    error_message = "vpc_cidr must be a valid IPv4 CIDR block with a /20 mask or larger to fit six subnets."
  }
}

variable "availability_zones" {
  description = "Availability zones to spread subnets across. Three AZs are recommended for production."
  type        = list(string)

  validation {
    condition     = length(var.availability_zones) >= 2 && length(var.availability_zones) <= 4
    error_message = "Provide between 2 and 4 availability zones."
  }
}

variable "public_subnet_cidrs" {
  description = "CIDR blocks for public subnets, one per availability zone, in the same order as availability_zones."
  type        = list(string)
}

variable "private_subnet_cidrs" {
  description = "CIDR blocks for private subnets, one per availability zone, in the same order as availability_zones."
  type        = list(string)
}

variable "enable_nat_gateway" {
  description = "Whether to create NAT gateways for private subnet egress."
  type        = bool
  default     = true
}

variable "single_nat_gateway" {
  description = "Use a single shared NAT gateway instead of one per AZ. Cuts cost at the expense of zonal fault isolation. Recommended for non-production only."
  type        = bool
  default     = false
}

variable "enable_flow_logs" {
  description = "Whether to enable VPC flow logs delivered to CloudWatch Logs."
  type        = bool
  default     = true
}

variable "flow_logs_retention_days" {
  description = "Retention period in days for the flow logs CloudWatch log group."
  type        = number
  default     = 30

  validation {
    condition = contains(
      [1, 3, 5, 7, 14, 30, 60, 90, 120, 150, 180, 365, 400, 545, 731, 1096, 1827, 2192, 2557, 2922, 3288, 3653],
      var.flow_logs_retention_days
    )
    error_message = "flow_logs_retention_days must be a retention value supported by CloudWatch Logs."
  }
}

variable "flow_logs_kms_key_arn" {
  description = "Optional KMS key ARN used to encrypt the flow logs log group. Defaults to the CloudWatch Logs service key when null."
  type        = string
  default     = null
}

variable "tags" {
  description = "Tags applied to every resource created by this module."
  type        = map(string)
  default     = {}
}
