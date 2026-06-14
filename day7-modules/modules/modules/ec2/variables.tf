variable "ami_id"{
    type = string
    description = "AMI ID for EC2"
}

variable "instance_type"{
    type = string
    description = "instance type"
    default = "t3.medium"
}
