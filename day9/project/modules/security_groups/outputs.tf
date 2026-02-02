# modules/security_groups/outputs.tf
output "frontend_sg_id" {
  description = "Frontend security group ID"
  value       = aws_security_group.frontend.id
}

output "backend_sg_id" {
  description = "Backend security group ID"
  value       = aws_security_group.backend.id
}

output "database_sg_id" {
  description = "Database security group ID"
  value       = aws_security_group.database.id
}