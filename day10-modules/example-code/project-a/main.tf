module "network" {
    source = "C:\Users\Siva Pothula\Documents\terraform\modules-imp\modules\network"
    common_tags = {
        team = dev
    }
    vpc_cidr = var.vpc_cidr
    subnet_cidr = var.subnet_cidr
}

module "ec2" {
    source = "C:\Users\Siva Pothula\Documents\terraform\modules-imp\modules\ec2"
    ami_id = var.ami_id
    instance_type = var.instance_type
}

