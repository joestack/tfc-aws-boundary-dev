# locals are used to add a little more magic, dynamic, or circumstances to the vars 
# used by the template data source to render the user_data scripts 
locals {
  boundary_apt      = length(split("+", var.boundary_version)) == 2 ? "boundary-enterprise" : "boundary"
  ca_cert           = var.create_root_ca ? tls_private_key.boundary.0.public_key_pem : "NULL"
  fqdn_tls          = [for i in range(var.controller_desired_capacity) : format("%v-srv-%02d.%v", var.name, i + 1, var.dns_domain)]
  server_ca         = var.create_root_ca ? tls_self_signed_cert.boundary.0.cert_pem : "NULL"
  database_url      = format(
        "postgresql://%s:%s@%s/%s",
        module.postgresql.db_instance_username,
        module.postgresql.db_instance_password,
        module.postgresql.db_instance_endpoint,
        module.postgresql.db_instance_name
      )
  key_root          = aws_kms_key.root.key_id
  key_auth          = aws_kms_key.auth.key_id
  # configuration     = base64encode(templatefile(
  #   "${path.module}/templates/configuration.hcl.tpl",
  #   {
  #     # Database URL for PostgreSQL
  #     database_url = format(
  #       "postgresql://%s:%s@%s/%s",
  #       module.postgresql.db_instance_username,
  #       module.postgresql.db_instance_password,
  #       module.postgresql.db_instance_endpoint,
  #       module.postgresql.db_instance_name
  #     )

  #     keys = [
  #       {
  #         key_id  = aws_kms_key.root.key_id
  #         purpose = "root"
  #       },
  #       {
  #         key_id  = aws_kms_key.auth.key_id
  #         purpose = "worker-auth"
  #       }
  #     ]
  #   }
  # )
  # )
}

data "template_file" "server" {
  count = var.controller_desired_capacity
  template = (join("\n", tolist([
    file("${path.root}/templates/base.sh"),
    file("${path.root}/templates/server.sh")
  ])))
  vars = {
    server_count      = var.controller_desired_capacity
    #aws_region        = coalesce(var.aws_region, var.AWS_DEFAULT_REGION)
    #datacenter        = var.datacenter
    #region            = var.region
    #auto_join_value   = var.auto_join_value
    node_name         = format("${var.name}-srv-%02d", count.index + 1)
#    node_name         = format("${var.server_name}-%02d", count.index + 1)
    ca_cert           = local.ca_cert
    server_cert       = tls_self_signed_cert.boundary[0].cert_pem
    server_key        = tls_private_key.boundary[0].private_key_pem
    server_ca         = local.server_ca
    dns_domain        = var.dns_domain
    #kms_key_id        = local.kms_key_id
    boundary_enabled  = var.boundary_enabled
    boundary_version  = var.boundary_version
    boundary_apt      = local.boundary_apt
    boundary_lic      = var.boundary_lic
    #configuration     = local.configuration
    database_url      = local.database_url
    key_root          = local.key_root
    key_auth          = local.key_auth
  }

}

data "template_cloudinit_config" "server" {
  count         = var.controller_desired_capacity
  gzip          = true
  base64_encode = true
  part {
    content_type = "text/x-shellscript"
    content      = element(data.template_file.server.*.rendered, count.index)
  }
}



## CONTROL NODES

resource "aws_instance" "server" {
  count                       = var.controller_desired_capacity
  ami                         = data.aws_ami.boundary.id
  instance_type               = var.controller_instance_type
  subnet_id                   = module.vpc.private_subnets[count.index]
  associate_public_ip_address = "false"
  vpc_security_group_ids      = [aws_security_group.controller.id]
  key_name                    = var.key_name
  iam_instance_profile        = aws_iam_instance_profile.controller.name 

  tags = {
    #Name      = format("${var.server_name}-%02d", count.index + 1)
    Name      = format("${var.name}-srv-%02d", count.index + 1)
    auto_join = var.auto_join_value
  }

  root_block_device {
    volume_type           = "gp2"
    volume_size           = var.root_block_device_size
    delete_on_termination = "true"
  }

  user_data = element(data.template_cloudinit_config.server.*.rendered, count.index)
}



# resource "aws_route53_record" "server" {
#   count   = var.controller_desired_capacity
#   zone_id = data.aws_route53_zone.selected.zone_id
#   name    = lookup(aws_instance.server.*.tags[count.index], "Name")
#   type    = "A"
#   ttl     = "300"
#   records = [element(aws_instance.server.*.public_ip, count.index)]
# }