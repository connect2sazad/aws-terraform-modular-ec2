# creating ec2 instance
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

  user_data = file("${path.module}/ud-plugins/${var.user_data_plugin}.sh")

  root_block_device {
    volume_size = var.volume_size
    volume_type = "gp3"
  }

}

output "instance_public_ip" {
  value = aws_instance.tfserver1[*].public_ip
}