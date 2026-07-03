output "cluster_name" {
  description = "Name of the EKS cluster."
  value       = aws_eks_cluster.this.name
}

output "cluster_arn" {
  description = "ARN of the EKS cluster."
  value       = aws_eks_cluster.this.arn
}

output "cluster_endpoint" {
  description = "HTTPS endpoint of the Kubernetes API server."
  value       = aws_eks_cluster.this.endpoint
}

output "cluster_version" {
  description = "Kubernetes version running on the control plane."
  value       = aws_eks_cluster.this.version
}

output "cluster_certificate_authority_data" {
  description = "Base64-encoded certificate authority data for the cluster."
  value       = aws_eks_cluster.this.certificate_authority[0].data
}

output "cluster_security_group_id" {
  description = "ID of the EKS-managed cluster security group."
  value       = aws_eks_cluster.this.vpc_config[0].cluster_security_group_id
}

output "cluster_additional_security_group_id" {
  description = "ID of the Terraform-managed additional security group attached to the control plane ENIs."
  value       = aws_security_group.cluster_additional.id
}

output "oidc_provider_arn" {
  description = "ARN of the IAM OIDC provider used for IRSA."
  value       = aws_iam_openid_connect_provider.this.arn
}

output "oidc_issuer_url" {
  description = "OIDC issuer URL of the cluster."
  value       = aws_eks_cluster.this.identity[0].oidc[0].issuer
}

output "node_role_arn" {
  description = "ARN of the shared IAM role used by managed node groups."
  value       = aws_iam_role.node.arn
}

output "node_group_arns" {
  description = "Map of node group key to node group ARN."
  value       = { for k, v in aws_eks_node_group.this : k => v.arn }
}

output "kms_key_arn" {
  description = "ARN of the KMS key encrypting Kubernetes secrets."
  value       = aws_kms_key.cluster.arn
}

output "ebs_csi_role_arn" {
  description = "ARN of the IRSA role bound to the EBS CSI driver controller service account."
  value       = aws_iam_role.ebs_csi.arn
}
