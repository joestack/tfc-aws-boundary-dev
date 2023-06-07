terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 3.0"
    }
  }
}

locals {
  image_id = data.aws_ami.boundary.id

  #private_subnets = coalescelist(var.private_subnets, module.vpc.private_subnets)
  private_subnets = module.vpc.private_subnets

  #public_subnets = coalescelist(var.public_subnets, module.vpc.public_subnets)
  public_subnets = module.vpc.public_subnets

  tags = merge(
    var.tags,
    {
      Owner = "terraform"
    }
  )

  vpc_id = coalesce(var.vpc_id, module.vpc.vpc_id)
}

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


## BASTION

resource "aws_security_group" "bastion" {
  count = var.key_name != "" ? 1 : 0

  egress {
    cidr_blocks = ["0.0.0.0/0"]
    from_port   = 0
    protocol    = "-1"
    to_port     = 0
  }

  ingress {
    cidr_blocks = ["0.0.0.0/0"]
    from_port   = 22
    protocol    = "TCP"
    to_port     = 22
  }

  name   = "Boundary Bastion"
  tags   = var.tags
  vpc_id = local.vpc_id
}

resource "aws_instance" "bastion" {
  count = var.key_name != "" ? 1 : 0

  ami                         = local.image_id
  associate_public_ip_address = true
  instance_type               = "t3.micro"
  key_name                    = var.key_name
  subnet_id                   = local.public_subnets[0]
  tags                        = merge(var.tags, { Name = "Boundary Bastion" })
  vpc_security_group_ids      = [one(aws_security_group.bastion[*].id)]
}




resource "aws_security_group" "controller" {
  name   = "Boundary controller"
  tags   = local.tags
  vpc_id = local.vpc_id
}

resource "aws_security_group_rule" "ssh" {
  count = var.key_name != "" ? 1 : 0

  from_port                = 22
  protocol                 = "TCP"
  security_group_id        = aws_security_group.controller.id
  source_security_group_id = one(aws_security_group.bastion[*].id)
  to_port                  = 22
  type                     = "ingress"
}

resource "aws_security_group_rule" "ingress" {
  from_port                = 9200
  protocol                 = "TCP"
  security_group_id        = aws_security_group.controller.id
  source_security_group_id = aws_security_group.alb.id
  to_port                  = 9200
  type                     = "ingress"
}

resource "aws_security_group_rule" "egress" {
  cidr_blocks       = ["0.0.0.0/0"]
  from_port         = 0
  protocol          = "-1"
  security_group_id = aws_security_group.controller.id
  to_port           = 0
  type              = "egress"
}

resource "aws_security_group" "postgresql" {
  ingress {
    from_port       = 5432
    protocol        = "TCP"
    security_groups = [aws_security_group.controller.id]
    to_port         = 5432
  }

  tags   = local.tags
  vpc_id = local.vpc_id
}

## POSTGRESQL

resource "random_password" "postgresql" {
  length  = 16
  special = false
}

module "postgresql" {
  source  = "terraform-aws-modules/rds/aws"
  version = "~> 3.4"

  allocated_storage       = 5
  backup_retention_period = 0
  backup_window           = "03:00-06:00"
  engine                  = "postgres"
  engine_version          = var.engine_version
  family                  = "postgres12"
  identifier              = "boundary"
  instance_class          = "db.t2.micro"
  maintenance_window      = "Mon:00:00-Mon:03:00"
  major_engine_version    = "12"
  name                    = "boundary"
  password                = random_password.postgresql.result
  port                    = 5432
  storage_encrypted       = false
  subnet_ids              = local.private_subnets
  tags                    = local.tags
  username                = "boundary"
  vpc_security_group_ids  = [aws_security_group.postgresql.id]
}


### POLICY KMS

data "aws_iam_policy_document" "controller" {
  statement {
    actions = [
      "kms:Decrypt",
      "kms:DescribeKey",
      "kms:Encrypt"
    ]

    effect = "Allow"

    resources = [aws_kms_key.auth.arn, aws_kms_key.root.arn]
  }

  # statement {
  #   actions = [
  #     "s3:*"
  #   ]

  #   effect = "Allow"

  #   resources = [
  #     "${data.aws_s3_bucket.boundary.arn}/",
  #     "${data.aws_s3_bucket.boundary.arn}/*"
  #   ]
  # }
}

data "aws_iam_policy_document" "assume_role_policy" {
  statement {
    actions = ["sts:AssumeRole"]

    effect = "Allow"

    principals {
      identifiers = ["ec2.amazonaws.com"]
      type        = "Service"
    }
  }
}

resource "aws_iam_policy" "controller" {
  name   = "BoundaryControllerServiceRolePolicy"
  policy = data.aws_iam_policy_document.controller.json
}

resource "aws_iam_role" "controller" {
  assume_role_policy = data.aws_iam_policy_document.assume_role_policy.json
  name               = "ServiceRoleForBoundaryController"
  tags               = var.tags
}

resource "aws_iam_role_policy_attachment" "controller" {
  policy_arn = aws_iam_policy.controller.arn
  role       = aws_iam_role.controller.name
}

resource "aws_iam_instance_profile" "controller" {
  role = aws_iam_role.controller.name
}

# The root key used by controllers
resource "aws_kms_key" "root" {
  deletion_window_in_days = 7
  key_usage               = "ENCRYPT_DECRYPT"
  tags                    = merge(local.tags, { Purpose = "root" })
}

# The worker-auth AWS KMS key used by controllers and workers
resource "aws_kms_key" "auth" {
  deletion_window_in_days = 7
  key_usage               = "ENCRYPT_DECRYPT"
  tags                    = merge(local.tags, { Purpose = "worker-auth" })
}
