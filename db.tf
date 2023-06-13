## POSTGRESQL

resource "random_password" "postgresql" {
  length  = 16
  special = false
}


resource "aws_db_instance" "boundary" {
  allocated_storage   = 20
  storage_type        = "gp2"
  engine              = "postgres"
  engine_version      = "14.2"
  instance_class      = "db.t3.micro"
  name                = "boundary"
  username            = "boundary"
  password                = random_password.postgresql.result
  skip_final_snapshot = true

  vpc_security_group_ids = [aws_security_group.postgresql.id]
  db_subnet_group_name   = module.vpc.private_subnets.name
  publicly_accessible    = true

  tags = local.tags
}


# module "postgresql" {
#   source  = "terraform-aws-modules/rds/aws"
#   #version = "~> 3.4"
#   version = "~> 5.9"

#   allocated_storage       = 20
#   backup_retention_period = 0
#   backup_window           = "03:00-06:00"
#   engine                  = "postgres"
#   #engine_version          = var.engine_version
#   engine_version          = "14"
#   family                  = "postgres14"
#   #family                  = "postgres12"
#   identifier              = "boundary"
#   instance_class          = "db.t3.micro"
#   maintenance_window      = "Mon:00:00-Mon:03:00"
#   major_engine_version    = "14"
#   #major_engine_version    = "12"
#   #name                    = "boundary"
#   db_name                    = "boundary"
#   password                = random_password.postgresql.result
#   port                    = 5432
#   storage_encrypted       = false
#   subnet_ids              = local.private_subnets
#   tags                    = local.tags
#   username                = "boundary"
#   vpc_security_group_ids  = [aws_security_group.postgresql.id]
#   multi_az                = true
# }

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

