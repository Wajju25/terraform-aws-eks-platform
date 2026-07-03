output "vpc_id" {
  description = "ID of the VPC."
  value       = aws_vpc.this.id
}

output "vpc_cidr" {
  description = "CIDR block of the VPC."
  value       = aws_vpc.this.cidr_block
}

output "public_subnet_ids" {
  description = "IDs of the public subnets."
  value       = aws_subnet.public[*].id
}

output "private_subnet_ids" {
  description = "IDs of the private subnets."
  value       = aws_subnet.private[*].id
}

output "nat_gateway_public_ips" {
  description = "Public IP addresses of the NAT gateways. Useful for allowlisting egress traffic."
  value       = aws_eip.nat[*].public_ip
}

output "private_route_table_ids" {
  description = "IDs of the private route tables, one per availability zone."
  value       = aws_route_table.private[*].id
}

output "availability_zones" {
  description = "Availability zones used by the subnets."
  value       = var.availability_zones
}

output "flow_logs_log_group_name" {
  description = "Name of the CloudWatch log group receiving VPC flow logs, or null when flow logs are disabled."
  value       = var.enable_flow_logs ? aws_cloudwatch_log_group.flow_logs[0].name : null
}
