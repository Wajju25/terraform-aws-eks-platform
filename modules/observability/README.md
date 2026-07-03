# Observability Module

Adds two layers of monitoring to an existing EKS cluster:

- **CloudWatch Container Insights** through the `amazon-cloudwatch-observability` managed addon, with an IRSA role for the CloudWatch agent built from the reusable `irsa` module
- **Prometheus and Grafana** through the `kube-prometheus-stack` Helm chart, with persistent storage, resource limits, and cluster-wide ServiceMonitor discovery

Both layers toggle independently, so a dev cluster can run Container Insights alone while prod runs the full stack.

## Requirements

- The EBS CSI driver addon must be installed (the `eks` module does this) so Prometheus and Grafana volumes can bind
- A configured `helm` provider in the calling root module, authenticated against the target cluster

## Usage

```hcl
module "observability" {
  source = "../../modules/observability"

  cluster_name      = module.eks.cluster_name
  oidc_provider_arn = module.eks.oidc_provider_arn

  enable_container_insights = true
  enable_prometheus_stack   = true
  prometheus_retention      = "30d"
  prometheus_storage_size   = "100Gi"
  grafana_admin_password    = var.grafana_admin_password

  tags = local.tags

  depends_on = [module.eks]
}
```

## Inputs

`cluster_name`, `oidc_provider_arn`, `enable_container_insights`, `enable_prometheus_stack`, `prometheus_stack_chart_version`, `prometheus_retention`, `prometheus_storage_class`, `prometheus_storage_size`, `enable_alertmanager`, `grafana_admin_password`, `tags`.

## Outputs

`cloudwatch_agent_role_arn`, `container_insights_addon_version`, `monitoring_namespace`, `prometheus_stack_release_name`.
