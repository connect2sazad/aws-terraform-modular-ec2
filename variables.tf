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
  description = "List of available user data plugins."
  type        = list(string)

  validation {
  condition = (
    length(trimspace(var.user_data_plugin_string)) > 0 &&

    alltrue([
      for plugin in split("+", var.user_data_plugin_string) :
      contains(
        var.available_user_data_plugins,
        trimspace(split(":", trimspace(plugin))[0])
      ) &&
      length(split(":", trimspace(plugin))) <= 2 &&
      (
        length(split(":", trimspace(plugin))) == 1
        ? true
        : can(regex(
            "^[A-Za-z0-9._+-]+$",
            trimspace(split(":", trimspace(plugin))[1])
          ))
      )
    ]) &&

    length(distinct([
      for plugin in split("+", var.user_data_plugin_string) :
      trimspace(split(":", trimspace(plugin))[0])
    ])) == length(split("+", var.user_data_plugin_string))
  )

  error_message = "Invalid, duplicate, or empty plugin selection. Check plugin names and version syntax."
}
}

