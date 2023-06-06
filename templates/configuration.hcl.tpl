controller {
  database {
    url = "${database_url}"
  }

  name = "controller"
}

disable_mlock = true

%{ for key in keys ~}
kms "awskms" {
  kms_key_id = "${key["key_id"]}"
  purpose    = "${key["purpose"]}"
}

%{ endfor ~}

listener "tcp" {
  address     = "$(private_ip):9201"
  purpose     = "cluster"
  tls_disable = true
}

listener "tcp" {
  address     = "$(private_ip):9200"
  purpose     = "api"
  tls_disable = true
}
