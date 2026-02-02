# outputs.tf
output "vpc_id" {
  description = "VPC ID"
  value       = module.vpc.vpc_id
}

output "frontend_public_ip" {
  description = "Frontend EC2 public IP"
  value       = module.frontend.public_ip
}

output "frontend_public_dns" {
  description = "Frontend EC2 public DNS"
  value       = module.frontend.public_dns
}

output "backend_private_ip" {
  description = "Backend EC2 private IP"
  value       = module.backend.private_ip
}

output "rds_endpoint" {
  description = "RDS endpoint"
  value       = module.rds.db_endpoint
}

output "rds_database_name" {
  description = "RDS database name"
  value       = module.rds.db_name
}

output "ssh_command_frontend" {
  description = "SSH command for frontend"
  value       = "ssh -i ${var.key_name}.pem ec2-user@${module.frontend.public_ip}"
}