//GLOBAL CLUSTER SETTINGS

variable "aws_region" {
  description = "The AWS region to be used"
}

variable "name" {
  description = "Unique Name of the Environment also be used as Tag"
}

variable "vpc_id" {
  description = "The ID of the VPC"
  default     = ""
  type        = string
}

variable "cidr_block" {
  description = "The default CIDR to use"
  default     = "10.0.0.0/16"
}

variable "key_name" {
  description = "SSH key name to be used to access any instances. Use the one that already exist in your AWS region or keep the default and assign the pub key to aws_hashistack_key variable"
  default     = "joestack"
}

variable "engine_version" {
  default     = "12.10"
  description = "The engine_version of the postgres db, within the postgres12 family"
  type        = string
}

variable "controller_desired_capacity" {
  default = "3"
}

variable "controller_instance_type" {
  default     = "t3.small"
  description = "Specifies the instance type of the controller EC2 instance"
  type        = string
}

# variable "private_subnets" {
#   description = "List of private subnet ids"
#   default = []
#   type        = list(string)
# }

# variable "public_subnets" {
#   description = "List of public subnet ids"
#   default = []
#   type        = list(string)
# }

variable "tags" {
  default = {}

  description = <<EOF
One or more tags. You can tag your Auto Scaling group and propagate the tags to
the Amazon EC2 instances it launches.
EOF

  type = map(string)
}

# variable "server_count" {
#   description = "Amount of cluster instances (odd number 1,3, max 5)"
#   default     = "3"
# }

# variable "instance_type" {
#   description = "Type of EC2 cluster instance"
#   default     = "t2.small"
# }

# # variable "server_name" {
# #   default = "hc-stack-srv"
# # }

variable "root_block_device_size" {
  default = "80"
}

variable "auto_join_value" {
  description = "Server rejoin tag_value to identify cluster instances"
  default     = "joestack_hashistack_autojoin"
}

# variable "dns_domain" {
#   description = "The Route53 Zone to assign DNS records to"
# }



# variable "aws_hashistack_key" {
#   description = "The public part of the SSH key to access any instance"
#   default     = "NULL"
# }

# variable "whitelist_ip" {
#   description = "The allowed ingress IP CIDR assigned to the ASGs"
#   default     = "0.0.0.0/0"
# }



# // GLOBAL CERT SETTINGS

# variable "create_root_ca" {
#   description = "Create a self-signed root ca based on hashicorp/terraform-provider-tls"
#   default     = "true"
# }

# variable "common_name" {
#   description = "Cert common name"
#   default     = "hashistack"
# }

# variable "organization" {
#   description = "Cert Organaization"
#   default     = "joestack"
# }

# //BOUNDARY SETTINGS

# variable "boundary_enabled" {
#   default = "false"
# }

# variable "boundary_version" {
#   default = "0.12.2-1"
# }

# variable "boundary_lic" {
#   default = "NULL"
# }