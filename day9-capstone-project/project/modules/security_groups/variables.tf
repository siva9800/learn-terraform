
# modules/security_groups/variables.tf
variable "vpc_id" {
  description = "VPC ID"
  type        = string
}

variable "project_name" {
  description = "Project name"
  type        = string
}

variable "environment" {
  description = "Environment name"
  type        = string
}

variable "your_ip" {
  description = "Your IP address for SSH access"
  type        = string
}

