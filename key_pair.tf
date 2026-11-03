# creating ssh-key-pair for ec2 instance
resource "aws_key_pair" "terraform_aws_key" {
  key_name   = var.keypair_name
  public_key = file("${path.module}/id_ed25519.pub")
}
