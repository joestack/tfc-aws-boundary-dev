// TLS Certificates
### Root CA ###

resource "tls_private_key" "boundary" {
  count       = var.create_root_ca ? 1 : 0
  algorithm   = "RSA"
}

resource "tls_self_signed_cert" "boundary" {
  count             = var.create_root_ca ? 1 : 0
  private_key_pem   = tls_private_key.boundary[count.index].private_key_pem
  #is_ca_certificate = true

  validity_period_hours = 720
  
  allowed_uses = [
    "key_encipherment",
    "digital_signature",
    "server_auth",
  ]

  subject {
    common_name  = "${var.name}.${var.dns_domain}"
    organization = var.organization
  }

    dns_names = concat(
      [for i in range(var.controller_desired_capacity) : format("%v-srv-%02d.%v", var.name, i + 1, var.dns_domain)],
      [for i in range(var.controller_desired_capacity) : format("%v-srv-%02d", var.name, i + 1)]
    )

  ip_addresses = [
    "127.0.0.1"
  ]
}


resource "aws_acm_certificate" "cert" {
  count             = var.create_root_ca ? 1 : 0
  private_key      = tls_private_key.boundary[count.index].private_key_pem
  certificate_body = tls_self_signed_cert.boundary[count.index].cert_pem

  tags = {
   Name = "${var.name}-${random_pet.test.id}"
  }
}

# ###################
# ## Cluster Nodes ##
# ###################
# resource "tls_private_key" "server-node" {
#   count       = var.controller_desired_capacity
#   algorithm   = "ECDSA"
#   ecdsa_curve = "P384"
# }


# # locals {
# #   dns_names = [
# #     "localhost",
# #     "${var.datacenter}.${var.region}"
# #   ]
# # }


# resource "tls_cert_request" "server-node" {
#   count           = var.controller_desired_capacity
#   private_key_pem = tls_private_key.server-node[count.index].private_key_pem
#   subject {
#     #common_name  = "${var.server_name}-0${count.index +1}.${var.dns_domain}"
#     common_name  = var.common_name
#     organization = var.organization
#   }

#   dns_names = concat(local.fqdn_tls)

#   ip_addresses = [
#     "127.0.0.1"
#   ]

# }

# resource "tls_locally_signed_cert" "server-node" {
#   count              = var.controller_desired_capacity
#   cert_request_pem   = tls_cert_request.server-node[count.index].cert_request_pem
#   ca_private_key_pem = element(tls_private_key.ca.*.private_key_pem, count.index)
#   ca_cert_pem        = element(tls_self_signed_cert.ca.*.cert_pem, count.index)

#   validity_period_hours = 720
#   allowed_uses = [
#     "key_encipherment",
#     "key_agreement",
#     "digital_signature",
#     "server_auth",
#     "client_auth",
#   ]
# }
