data "aws_partition" "current" {}

locals {
  partition = data.aws_partition.current.partition

  # OIDC issuer without the https:// scheme, used in IAM trust conditions.
  oidc_issuer = replace(aws_eks_cluster.this.identity[0].oidc[0].issuer, "https://", "")

  node_managed_policies = [
    "AmazonEKSWorkerNodePolicy",
    "AmazonEKS_CNI_Policy",
    "AmazonEC2ContainerRegistryReadOnly",
    "AmazonSSMManagedInstanceCore",
  ]

  tags = merge(var.tags, {
    "terraform-module" = "eks"
  })
}

# KMS key for envelope encryption of Kubernetes secrets

resource "aws_kms_key" "cluster" {
  description             = "EKS secret encryption key for ${var.cluster_name}"
  enable_key_rotation     = true
  deletion_window_in_days = var.kms_deletion_window_in_days

  tags = local.tags
}

resource "aws_kms_alias" "cluster" {
  name          = "alias/eks/${var.cluster_name}"
  target_key_id = aws_kms_key.cluster.key_id
}

# Control plane logging
#
# The log group is created ahead of the cluster so retention and tags are
# managed by Terraform instead of being created implicitly by EKS.

resource "aws_cloudwatch_log_group" "cluster" {
  name              = "/aws/eks/${var.cluster_name}/cluster"
  retention_in_days = var.cluster_log_retention_days

  tags = local.tags
}

# Cluster IAM role

data "aws_iam_policy_document" "cluster_assume" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["eks.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "cluster" {
  name               = "${var.cluster_name}-cluster"
  assume_role_policy = data.aws_iam_policy_document.cluster_assume.json

  tags = local.tags
}

resource "aws_iam_role_policy_attachment" "cluster" {
  role       = aws_iam_role.cluster.name
  policy_arn = "arn:${local.partition}:iam::aws:policy/AmazonEKSClusterPolicy"
}

# Additional cluster security group
#
# EKS creates and manages its own cluster security group. This one is an
# attachment point for rules the platform team adds later (for example,
# ingress from a bastion or CI runners) without touching the managed group.

resource "aws_security_group" "cluster_additional" {
  name_prefix = "${var.cluster_name}-additional-"
  description = "Additional security group for ${var.cluster_name} control plane ENIs"
  vpc_id      = var.vpc_id

  tags = merge(local.tags, {
    Name = "${var.cluster_name}-additional"
  })

  lifecycle {
    create_before_destroy = true
  }
}

# EKS cluster

resource "aws_eks_cluster" "this" {
  name     = var.cluster_name
  role_arn = aws_iam_role.cluster.arn
  version  = var.cluster_version

  vpc_config {
    subnet_ids              = var.subnet_ids
    security_group_ids      = [aws_security_group.cluster_additional.id]
    endpoint_private_access = true
    endpoint_public_access  = var.endpoint_public_access
    public_access_cidrs     = var.endpoint_public_access ? var.endpoint_public_access_cidrs : null
  }

  access_config {
    authentication_mode                         = var.authentication_mode
    bootstrap_cluster_creator_admin_permissions = true
  }

  encryption_config {
    resources = ["secrets"]

    provider {
      key_arn = aws_kms_key.cluster.arn
    }
  }

  enabled_cluster_log_types = var.cluster_enabled_log_types

  tags = local.tags

  depends_on = [
    aws_iam_role_policy_attachment.cluster,
    aws_cloudwatch_log_group.cluster,
  ]
}

# IAM OIDC provider for IRSA

data "tls_certificate" "oidc" {
  url = aws_eks_cluster.this.identity[0].oidc[0].issuer
}

resource "aws_iam_openid_connect_provider" "this" {
  url             = aws_eks_cluster.this.identity[0].oidc[0].issuer
  client_id_list  = ["sts.amazonaws.com"]
  thumbprint_list = [data.tls_certificate.oidc.certificates[0].sha1_fingerprint]

  tags = local.tags
}

# Node IAM role, shared by all managed node groups

data "aws_iam_policy_document" "node_assume" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "node" {
  name               = "${var.cluster_name}-node"
  assume_role_policy = data.aws_iam_policy_document.node_assume.json

  tags = local.tags
}

resource "aws_iam_role_policy_attachment" "node" {
  for_each = toset(local.node_managed_policies)

  role       = aws_iam_role.node.name
  policy_arn = "arn:${local.partition}:iam::aws:policy/${each.value}"
}

# Managed node groups
#
# desired_size is ignored after creation so cluster-autoscaler or Karpenter
# can own scaling without fighting Terraform on every plan.

resource "aws_eks_node_group" "this" {
  for_each = var.node_groups

  cluster_name    = aws_eks_cluster.this.name
  node_group_name = "${var.cluster_name}-${each.key}"
  node_role_arn   = aws_iam_role.node.arn
  subnet_ids      = var.subnet_ids
  version         = aws_eks_cluster.this.version

  capacity_type  = each.value.capacity_type
  instance_types = each.value.instance_types
  ami_type       = each.value.ami_type
  disk_size      = each.value.disk_size

  scaling_config {
    min_size     = each.value.min_size
    max_size     = each.value.max_size
    desired_size = each.value.desired_size
  }

  update_config {
    max_unavailable = each.value.max_unavailable
  }

  labels = each.value.labels

  dynamic "taint" {
    for_each = each.value.taints

    content {
      key    = taint.value.key
      value  = taint.value.value
      effect = taint.value.effect
    }
  }

  tags = merge(local.tags, {
    Name = "${var.cluster_name}-${each.key}"
  })

  lifecycle {
    ignore_changes = [scaling_config[0].desired_size]
  }

  depends_on = [aws_iam_role_policy_attachment.node]
}

# IRSA role for the EBS CSI driver addon

data "aws_iam_policy_document" "ebs_csi_assume" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRoleWithWebIdentity"]

    principals {
      type        = "Federated"
      identifiers = [aws_iam_openid_connect_provider.this.arn]
    }

    condition {
      test     = "StringEquals"
      variable = "${local.oidc_issuer}:sub"
      values   = ["system:serviceaccount:kube-system:ebs-csi-controller-sa"]
    }

    condition {
      test     = "StringEquals"
      variable = "${local.oidc_issuer}:aud"
      values   = ["sts.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "ebs_csi" {
  name               = "${var.cluster_name}-ebs-csi-driver"
  assume_role_policy = data.aws_iam_policy_document.ebs_csi_assume.json

  tags = local.tags
}

resource "aws_iam_role_policy_attachment" "ebs_csi" {
  role       = aws_iam_role.ebs_csi.name
  policy_arn = "arn:${local.partition}:iam::aws:policy/service-role/AmazonEBSCSIDriverPolicy"
}

# Cluster addons
#
# Versions resolve to the most recent compatible release unless pinned via
# var.cluster_addons. Addons wait for node groups so coredns can schedule.

data "aws_eks_addon_version" "this" {
  for_each = var.cluster_addons

  addon_name         = each.key
  kubernetes_version = aws_eks_cluster.this.version
  most_recent        = true
}

resource "aws_eks_addon" "this" {
  for_each = var.cluster_addons

  cluster_name                = aws_eks_cluster.this.name
  addon_name                  = each.key
  addon_version               = coalesce(each.value.addon_version, data.aws_eks_addon_version.this[each.key].version)
  resolve_conflicts_on_create = "OVERWRITE"
  resolve_conflicts_on_update = each.value.resolve_conflicts_on_update
  configuration_values        = each.value.configuration_values

  service_account_role_arn = each.key == "aws-ebs-csi-driver" ? aws_iam_role.ebs_csi.arn : null

  tags = local.tags

  depends_on = [aws_eks_node_group.this]
}
