#!/bin/bash

########################
###   COMMON BLOCK   ###
########################
common() {
sudo echo "${server_cert}" > /etc/ssl/certs/hashistack_fullchain.pem
sudo echo "${server_key}" > /etc/ssl/certs/hashistack_privkey.key
sudo echo "${server_ca}" > /etc/ssl/certs/hashistack_ca.pem
}



#########################
###  BOUNDARY BLOCK   ###
#########################
install_boundary_apt() {

apt-get -y install ${boundary_apt}=${boundary_version}
#mkdir -p /opt/boundary
echo ${boundary_lic} > /etc/boundary.d/license.hclic
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
controller {
  database {
    url = "${database_url}"
  }
  
  #FIXME Name needs to be unique
  #name = "controller"
  name = "${node_name}"

  #FIXME
  #public_cluster_address = FIXME

  license = "file:////etc/boundary.d/license.hclic"
}

disable_mlock = true


kms "awskms" {
  kms_key_id = "${key_root}"
  purpose    = "root"
}

kms "awskms" {
  kms_key_id = "${key_auth}"
  purpose    = "worker-auth"
}

listener "tcp" {
  address     = "$(private_ip):9201"
  purpose     = "cluster"
  tls_disable = true
  #tls_disable = false
  #tls_cert_file = "/etc/ssl/certs/hashistack_fullchain.pem"
  #tls_key_file = "/etc/ssl/certs/hashistack_privkey.key"

}

listener "tcp" {
  address     = "$(private_ip):9200"
  purpose     = "api"
  tls_disable = true
  #tls_disable = false
  #tls_cert_file = "/etc/ssl/certs/hashistack_fullchain.pem"
  #tls_key_file = "/etc/ssl/certs/hashistack_privkey.key"
}
EOF

}


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
[[ ${boundary_enabled} = "true" ]] && init_configuration 
[[ ${boundary_enabled} = "true" ]] && start_boundary 
