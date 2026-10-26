output "instance_id" {
  description = "ID of the instance. Pass it to `aws ssm start-session --target` to open a shell."
  value       = aws_instance.this.id
}

output "private_ip" {
  description = "Private IP address of the instance."
  value       = aws_instance.this.private_ip
}

output "security_group_id" {
  description = "ID of the instance's security group, for other resources to allow traffic from or to it."
  value       = aws_security_group.this.id
}

output "iam_role_name" {
  description = "Name of the instance's IAM role, for attaching further policies."
  value       = aws_iam_role.this.name
}

output "iam_role_arn" {
  description = "ARN of the instance's IAM role."
  value       = aws_iam_role.this.arn
}
