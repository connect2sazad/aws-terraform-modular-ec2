# creating security group for ec2 instance
resource "aws_security_group" "terraform_aws_sg" {
  name        = var.sg_name
  description = "Allow TLS inbound traffic and all outbound traffic"

  tags = {
    Name = var.sg_name
  }
}

# creating security group ingress rules for ec2 instance
resource "aws_vpc_security_group_ingress_rule" "allow_ingress" {

  for_each = var.ingress_ports

  security_group_id = aws_security_group.terraform_aws_sg.id
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "tcp"

  from_port = each.value
  to_port   = each.value
}

# SSH access only from the Ansible control node
resource "aws_vpc_security_group_ingress_rule" "allow_ssh_from_ansible" {
  security_group_id = aws_security_group.terraform_aws_sg.id
  description       = "Allow SSH from the Ansible control node"

  cidr_ipv4   = var.ssh_allowed_cidr
  ip_protocol = "tcp"
  from_port   = 22
  to_port     = 22
}

# creating security group egress rules for ec2 instance
resource "aws_vpc_security_group_egress_rule" "allow_egress" {


  security_group_id = aws_security_group.terraform_aws_sg.id
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "-1" # semantically equivalent to all ports
}