output "vpc_id" {
  description = "ID of the VPC."
  value       = aws_vpc.main.id
}

output "vpc_cidr_block" {
  description = "CIDR block of the VPC."
  value       = aws_vpc.main.cidr_block
}

output "availability_zones" {
  description = "Availability Zones the subnets are spread across."
  value       = local.azs
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
  description = "Public IP of the NAT Gateway, the source address for outbound traffic from the app subnets. Null when the NAT Gateway is disabled."
  value       = one(aws_eip.nat[*].public_ip)
}
