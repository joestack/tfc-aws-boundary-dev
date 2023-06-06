# // provider and provider related or globally used data sources
# provider "aws" {
#   region = var.aws_region
# }


terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 3.0"
    }
  }
}

locals {
  #image_id = data.aws_ami.boundary.id

  #private_subnets = coalescelist(var.private_subnets, module.vpc.private_subnets)

  #public_subnets = coalescelist(var.public_subnets, module.vpc.public_subnets)

  tags = merge(
    var.tags,
    {
      Owner = "terraform"
    }
  )

  vpc_id = coalesce(var.vpc_id, module.vpc.vpc_id)
}


# resource "aws_key_pair" "aws-hashistack-key" {
#   count      = var.key_name != "aws-hashistack-key" ? 0 : 1
#   key_name   = "aws-hashistack-key"
#   public_key = var.aws_hashistack_key
# }

data "aws_availability_zones" "available" {}

# data "aws_route53_zone" "selected" {
#   name         = "${var.dns_domain}."
#   private_zone = false
# }

data "aws_ami" "boundary" {
  most_recent = true
  filter {
    name = "name"
    #values = ["ubuntu/images/hvm-ssd/ubuntu-xenial-16.04-amd64-server-*"]
    values = ["ubuntu/images/hvm-ssd/ubuntu-focal-20.04-amd64-server-*"]
    #values = ["ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*"]
  }
  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
  owners = ["099720109477"] # Canonical
}

module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "~> 3.7"

  azs                = data.aws_availability_zones.available.names
  cidr               = var.cidr_block
  create_vpc         = var.vpc_id != "" ? false : true
  enable_nat_gateway = true
  enable_dns_hostnames = true
  name               = "boundary"

  private_subnets = [
    "10.0.1.0/24",
    "10.0.2.0/24",
    "10.0.3.0/24"
  ]

  public_subnets = [
    "10.0.101.0/24",
    "10.0.102.0/24",
    "10.0.103.0/24"
  ]

  tags = local.tags
}

# ### ALB

# module "alb" {
#   source  = "terraform-aws-modules/alb/aws"
#   version = "~> 6.5"

#   http_tcp_listeners = [
#     {
#       port     = 80
#       protocol = "HTTP"
#     }
#   ]

#   load_balancer_type = "application"
#   name               = "boundary"
#   security_groups    = [aws_security_group.alb.id]
#   subnets            = local.public_subnets
#   tags               = local.tags
  
#   target_groups = [
#     {
#       name             = "boundary"
#       backend_protocol = "HTTP"
#       backend_port     = 9200
#     }
#   ]

#   vpc_id = local.vpc_id
# }


# resource "aws_security_group" "bastion" {
#   count = var.key_name != "" ? 1 : 0

#   egress {
#     cidr_blocks = ["0.0.0.0/0"]
#     from_port   = 0
#     protocol    = "-1"
#     to_port     = 0
#   }

#   ingress {
#     cidr_blocks = ["0.0.0.0/0"]
#     from_port   = 22
#     protocol    = "TCP"
#     to_port     = 22
#   }

#   name   = "Boundary Bastion"
#   tags   = var.tags
#   vpc_id = local.vpc_id
# }

# resource "aws_instance" "bastion" {
#   count = var.key_name != "" ? 1 : 0

#   ami                         = var.image_id
#   associate_public_ip_address = true
#   instance_type               = "t3.micro"
#   key_name                    = var.key_name
#   subnet_id                   = local.public_subnets[0]
#   tags                        = merge(var.tags, { Name = "Boundary Bastion" })
#   vpc_security_group_ids      = [one(aws_security_group.bastion[*].id)]
# }