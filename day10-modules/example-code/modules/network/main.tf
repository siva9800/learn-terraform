resource "aws_vpc" "myapp_vpc" {
    cidr_block = var.vpc_cidr
    tags = var.common_tags
}


resource "aws_subnet" "public_subnet"{
    vpc_id = aws_vpc.myapp_vpc.id
    cidr_block = var.subnet_cidr
    tags = var.common_tags
}

resource "igw

resource "nat
























