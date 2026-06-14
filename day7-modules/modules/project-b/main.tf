module "network" {
    source = "C:\Users\Siva Pothula\Documents\terraform\modules-imp\modules\network"
    common_tags = {
        team = dev
    }
    vpc_cidr = "10.0.1.0/16"
    subnet_cidr = "10.0.1.0/24"
}

module "rds" {
    source = "C:\Users\Siva Pothula\Documents\terraform\modules-imp\modules\rds"
    rds_name = "rds-name"
    db_idnetifier=
    db_instance_family=
}