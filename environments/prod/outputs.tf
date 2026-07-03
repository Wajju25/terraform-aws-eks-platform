output "vpc_id" {
  description = "ID of the prod VPC."
  value       = module.vpc.vpc_id
}

output "private_subnet_ids" {
  description = "Private subnet IDs used by the cluster."
  value       = module.vpc.private_subnet_ids
}

output "nat_gateway_public_ips" {
  description = "Egress IP addresses of the prod NAT gateways, for allowlisting with third parties."
  value       = module.vpc.nat_gateway_public_ips
}

output "cluster_name" {
  description = "Name of the EKS cluster."
  value       = module.eks.cluster_name
}

output "cluster_endpoint" {
  description = "Kubernetes API server endpoint."
  value       = module.eks.cluster_endpoint
}

output "oidc_provider_arn" {
  description = "ARN of the cluster IAM OIDC provider, for wiring additional IRSA roles."
  value       = module.eks.oidc_provider_arn
}

output "cluster_autoscaler_role_arn" {
  description = "IRSA role ARN for the cluster-autoscaler service account."
  value       = module.cluster_autoscaler_irsa.role_arn
}

output "monitoring_namespace" {
  description = "Namespace hosting the Prometheus stack."
  value       = module.observability.monitoring_namespace
}

output "configure_kubectl" {
  description = "Command that writes a kubeconfig entry for this cluster."
  value       = "aws eks update-kubeconfig --region ${var.region} --name ${module.eks.cluster_name}"
}
