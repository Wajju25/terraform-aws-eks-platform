# EKS Module

Provisions an EKS control plane with managed node groups, an IAM OIDC provider for IRSA, KMS envelope encryption of Kubernetes secrets, control plane logging, and managed cluster addons.

## Design Notes

- Secrets are encrypted with a dedicated, rotating KMS key
- All five control plane log types ship to a Terraform-managed log group with explicit retention
- The private API endpoint is always on; public access is optional and CIDR-restricted
- Node groups accept both `ON_DEMAND` and `SPOT` capacity with labels and taints, and `desired_size` is ignored after creation so an autoscaler owns day-2 scaling
- Addon versions resolve to the most recent compatible release unless pinned, and the EBS CSI driver gets its own IRSA role automatically
- `authentication_mode` defaults to `API_AND_CONFIG_MAP`, which enables EKS access entries without breaking existing `aws-auth` workflows

## Usage

```hcl
module "eks" {
  source = "../../modules/eks"

  cluster_name    = "eks-platform-prod"
  cluster_version = "1.30"
  vpc_id          = module.vpc.vpc_id
  subnet_ids      = module.vpc.private_subnet_ids

  endpoint_public_access       = true
  endpoint_public_access_cidrs = ["203.0.113.0/24"]

  node_groups = {
    general = {
      instance_types = ["m6i.large"]
      min_size       = 3
      max_size       = 9
      desired_size   = 3
    }
    spot = {
      capacity_type  = "SPOT"
      instance_types = ["m6i.large", "m6a.large", "m5.large"]
      min_size       = 0
      max_size       = 12
      desired_size   = 3
      labels         = { "node.kubernetes.io/lifecycle" = "spot" }
    }
  }

  tags = local.tags
}
```

## Inputs

See `variables.tf` for the full typed and validated list. Key inputs: `cluster_name`, `cluster_version`, `subnet_ids`, `node_groups`, `cluster_addons`, `endpoint_public_access_cidrs`.

## Outputs

`cluster_name`, `cluster_endpoint`, `cluster_certificate_authority_data`, `oidc_provider_arn`, `oidc_issuer_url`, `node_role_arn`, `kms_key_arn`, `ebs_csi_role_arn`.
