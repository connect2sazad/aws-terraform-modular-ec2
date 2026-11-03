variable "region" {
  type = string
}

variable "sg_name" {
  type = string
}

variable "keypair_name" {
  type = string
}

variable "fresh_ec2_name" {
  type = string
}

variable "ingress_ports" {
  type = map(number)
}

variable "image_name" {
  type = string
}

variable "machine_type" {
  type = string
}

variable "ec2_role" {
  type = string
}

variable "ec2_env" {
  type = string
}

variable "ssh_allowed_cidr" {
  description = "Public IP or CIDR allowed to SSH into the instance"
  type        = string
}

variable "volume_size" {
  type = number
}

variable "user_data_plugin" {
  type = string
}