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

variable "available_user_data_talents" {
  description = "List of available user data talents."
  type        = list(string)

  validation {
    condition     = length(var.available_user_data_talents) > 0
    error_message = "The User Data talent list cannot be empty."
  }
}

variable "user_data_talent_string" {
  description = "talents to install, separated by +. Optional versions use talent:version."
  type        = string

  validation {
    condition = (
      length(trimspace(var.user_data_talent_string)) > 0 &&

      alltrue([
        for talent in split("+", var.user_data_talent_string) :
        contains(
          var.available_user_data_talents,
          trimspace(split(":", trimspace(talent))[0])
        ) &&
        length(split(":", trimspace(talent))) <= 2 &&
        (
          length(split(":", trimspace(talent))) == 1
          ? true
          : can(regex(
            "^[A-Za-z0-9._+-]+$",
            trimspace(split(":", trimspace(talent))[1])
          ))
        )
      ]) &&

      length(distinct([
        for talent in split("+", var.user_data_talent_string) :
        trimspace(split(":", trimspace(talent))[0])
      ])) == length(split("+", var.user_data_talent_string))
    )

    error_message = "Invalid, duplicate, or empty talent selection. Check talent names and version syntax."
  }
}