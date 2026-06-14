resource "aws_instance" "web_ec2" {
     ami = var.ami_id
     instance_type = var.instance_type
     subnet_id = aws_subnet.public_subnet.id
     tags = var.common_tags
}






















