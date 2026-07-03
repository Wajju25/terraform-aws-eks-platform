terraform {
  required_version = ">= 1.6.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.70"
    }
    helm = {
      source  = "hashicorp/helm"
      version = "~> 2.15"
    }
  }
}

provider "aws" {
  region = var.region

  default_tags {
    tags = local.tags
  }
}

# Helm authenticates against the cluster with a short-lived token from the
# caller's AWS credentials, so no kubeconfig file is required.
provider "helm" {
  kubernetes {
    host                   = module.eks.cluster_endpoint
    cluster_ca_certificate = base64decode(module.eks.cluster_certificate_authority_data)

    exec {
      api_version = "client.authentication.k8s.io/v1beta1"
      command     = "aws"
      args        = ["eks", "get-token", "--cluster-name", module.eks.cluster_name, "--region", var.region]
    }
  }
}

data "aws_availability_zones" "available" {
  state = "available"

  filter {
    name   = "opt-in-status"
    values = ["opt-in-not-required"]
  }
}

locals {
  environment  = "prod"
  name         = "${var.project}-${local.environment}"
  cluster_name = "${var.project}-${local.environment}"

  azs = slice(data.aws_availability_zones.available.names, 0, 3)

  # /16 VPC split into /20 subnets: indexes 0-2 public, 8-10 private.
  public_subnet_cidrs  = [for i in range(3) : cidrsubnet(var.vpc_cidr, 4, i)]
  private_subnet_cidrs = [for i in range(3) : cidrsubnet(var.vpc_cidr, 4, i + 8)]

  tags = {
    Project     = var.project
    Environment = local.environment
    ManagedBy   = "terraform"
    Owner       = var.owner
    CostCenter  = var.cost_center
  }
}

# Networking — one NAT gateway per AZ for zonal fault isolation

module "vpc" {
  source = "../../modules/vpc"

  name         = local.name
  cluster_name = local.cluster_name
  vpc_cidr     = var.vpc_cidr

  availability_zones   = local.azs
  public_subnet_cidrs  = local.public_subnet_cidrs
  private_subnet_cidrs = local.private_subnet_cidrs

  single_nat_gateway       = false
  enable_flow_logs         = true
  flow_logs_retention_days = 90

  tags = local.tags
}

# EKS cluster

module "eks" {
  source = "../../modules/eks"

  cluster_name    = local.cluster_name
  cluster_version = var.cluster_version
  vpc_id          = module.vpc.vpc_id
  subnet_ids      = module.vpc.private_subnet_ids

  endpoint_public_access       = var.cluster_endpoint_public_access
  endpoint_public_access_cidrs = var.cluster_endpoint_allowed_cidrs

  cluster_log_retention_days = 90

  node_groups = {
    # Steady-state workloads on on-demand capacity.
    general = {
      instance_types = ["m6i.large"]
      min_size       = 3
      max_size       = 9
      desired_size   = 3
    }
    # Interruption-tolerant workloads on spot. Diversified instance types
    # keep the spot pools deep; the taint keeps unaware workloads off.
    spot = {
      capacity_type  = "SPOT"
      instance_types = ["m6i.large", "m6a.large", "m5.large", "m5a.large"]
      min_size       = 0
      max_size       = 12
      desired_size   = 3
      labels = {
        "node.kubernetes.io/lifecycle" = "spot"
      }
      taints = [
        {
          key    = "spot"
          value  = "true"
          effect = "NO_SCHEDULE"
        },
      ]
    }
  }

  tags = local.tags
}

# IRSA example: cluster-autoscaler

module "cluster_autoscaler_irsa" {
  source = "../../modules/irsa"

  role_name         = "${local.cluster_name}-cluster-autoscaler"
  role_description  = "cluster-autoscaler for ${local.cluster_name}"
  oidc_provider_arn = module.eks.oidc_provider_arn

  service_accounts = [
    { namespace = "kube-system", name = "cluster-autoscaler" },
  ]

  inline_policies = {
    cluster-autoscaler = jsonencode({
      Version = "2012-10-17"
      Statement = [
        {
          Sid    = "Describe"
          Effect = "Allow"
          Action = [
            "autoscaling:DescribeAutoScalingGroups",
            "autoscaling:DescribeAutoScalingInstances",
            "autoscaling:DescribeLaunchConfigurations",
            "autoscaling:DescribeScalingActivities",
            "ec2:DescribeImages",
            "ec2:DescribeInstanceTypes",
            "ec2:DescribeLaunchTemplateVersions",
            "ec2:GetInstanceTypesFromInstanceRequirements",
            "eks:DescribeNodegroup",
          ]
          Resource = "*"
        },
        {
          Sid    = "Scale"
          Effect = "Allow"
          Action = [
            "autoscaling:SetDesiredCapacity",
            "autoscaling:TerminateInstanceInAutoScalingGroup",
          ]
          Resource = "*"
          Condition = {
            StringEquals = {
              "aws:ResourceTag/kubernetes.io/cluster/${local.cluster_name}" = "owned"
            }
          }
        },
      ]
    })
  }

  tags = local.tags
}

# Observability — Container Insights plus the full Prometheus stack

module "observability" {
  source = "../../modules/observability"

  cluster_name      = module.eks.cluster_name
  oidc_provider_arn = module.eks.oidc_provider_arn

  enable_container_insights = true
  enable_prometheus_stack   = true
  prometheus_retention      = "30d"
  prometheus_storage_size   = "100Gi"
  enable_alertmanager       = true
  grafana_admin_password    = var.grafana_admin_password

  tags = local.tags

  depends_on = [module.eks]
}
