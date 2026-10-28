# Outputs make the created resources inspectable with `terraform output`
# without opening the console.

output "vpc_id" {
  description = "ID of the VPC."
  value       = module.vpc.vpc_id
}

output "public_subnet_ids" {
  description = "IDs of the public subnets, keyed by Availability Zone."
  value       = module.vpc.public_subnet_ids
}

output "app_subnet_ids" {
  description = "IDs of the private application subnets, keyed by Availability Zone."
  value       = module.vpc.app_subnet_ids
}

output "data_subnet_ids" {
  description = "IDs of the private database subnets, keyed by Availability Zone."
  value       = module.vpc.data_subnet_ids
}

output "app_data_bucket_name" {
  description = "Name of the application data S3 bucket."
  value       = module.app_data.bucket_id
}

output "nat_gateway_public_ip" {
  description = "Public IP of the NAT Gateway. Null when the NAT Gateway is disabled."
  value       = module.vpc.nat_gateway_public_ip
}
