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
  environment  = "dev"
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

# Networking

module "vpc" {
  source = "../../modules/vpc"

  name         = local.name
  cluster_name = local.cluster_name
  vpc_cidr     = var.vpc_cidr

  availability_zones   = local.azs
  public_subnet_cidrs  = local.public_subnet_cidrs
  private_subnet_cidrs = local.private_subnet_cidrs

  # Dev trades zonal NAT redundancy for cost.
  single_nat_gateway       = true
  enable_flow_logs         = true
  flow_logs_retention_days = 14

  tags = local.tags
}

# EKS cluster

module "eks" {
  source = "../../modules/eks"

  cluster_name    = local.cluster_name
  cluster_version = var.cluster_version
  vpc_id          = module.vpc.vpc_id
  subnet_ids      = module.vpc.private_subnet_ids

  endpoint_public_access       = true
  endpoint_public_access_cidrs = var.cluster_endpoint_allowed_cidrs

  cluster_log_retention_days = 30

  node_groups = {
    general = {
      instance_types = ["t3.large"]
      min_size       = 1
      max_size       = 3
      desired_size   = 2
    }
    spot = {
      capacity_type  = "SPOT"
      instance_types = ["t3.large", "t3a.large", "m5.large"]
      min_size       = 0
      max_size       = 5
      desired_size   = 1
      labels = {
        "node.kubernetes.io/lifecycle" = "spot"
      }
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

# Observability
#
# Dev keeps Container Insights on and leaves the Prometheus stack optional
# to hold down cost.

module "observability" {
  source = "../../modules/observability"

  cluster_name      = module.eks.cluster_name
  oidc_provider_arn = module.eks.oidc_provider_arn

  enable_container_insights = true
  enable_prometheus_stack   = var.enable_prometheus_stack
  prometheus_retention      = "7d"
  prometheus_storage_size   = "20Gi"
  grafana_admin_password    = var.grafana_admin_password

  tags = local.tags

  depends_on = [module.eks]
}
