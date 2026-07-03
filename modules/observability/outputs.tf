output "cloudwatch_agent_role_arn" {
  description = "ARN of the CloudWatch agent IRSA role, or null when Container Insights is disabled."
  value       = var.enable_container_insights ? module.cloudwatch_agent_irsa[0].role_arn : null
}

output "container_insights_addon_version" {
  description = "Installed version of the amazon-cloudwatch-observability addon, or null when disabled."
  value       = var.enable_container_insights ? aws_eks_addon.container_insights[0].addon_version : null
}

output "monitoring_namespace" {
  description = "Namespace hosting the Prometheus stack, or null when the stack is disabled."
  value       = var.enable_prometheus_stack ? var.monitoring_namespace : null
}

output "prometheus_stack_release_name" {
  description = "Helm release name of kube-prometheus-stack, or null when disabled."
  value       = var.enable_prometheus_stack ? helm_release.kube_prometheus_stack[0].name : null
}
