region     = "ap-south-1"
image_name = "ubuntu/images/hvm-ssd-gp3/ubuntu-resolute-26.04-amd64-server-*"
ingress_ports = {
  http   = 80
  https  = 443
  server = 555
}
sg_name          = "fresh-ec2-sg1"
keypair_name     = "fresh-ec2-kp1"
fresh_ec2_name   = "Fresh-EC2-Instance-with-Docker-Setup1"
ec2_role         = "web"
ec2_env          = "dev"
ssh_allowed_cidr = "0.0.0.0/0"

# machine_type = "t3.micro" # docker
# volume_size = 10 # docker
machine_type = "t3.medium" # kubernetes
volume_size  = 30          # kubernetes

available_user_data_talents = [
  "ansible", "argocd", "awscli",
  "docker",
  "go",
  "helm",
  "java", "jenkins",
  "kind_k8s", "kubectl",
  "terraform"
]
# user_data_talent        = "kind+kubectl" # select the talent from available_user_data_talents 
user_data_talent_string = "docker+go"