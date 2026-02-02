variable "common_tags" {
    type = map(string)
    description = "Tags applied to all aws resources you create with this code"
}

variable "vpc_cidr" {
    type = string
    description = "CIDR block for VPC"
}

variable "subnet_cidr" {
    type = string
    description = "CIDR block for Subnet"

}