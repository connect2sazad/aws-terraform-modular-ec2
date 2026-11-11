# creating ec2 instance
locals {
  user_data_talents = [
    for talent in split("+", var.user_data_talent_string) : {
      name = split(":", trimspace(talent))[0]

      version = (
        length(split(":", trimspace(talent))) > 1
        ? split(":", trimspace(talent))[1]
        : ""
      )
    }
  ]

  user_data = join("\n", concat(
    [
      "#!/bin/bash",
      "set -euxo pipefail",

      # Create log directory
      "mkdir -p /home/ubuntu/aws-terraform-modular-ec2/logs",

      # Set directory ownership
      "chown -R ubuntu:ubuntu /home/ubuntu/aws-terraform-modular-ec2"
    ],

    flatten([
      for talent in local.user_data_talents : [
        format(
          "export talent_VERSION='%s'",
          talent.version
        ),

        replace(
          replace(
            replace(
              file("${path.module}/talents/${talent.name}.sh"),
              "\r\n",
              "\n"
            ),
            "\r",
            "\n"
          ),
          "#!/bin/bash\n",
          ""
        )
      ]
    ])
  ))
}


resource "aws_instance" "tfserver1" {
  ami                    = data.aws_ami.ubuntu.id
  instance_type          = var.machine_type
  key_name               = aws_key_pair.terraform_aws_key.key_name
  vpc_security_group_ids = ["${aws_security_group.terraform_aws_sg.id}"]

  tags = {
    Name        = var.fresh_ec2_name
    Role        = var.ec2_role
    Environment = var.ec2_env
    ManagedBy   = "terraform"
  }

  associate_public_ip_address = true

  # user_data = file("${path.module}/talents/${var.user_data_talent}.sh")
  user_data = local.user_data

  root_block_device {
    volume_size = var.volume_size
    volume_type = "gp3"
  }

}

output "instance_public_ip" {
  value = aws_instance.tfserver1[*].public_ip
}