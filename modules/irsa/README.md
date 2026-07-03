# IRSA Module

Reusable IAM Roles for Service Accounts. Creates an IAM role whose trust policy only allows the named Kubernetes service accounts to assume it through the cluster OIDC provider, with both `sub` and `aud` conditions enforced.

## Usage

```hcl
module "external_dns_irsa" {
  source = "../../modules/irsa"

  role_name         = "${module.eks.cluster_name}-external-dns"
  oidc_provider_arn = module.eks.oidc_provider_arn

  service_accounts = [
    { namespace = "kube-system", name = "external-dns" },
  ]

  inline_policies = {
    route53 = jsonencode({
      Version = "2012-10-17"
      Statement = [{
        Effect   = "Allow"
        Action   = ["route53:ChangeResourceRecordSets"]
        Resource = "arn:aws:route53:::hostedzone/*"
      }]
    })
  }

  tags = local.tags
}
```

Then annotate the service account:

```yaml
apiVersion: v1
kind: ServiceAccount
metadata:
  name: external-dns
  namespace: kube-system
  annotations:
    eks.amazonaws.com/role-arn: <role_arn output>
```

## Inputs

`role_name`, `oidc_provider_arn`, `service_accounts`, `policy_arns`, `inline_policies`, `permissions_boundary_arn`, `max_session_duration`, `tags`.

## Outputs

`role_arn`, `role_name`.
