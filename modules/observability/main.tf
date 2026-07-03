data "aws_partition" "current" {}

data "aws_eks_cluster" "this" {
  name = var.cluster_name
}

locals {
  partition = data.aws_partition.current.partition

  tags = merge(var.tags, {
    "terraform-module" = "observability"
  })
}

# CloudWatch Container Insights
#
# Installed through the amazon-cloudwatch-observability managed addon, which
# runs the CloudWatch agent and Fluent Bit. The agent authenticates with an
# IRSA role built from the reusable irsa module.

module "cloudwatch_agent_irsa" {
  source = "../irsa"

  count = var.enable_container_insights ? 1 : 0

  role_name         = "${var.cluster_name}-cloudwatch-agent"
  role_description  = "CloudWatch agent for Container Insights on ${var.cluster_name}"
  oidc_provider_arn = var.oidc_provider_arn

  service_accounts = [
    { namespace = "amazon-cloudwatch", name = "cloudwatch-agent" },
  ]

  policy_arns = [
    "arn:${local.partition}:iam::aws:policy/CloudWatchAgentServerPolicy",
    "arn:${local.partition}:iam::aws:policy/AWSXrayWriteOnlyAccess",
  ]

  tags = local.tags
}

data "aws_eks_addon_version" "container_insights" {
  count = var.enable_container_insights ? 1 : 0

  addon_name         = "amazon-cloudwatch-observability"
  kubernetes_version = data.aws_eks_cluster.this.version
  most_recent        = true
}

resource "aws_eks_addon" "container_insights" {
  count = var.enable_container_insights ? 1 : 0

  cluster_name                = var.cluster_name
  addon_name                  = "amazon-cloudwatch-observability"
  addon_version               = coalesce(var.container_insights_addon_version, data.aws_eks_addon_version.container_insights[0].version)
  resolve_conflicts_on_create = "OVERWRITE"
  resolve_conflicts_on_update = "OVERWRITE"
  service_account_role_arn    = module.cloudwatch_agent_irsa[0].role_arn

  tags = local.tags
}

# Prometheus and Grafana via kube-prometheus-stack

resource "helm_release" "kube_prometheus_stack" {
  count = var.enable_prometheus_stack ? 1 : 0

  name             = "kube-prometheus-stack"
  repository       = "https://prometheus-community.github.io/helm-charts"
  chart            = "kube-prometheus-stack"
  version          = var.prometheus_stack_chart_version
  namespace        = var.monitoring_namespace
  create_namespace = true

  timeout         = 600
  atomic          = true
  cleanup_on_fail = true

  values = [
    yamlencode({
      prometheus = {
        prometheusSpec = {
          retention = var.prometheus_retention
          resources = {
            requests = { cpu = "250m", memory = "1Gi" }
            limits   = { memory = "2Gi" }
          }
          storageSpec = {
            volumeClaimTemplate = {
              spec = {
                storageClassName = var.prometheus_storage_class
                accessModes      = ["ReadWriteOnce"]
                resources = {
                  requests = { storage = var.prometheus_storage_size }
                }
              }
            }
          }
          # Pick up ServiceMonitors and PodMonitors from every namespace,
          # not only releases of this chart.
          serviceMonitorSelectorNilUsesHelmValues = false
          podMonitorSelectorNilUsesHelmValues     = false
        }
      }
      grafana = {
        enabled = true
        persistence = {
          enabled          = true
          storageClassName = var.prometheus_storage_class
          size             = "10Gi"
        }
        resources = {
          requests = { cpu = "100m", memory = "256Mi" }
          limits   = { memory = "512Mi" }
        }
      }
      alertmanager = {
        enabled = var.enable_alertmanager
      }
    }),
  ]

  dynamic "set_sensitive" {
    for_each = var.grafana_admin_password == null ? [] : [1]

    content {
      name  = "grafana.adminPassword"
      value = var.grafana_admin_password
    }
  }
}
