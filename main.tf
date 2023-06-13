terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      #version = "~> 3.0"
      #version = "~> 4.0"
      version = ">= 4.65"
    }
  }
}

locals {
  image_id = data.aws_ami.boundary.id

  #private_subnets = coalescelist(var.private_subnets, module.vpc.private_subnets)
  #private_subnets = module.vpc.private_subnets

  #public_subnets = coalescelist(var.public_subnets, module.vpc.public_subnets)
  #public_subnets = module.vpc.public_subnets

  pub_cidrs  = cidrsubnets("10.0.0.0/24", 4, 4, 4, 4)
  priv_cidrs = cidrsubnets("10.0.100.0/24", 4, 4, 4, 4)

  tags = merge(
    var.tags,
    {
      Name = "${var.name}-${random_pet.test.id}"
    }
  )

  #vpc_id = coalesce(var.vpc_id, module.vpc.vpc_id)
  vpc_id = aws_vpc.main.id
}


resource "random_pet" "test" {
  length = 1
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
  #subnet_id                   = local.public_subnets[0]
  subnet_id                   = aws_subnet.public[0].id
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

# resource "aws_security_group_rule" "ingress" {
#   from_port                = 9200
#   protocol                 = "TCP"
#   security_group_id        = aws_security_group.controller.id
#   source_security_group_id = aws_security_group.controller_lb.id
#   to_port                  = 9200
#   type                     = "ingress"
# }

resource "aws_security_group_rule" "allow_9200_controller" {
  type              = "ingress"
  from_port         = 9200
  to_port           = 9200
  protocol          = "tcp"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = aws_security_group.controller.id
}

resource "aws_security_group_rule" "allow_9201_controller" {
  type              = "ingress"
  from_port         = 9201
  to_port           = 9201
  protocol          = "tcp"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = aws_security_group.controller.id
}


resource "aws_security_group_rule" "egress" {
  cidr_blocks       = ["0.0.0.0/0"]
  from_port         = 0
  protocol          = "-1"
  security_group_id = aws_security_group.controller.id
  to_port           = 0
  type              = "egress"
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
