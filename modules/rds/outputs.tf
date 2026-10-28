output "db_instance_id" {
  description = "Identifier of the database instance."
  value       = aws_db_instance.this.id
}

output "address" {
  description = "DNS name of the database. Resolves only inside the VPC."
  value       = aws_db_instance.this.address
}

output "port" {
  description = "Port the database listens on."
  value       = aws_db_instance.this.port
}

output "security_group_id" {
  description = "ID of the database's security group."
  value       = aws_security_group.this.id
}

output "master_user_secret_arn" {
  description = "ARN of the Secrets Manager secret that holds the master password. The password itself is never an output."
  value       = one(aws_db_instance.this.master_user_secret[*].secret_arn)
}
