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
ExecStart=/usr/local/bin/boundary server -config /etc/boundary/configuration.hcl
LimitMEMLOCK=infinity
Capabilities=CAP_IPC_LOCK+ep
CapabilityBoundingSet=CAP_SYSLOG CAP_IPC_LOCK

[Install]
WantedBy=multi-user.target
EOF



systemctl enable boundary
systemctl start boundary

## FIXME tbc
}


####################
#####   MAIN   #####
####################

common
[[ ${boundary_enabled} = "true" ]] && install_boundary_apt 
