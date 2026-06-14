# main.tf
terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
  required_version = ">= 1.0"
}

provider "aws" {
  region = var.aws_region
}

# VPC Module
module "vpc" {
  source = "./modules/vpc"

  vpc_cidr           = var.vpc_cidr
  availability_zones = var.availability_zones
  project_name       = var.project_name
  environment        = var.environment
}

# Security Groups Module
module "security_groups" {
  source = "./modules/security_groups"

  vpc_id       = module.vpc.vpc_id
  project_name = var.project_name
  environment  = var.environment
  your_ip      = var.your_ip
}

# EC2 Module for Frontend
module "frontend" {
  source = "./modules/ec2"

  instance_name     = "${var.project_name}-${var.environment}-frontend"
  instance_type     = var.frontend_instance_type
  ami_id            = var.ami_id
  subnet_id         = module.vpc.public_subnet_ids[0]
  security_group_id = module.security_groups.frontend_sg_id
  key_name          = var.key_name
  user_data         = file("${path.module}/scripts/frontend_userdata.sh")
}

# EC2 Module for Backend
module "backend" {
  source = "./modules/ec2"

  instance_name     = "${var.project_name}-${var.environment}-backend"
  instance_type     = var.backend_instance_type
  ami_id            = var.ami_id
  subnet_id         = module.vpc.private_subnet_ids[0]
  security_group_id = module.security_groups.backend_sg_id
  key_name          = var.key_name
  user_data         = file("./scripts/backend_userdata.sh")
}

# RDS Module
module "rds" {
  source = "./modules/rds"

  db_name             = var.db_name
  db_username         = var.db_username
  db_password         = var.db_password
  instance_class      = var.db_instance_class
  allocated_storage   = var.db_allocated_storage
  engine              = var.db_engine
  engine_version      = var.db_engine_version
  subnet_ids          = module.vpc.private_subnet_ids
  security_group_id   = module.security_groups.database_sg_id
  project_name        = var.project_name
  environment         = var.environment
  multi_az            = var.db_multi_az
  skip_final_snapshot = true
}