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

variable "available_user_data_plugins" {
  description = "List of Available User Data Plugins."

  type = list(string)

  validation {
    condition     = length(var.available_user_data_plugins) > 0
    error_message = "The User Data plugin list cannot be empty."
  }
}

variable "user_data_plugin" {
  description = "Select the User Data installation script."

  type = string

  validation {
    condition = contains(
      var.available_user_data_plugins,
      var.user_data_plugin
    )

    error_message = <<-EOT
      INVALID USER DATA PLUGIN!

      AVAILABLE PLUGINS:
      ------------------
      ${join("\n      ", var.available_user_data_plugins)}

      ------------------
      Please select one of the available plugins.
    EOT
  }
}