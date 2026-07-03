# VPC Module

Provisions a VPC laid out for an EKS cluster: public and private subnets across up to four availability zones, NAT gateways, and VPC flow logs to CloudWatch.

## Design Notes

- Public subnets are tagged with `kubernetes.io/role/elb` and private subnets with `kubernetes.io/role/internal-elb` so the AWS Load Balancer Controller can discover them
- Private subnets also carry `karpenter.sh/discovery` so a future Karpenter installation can find them without changes here
- One private route table per AZ, so `single_nat_gateway = false` gives each AZ an independent egress path
- Flow logs write to a dedicated CloudWatch log group with configurable retention and optional KMS encryption

## Usage

```hcl
module "vpc" {
  source = "../../modules/vpc"

  name         = "eks-platform-dev"
  cluster_name = "eks-platform-dev"
  vpc_cidr     = "10.0.0.0/16"

  availability_zones   = ["us-east-1a", "us-east-1b", "us-east-1c"]
  public_subnet_cidrs  = ["10.0.0.0/20", "10.0.16.0/20", "10.0.32.0/20"]
  private_subnet_cidrs = ["10.0.128.0/20", "10.0.144.0/20", "10.0.160.0/20"]

  single_nat_gateway = true # dev only

  tags = local.tags
}
```

## Inputs

See `variables.tf` for the full typed and validated list. Key inputs: `name`, `cluster_name`, `vpc_cidr`, `availability_zones`, `public_subnet_cidrs`, `private_subnet_cidrs`, `single_nat_gateway`, `enable_flow_logs`.

## Outputs

`vpc_id`, `public_subnet_ids`, `private_subnet_ids`, `nat_gateway_public_ips`, `private_route_table_ids`, `flow_logs_log_group_name`.
