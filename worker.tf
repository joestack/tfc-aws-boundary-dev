data "template_file" "worker" {
 
  count = var.controller_desired_capacity
  template = (join("\n", tolist([
    file("${path.root}/templates/base.sh"),
    file("${path.root}/templates/worker.sh")
  ])))
  vars = {
    worker_count      = var.worker_desired_capacity
    node_name         = format("${var.name}-wrkr-%02d", count.index + 1)
    #controller_ips    = aws_instance.server.*.private_ip
    controller_ips    = local.controller_ips
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
    cluster_address   = aws_route53_record.boundary_lb.fqdn
    database_url      = local.database_url
    key_root          = local.key_root
    key_auth          = local.key_auth
    #fqdn_tls          = local.fqdn_tls
  }

}


data "template_cloudinit_config" "worker" {
  count         = var.worker_desired_capacity
  gzip          = true
  base64_encode = true
  part {
    content_type = "text/x-shellscript"
    content      = element(data.template_file.worker.*.rendered, count.index)
  }
}



## CONTROL NODES

resource "aws_instance" "worker" {
  count                       = var.worker_desired_capacity
  ami                         = data.aws_ami.boundary.id
  instance_type               = var.controller_instance_type
#  subnet_id                   = module.vpc.private_subnets[count.index]
  subnet_id                   = element(aws_subnet.private.*.id, count.index)
  associate_public_ip_address = "false"
  vpc_security_group_ids      = [aws_security_group.worker.id]
  key_name                    = var.key_name
  iam_instance_profile        = aws_iam_instance_profile.boundary.name

  tags = {
    #Name      = format("${var.server_name}-%02d", count.index + 1)
    Name      = format("${var.name}-wrkr-%02d", count.index + 1)
    auto_join = var.auto_join_value
  }

  root_block_device {
    volume_type           = "gp2"
    volume_size           = var.root_block_device_size
    delete_on_termination = "true"
  }

  user_data = element(data.template_cloudinit_config.worker.*.rendered, count.index)
}



resource "aws_route53_record" "worker" {
  count   = var.worker_desired_capacity
  zone_id = data.aws_route53_zone.selected.zone_id
  name    = lookup(aws_instance.worker.*.tags[count.index], "Name")
  type    = "A"
  ttl     = "300"
  records = [element(aws_instance.worker.*.private_ip, count.index)]
}



# data "template_file" "client" {
#   count = var.client_count
#   template = (join("\n", tolist([
#     file("${path.root}/templates/base.sh"),
#     file("${path.root}/templates/docker.sh"),
#     file("${path.root}/templates/client.sh")
#   ])))
#   vars = {
#     client_count    = var.client_count
#     datacenter      = var.datacenter
#     region          = var.region
#     client          = var.client
#     auto_join_value = var.auto_join_value
#     node_name       = format("${var.name}-worker-%02d", count.index + 1)
# #    node_name       = format("${var.client_name}-%02d", count.index + 1)
#     nomad_enabled   = var.nomad_enabled
#     nomad_version   = var.nomad_version
#     nomad_apt       = local.nomad_apt
#     consul_enabled  = var.consul_enabled
#     consul_version  = var.consul_version
#     consul_apt      = local.consul_apt
#     consul_lic      = var.consul_lic
#     consul_enabled  = var.consul_enabled
#     nomad_enabled   = var.nomad_enabled
#   }
# }

# data "template_cloudinit_config" "client" {
#   count         = var.client_count
#   gzip          = true
#   base64_encode = true
#   part {
#     content_type = "text/x-shellscript"
#     content      = element(data.template_file.client.*.rendered, count.index)
#   }
# }

# resource "aws_instance" "client" {
#   count                       = var.nomad_enabled != "true" ? 0 : 1 * var.client_count
#   ami                         = data.aws_ami.ubuntu.id
#   instance_type               = var.instance_type
#   subnet_id                   = element(aws_subnet.hcstack_subnet.*.id, count.index)
#   associate_public_ip_address = "true"
#   vpc_security_group_ids      = [aws_security_group.primary.id]
#   key_name                    = var.key_name
#   iam_instance_profile        = aws_iam_instance_profile.hc-stack-client.name

#   tags = {
#     #Name      = format("${var.client_name}-%02d", count.index + 1)
#     Name      = format("${var.name}-worker-%02d", count.index + 1)
#     auto_join = var.auto_join_value
#   }

#   root_block_device {
#     volume_type           = "gp2"
#     volume_size           = var.root_block_device_size
#     delete_on_termination = "true"
#   }

#   # ebs_block_device  {
#   #   device_name           = "/dev/xvdd"
#   #   volume_type           = "gp2"
#   #   volume_size           = var.ebs_block_device_size
#   #   delete_on_termination = "true"
#   # }

#   user_data = element(data.template_cloudinit_config.client.*.rendered, count.index)
# }