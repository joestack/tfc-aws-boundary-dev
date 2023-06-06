output "dns_name" {
  description = "The public DNS name of the controller load balancer"
  value       = module.alb.lb_dns_name
}

# output "s3command" {
#   description = "The S3 cp command used to display the contents of the cloud-init-output.log"

output "bastion_ip" {
  value = aws_instance.bastion[0].public_ip
}

## TEST
output "controller_ips" {
  value = aws_instance.server[*].public_ip
}

# output "dns_name_set" {
#   value = aws_route53_record.alb.fqdn
# }



# output "cluster_private_ips" {
#   value = aws_instance.server.*.private_ip
# }

# output "cluster_public_ips" {
#   value = aws_instance.server[*].public_ip
# }

# output "nomad_client_private_ips" {
#   value = aws_instance.client.*.private_ip
# }

# output "nomad_client_public_ips" {
#   value = aws_instance.client[*].public_ip
# }

# output "tfe_pub_ip" {
#   value = aws_instance.tfe[*].public_ip
# }

# output "tfe_prv_ip" {
#   value = aws_instance.tfe[*].private_ip
# }

# output "cluster_server_count" {
#   value = local.server_count
# }

# output "tfe_enc_password" {
#   value = var.terraform_enabled ? local.tfe_enc_password : ""
# }

# output "tfe_auth_passord" {
#   value = var.terraform_enabled ? local.tfe_auth_password : ""
# }

# output "consul_init_token" {
#   value = var.consul_enabled ? local.consul_init_token : ""
# }

# output "cluster_fqdn" {
#   value = aws_route53_record.server.*.fqdn
# }