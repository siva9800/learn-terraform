aws_region         = "us-east-1"
project_name       = "myapp"
environment        = "dev"
vpc_cidr           = "10.0.0.0/16"
availability_zones = ["us-east-1a", "us-east-1b"]

your_ip = "49.37.157.40/32" # Example: "203.0.113.25/32"

key_name = ""

# EC2 Configuration - FREE TIER
ami_id                 = "ami-0532be01f26a3de55"
frontend_instance_type = "t3.micro" # Free tier eligible
backend_instance_type  = "t3.micro" # Free tier eligible

# RDS Configuration - FREE TIER
db_name              = "appdb"
db_username          = "admin"
db_password          = "YourSecurePassword123!"
db_instance_class    = "db.t4g.micro"
db_allocated_storage = 20
db_engine            = "mysql"
db_engine_version    = "8.0.43"
db_multi_az          = false # Free tier doesn't support Multi-AZ