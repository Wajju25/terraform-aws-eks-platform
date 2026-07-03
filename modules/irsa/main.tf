locals {
  # arn:aws:iam::<account>:oidc-provider/oidc.eks.<region>.amazonaws.com/id/<id>
  # -> oidc.eks.<region>.amazonaws.com/id/<id>
  oidc_provider = element(split("/oidc-provider/", var.oidc_provider_arn), 1)

  tags = merge(var.tags, {
    "terraform-module" = "irsa"
  })
}

data "aws_iam_policy_document" "assume" {
  statement {
    sid     = "AssumeRoleWithWebIdentity"
    effect  = "Allow"
    actions = ["sts:AssumeRoleWithWebIdentity"]

    principals {
      type        = "Federated"
      identifiers = [var.oidc_provider_arn]
    }

    condition {
      test     = "StringEquals"
      variable = "${local.oidc_provider}:sub"
      values = [
        for sa in var.service_accounts :
        "system:serviceaccount:${sa.namespace}:${sa.name}"
      ]
    }

    condition {
      test     = "StringEquals"
      variable = "${local.oidc_provider}:aud"
      values   = ["sts.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "this" {
  name                 = var.role_name
  description          = var.role_description
  assume_role_policy   = data.aws_iam_policy_document.assume.json
  permissions_boundary = var.permissions_boundary_arn
  max_session_duration = var.max_session_duration

  tags = local.tags
}

resource "aws_iam_role_policy_attachment" "managed" {
  for_each = toset(var.policy_arns)

  role       = aws_iam_role.this.name
  policy_arn = each.value
}

resource "aws_iam_role_policy" "inline" {
  for_each = var.inline_policies

  name   = each.key
  role   = aws_iam_role.this.id
  policy = each.value
}
