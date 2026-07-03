output "role_arn" {
  description = "ARN of the IAM role. Annotate the Kubernetes service account with eks.amazonaws.com/role-arn set to this value."
  value       = aws_iam_role.this.arn
}

output "role_name" {
  description = "Name of the IAM role."
  value       = aws_iam_role.this.name
}
