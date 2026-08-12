# Outputs expose values needed by later phases and make the created
# resources inspectable with `terraform output` without opening the
# console.

output "vpc_id" {
  description = "ID of the VPC."
  value       = aws_vpc.main.id
}

output "public_subnet_ids" {
  description = "IDs of the public subnets, keyed by Availability Zone."
  value       = { for az, subnet in aws_subnet.public : az => subnet.id }
}

output "app_subnet_ids" {
  description = "IDs of the private application subnets, keyed by Availability Zone."
  value       = { for az, subnet in aws_subnet.app : az => subnet.id }
}

output "data_subnet_ids" {
  description = "IDs of the private database subnets, keyed by Availability Zone."
  value       = { for az, subnet in aws_subnet.data : az => subnet.id }
}

output "nat_gateway_public_ip" {
  description = "Public IP of the NAT Gateway, the source address for all outbound traffic from private subnets."
  value       = aws_eip.nat.public_ip
}