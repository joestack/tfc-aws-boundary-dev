# module "vpc" {
#   source  = "terraform-aws-modules/vpc/aws"
#   #version = "~> 3.7"
#   version = "~> 4.0"

#   azs                = data.aws_availability_zones.available.names
#   cidr               = var.cidr_block
#   create_vpc         = var.vpc_id != "" ? false : true
#   enable_nat_gateway = true
#   enable_dns_hostnames = true
#   name               = "boundary"

#   private_subnets = [
#     "10.0.1.0/24",
#     "10.0.2.0/24",
#     "10.0.3.0/24"
#   ]

#   public_subnets = [
#     "10.0.101.0/24",
#     "10.0.102.0/24",
#     "10.0.103.0/24"
#   ]

#   tags = local.tags
# }






# VPC resources
resource "aws_vpc" "main" {
  cidr_block           = "10.0.0.0/16"
  instance_tenancy     = "default"
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = local.tags
}

resource "aws_internet_gateway" "this" {
  vpc_id = local.vpc_id
  tags   = local.tags
}

# Subnets
resource "aws_subnet" "public" {
  count             = var.num_subnets_public
  vpc_id            = local.vpc_id
  availability_zone = data.aws_availability_zones.available.names[count.index]
  cidr_block        = local.pub_cidrs[count.index]

  tags = {
    Name = "${var.tag}-${random_pet.test.id}-public-${count.index}"
  }
}

resource "aws_subnet" "private" {
  count             = var.num_subnets_private
  vpc_id            = local.vpc_id
  availability_zone = data.aws_availability_zones.available.names[0]
  cidr_block        = local.priv_cidrs[count.index]

  tags = {
    Name = "${var.tag}-${random_pet.test.id}-private-${count.index}"
  }
}

resource "aws_eip" "nat" {
  count = var.num_subnets_private
  vpc   = true
  tags  = local.tags
}

resource "aws_nat_gateway" "private" {
  count         = var.num_subnets_public
  subnet_id     = aws_subnet.public.*.id[count.index]
  allocation_id = aws_eip.nat.*.id[count.index]
  tags          = local.tags
}

# Public Routes
resource "aws_route_table" "public" {
  count  = var.num_subnets_public
  vpc_id = local.vpc_id
  tags = {
    Name = "${var.tag}-${random_pet.test.id}-public-${count.index}"
  }
}

resource "aws_route_table_association" "public_subnets" {
  count          = var.num_subnets_public
  subnet_id      = aws_subnet.public.*.id[count.index]
  route_table_id = aws_route_table.public.*.id[count.index]
}

resource "aws_route" "public_internet_gateway" {
  count                  = var.num_subnets_public
  route_table_id         = aws_route_table.public.*.id[count.index]
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.this.id

  timeouts {
    create = "5m"
  }
}

# Private Routes
resource "aws_route_table" "private" {
  count  = var.num_subnets_private
  vpc_id = local.vpc_id
  tags = {
    Name = "${var.tag}-${random_pet.test.id}-private-${count.index}"
  }
}

resource "aws_route_table_association" "private" {
  count          = var.num_subnets_private
  subnet_id      = aws_subnet.private.*.id[count.index]
  route_table_id = aws_route_table.private.*.id[count.index]
}

resource "aws_route" "nat_gateway" {
  count                  = var.num_subnets_private
  route_table_id         = aws_route_table.private.*.id[count.index]
  destination_cidr_block = "0.0.0.0/0"
  nat_gateway_id         = aws_nat_gateway.private.*.id[count.index]

  timeouts {
    create = "5m"
  }
}