#!/bin/bash

########################
###   COMMON BLOCK   ###
########################
common() {
  mkdir -p /etc/boundary.d/tls
  echo "${server_cert}" > /etc/boundary.d/tls/boundary-cert.pem
  echo "${server_key}" > /etc/boundary.d/tls/boundary-key.pem
  echo "${server_ca}" > /etc/boundary.d/tls/boundary-ca.pem
}



#########################
###  BOUNDARY BLOCK   ###
#########################
install_boundary_apt() {

apt-get -y install ${boundary_apt}=${boundary_version}
#mkdir -p /opt/boundary
#echo ${boundary_lic} > /etc/boundary.d/license.hclic
#chown -R boundary:boundary /opt/boundary/


tee /etc/systemd/system/boundary.service > /dev/null <<EOF
[Unit]
Description=Access any system from anywhere based on user identity
Documentation=https://www.boundaryproject.io/docs

[Service]
ExecStart=/usr/bin/boundary server -config /etc/boundary.d/configuration.hcl
LimitMEMLOCK=infinity
Capabilities=CAP_IPC_LOCK+ep
CapabilityBoundingSet=CAP_SYSLOG CAP_IPC_LOCK

[Install]
WantedBy=multi-user.target
EOF

## FIXME tbc
}


create_configuration() {
  tee /etc/boundary.d/configuration.hcl > /dev/null <<EOF


listener "tcp" {
  address = "$(private_ip):9202"
	purpose = "proxy"
  tls_disable   = false
  tls_cert_file = "/etc/boundary.d/tls/boundary-cert.pem"
  tls_key_file = "/etc/boundary.d/tls/boundary-key.pem"

	#proxy_protocol_behavior = "allow_authorized"
	#proxy_protocol_authorized_addrs = "127.0.0.1"
}

worker {
  # Name attr must be unique
	public_addr = "$(public_ip)"
	name = "${node_name}"
	description = "A default worker created for demonstration"
	controllers = [${controller_ips}]
}

kms "awskms" {
	purpose    = "worker-auth"
	key_id     = "global_root"
  kms_key_id = "${key_auth}"
}

EOF
}








# create_configuration() {
#     tee /etc/boundary.d/configuration.hcl > /dev/null <<EOF
# controller {
#   database {
#     url = "${database_url}"
#   }
  

#   name = "${node_name}"

#   #FIXME
#   public_cluster_address = "${cluster_address}"

#   license = "file:////etc/boundary.d/license.hclic"
# }

# disable_mlock = true


# kms "awskms" {
#   kms_key_id = "${key_root}"
#   purpose    = "root"
# }

# kms "awskms" {
#   kms_key_id = "${key_auth}"
#   purpose    = "worker-auth"
# }

# listener "tcp" {
#   address     = "$(private_ip):9201"
#   purpose     = "cluster"
#   #tls_disable = true
#   tls_disable = false
#   tls_cert_file = "/etc/boundary.d/tls/boundary-cert.pem"
#   tls_key_file = "/etc/boundary.d/tls/boundary-key.pem"

# }

# listener "tcp" {
#   address     = "$(private_ip):9200"
#   purpose     = "api"
#   #tls_disable = true
#   tls_disable = false
#   tls_cert_file = "/etc/boundary.d/tls/boundary-cert.pem"
#   tls_key_file = "/etc/boundary.d/tls/boundary-key.pem"
# }
# EOF

# }


init_configuration() {
    boundary database init -config /etc/boundary.d/configuration.hcl -log-format json
}

start_boundary() {
    systemctl enable boundary
    systemctl start boundary
}

####################
#####   MAIN   #####
####################

common
[[ ${boundary_enabled} = "true" ]] && install_boundary_apt 
[[ ${boundary_enabled} = "true" ]] && create_configuration 
#[[ ${boundary_enabled} = "true" ]] && init_configuration 
[[ ${boundary_enabled} = "true" ]] && start_boundary 
