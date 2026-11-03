# AWS Terraform Modular EC2 Infrastructure

Automate the provisioning and initial configuration of AWS EC2 instances with Terraform and reusable, variable-driven User Data scripts.

This project uses one reusable Terraform configuration to provision EC2 infrastructure and install different tools by changing the `user_data_plugin` variable. Instead of maintaining separate Terraform configurations for each environment, select an installation script and customize the instance through Terraform variables.

**Portfolio:** <https://connect2sazad.github.io/>  
**GitLab:** <https://gitlab.com/connect2sazad/aws-terraform-modular-ec2>  
**GitHub:** <https://github.com/connect2sazad/aws-terraform-modular-ec2>

---

## Table of Contents

- [Features](#features)
- [Available User Data Plugins](#available-user-data-plugins)
- [Project Structure](#project-structure)
- [Prerequisites](#prerequisites)
- [Getting Started](#getting-started)
  - [1. Clone the Repository](#1-clone-the-repository)
  - [2. Generate an SSH Key Pair](#2-generate-an-ssh-key-pair)
  - [3. Configure SSH Key Files](#3-configure-ssh-key-files)
  - [4. Install AWS CLI](#4-install-aws-cli)
  - [5. Configure AWS Access](#5-configure-aws-access)
  - [6. Configure AWS CLI](#6-configure-aws-cli)
  - [7. Install Terraform](#7-install-terraform)
  - [8. Initialize Terraform](#8-initialize-terraform)
  - [9. Select a User Data Plugin](#9-select-a-user-data-plugin)
  - [10. Start EC2 Using Automation Scripts](#10-start-ec2-using-automation-scripts)
  - [11. Validate the Configuration](#11-validate-the-configuration)
  - [12. Create a Terraform Plan](#12-create-a-terraform-plan)
  - [13. Create the EC2 Instance](#13-create-the-ec2-instance)
  - [14. Connect to the EC2 Instance](#14-connect-to-the-ec2-instance)
  - [15. Verify the Installation](#15-verify-the-installation)
  - [16. Destroy the Infrastructure](#16-destroy-the-infrastructure)
- [Important Note About User Data Changes](#important-note-about-user-data-changes)
- [Troubleshooting](#troubleshooting)
- [Best Practices](#best-practices)
- [Future Improvements](#future-improvements)
- [Useful Resources](#useful-resources)
- [Author](#author)

## Features

- Modular Terraform infrastructure.
- Variable-driven User Data script selection.
- Reusable EC2 instance configuration.
- Automated software installation during EC2 initialization.
- Configurable EC2 instance types.
- Configurable EBS volume sizes.
- Customizable EC2 instance names, roles, and environments.
- AWS security group and SSH key pair integration.
- Easy addition of new installation scripts.
- Automated EC2 provisioning using Windows batch scripts.
- Linux/macOS support through Bash automation scripts.

## Available User Data Plugins

The `ud-plugins/` directory contains shell scripts used to install and configure tools on the EC2 instance.

| Plugin | Description |
|---|---|
| `docker` | Installs and configures Docker. |
| `kind+kubectl` | Installs Kind and kubectl for Kubernetes environments. |

Additional installation scripts can be added to this directory. Once you add the installation script, make sure you register the script file name without ".sh" to `available_user_data_plugins` variable in `terraform.tfvars`

> **Important:** The plugin selection controls the User Data script used during EC2 provisioning. It is not a runtime plugin manager. Changing the selected plugin may cause Terraform to replace the existing EC2 instance, depending on the resource configuration.

## Project Structure

```text
aws-terraform-modular-ec2/
│
├── ud-plugins/
│   ├── docker.sh
│   └── kind+kubectl.sh
│
├── .gitignore
├── data-source.tf
├── ec2.tf
├── key-pair.tf
├── LICENSE
├── main.tf
├── outputs.tf
├── provider.tf
├── security_groups.tf
|
├── launch_ec2.bat
├── destroy_ec2.bat
├── launch_ec2.sh
├── destroy_ec2.sh
|
├── terraform.tf
├── terraform.tfvars
├── variables.tf
└── README.md
```

> The exact Terraform filenames may vary as the project evolves.

## Prerequisites

Before getting started, make sure you have:

- An AWS account.
- Git and Git Bash (for Windows users).
- AWS CLI installed.
- Terraform installed.
- An SSH key pair.
- Basic familiarity with AWS, EC2, SSH, and Terraform.

> **Cost warning:** AWS resources may incur charges while they are running. Destroy resources when they are no longer required.

## Getting Started

### 1. Clone the Repository

Open Git Bash or a terminal and clone the repository:

```bash
git clone https://gitlab.com/connect2sazad/aws-terraform-modular-ec2.git
cd aws-terraform-modular-ec2
```

You can also clone the project from the [GitHub repository](https://github.com/connect2sazad/aws-terraform-modular-ec2).

### 2. Generate an SSH Key Pair

Run the following command from the repository directory:

```bash
ssh-keygen -t ed25519 -C "your_email@example.com" -f id_ed25519
```

Replace `your_email@example.com` with your email address.

This creates two files:

| File | Purpose |
|---|---|
| `id_ed25519` | Private key. Keep this secret. |
| `id_ed25519.pub` | Public key. Terraform uses this to configure EC2 SSH access. |

**Never share or commit your private key.**

### 3. Configure SSH Key Files

Make sure the public key path in your Terraform configuration points to `id_ed25519.pub`.

For example, the key-pair resource may look like this:

```hcl
resource "aws_key_pair" "terraform_aws_key" {
  key_name   = var.keypair_name
  public_key = file("${path.module}/id_ed25519.pub")
}
```

Ensure your `.gitignore` excludes sensitive and generated files. For example:

```gitignore
id_ed25519
id_ed25519.pub
*.tfstate
*.tfstate.*
*.tfplan
tfplan
.terraform/
crash.log
crash.*.log
```

You can commit `.terraform.lock.hcl` to help keep provider selections consistent across environments.

Never commit private keys, AWS credentials, Terraform state files, or sensitive plan files.

### 4. Install AWS CLI

Install the AWS CLI for your operating system.

#### Windows

Run in PowerShell:

```powershell
Invoke-WebRequest -Uri "https://awscli.amazonaws.com/AWSCLIV2.msi" -OutFile "$env:TEMP\AWSCLIV2.msi"

Start-Process msiexec.exe -ArgumentList "/i `"$env:TEMP\AWSCLIV2.msi`" /qn" -Wait
```

Verify the installation:

```powershell
aws --version
```

#### Linux (x86_64)

```bash
curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
unzip awscliv2.zip
sudo ./aws/install
aws --version
```

#### macOS

```bash
curl "https://awscli.amazonaws.com/AWSCLIV2.pkg" -o "AWSCLIV2.pkg"
sudo installer -pkg AWSCLIV2.pkg -target /
aws --version
```

Official guide: [Installing or updating the latest version of the AWS CLI](https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html).

### 5. Configure AWS Access

Use a secure method to provide Terraform and the AWS CLI with credentials.

Prefer AWS IAM Identity Center or an approved IAM role with temporary credentials whenever possible.

Alternatively, an IAM user with programmatic credentials may be used if that is appropriate for your environment:

1. Open the [AWS IAM Console](https://console.aws.amazon.com/iam/).
2. Navigate to **Users** and select **Create user**.
3. Enter a username.
4. Configure programmatic access using the appropriate credentials workflow.
5. Assign only the permissions required by your Terraform configuration.
6. Store generated credentials securely.

Avoid unrestricted administrator permissions unless they are explicitly required and approved.

### 6. Configure AWS CLI

Run:

```bash
aws configure
```

Enter your AWS credentials and preferred region when prompted.

Example:

```text
AWS Access Key ID: YOUR_ACCESS_KEY_ID
AWS Secret Access Key: YOUR_SECRET_ACCESS_KEY
Default region name: ap-south-1
Default output format: json
```

Replace `ap-south-1` with your intended AWS region.

Verify the active AWS identity:

```bash
aws sts get-caller-identity
```

Make sure the returned account and identity are the ones in which you intend to create resources.

### 7. Install Terraform

Install Terraform by following the [official HashiCorp installation guide](https://developer.hashicorp.com/terraform/install).

Verify the installation:

```bash
terraform -version
```

### 8. Initialize Terraform

From the repository directory, run:

```bash
terraform init
```

This initializes the Terraform working directory and downloads the required providers.

### 9. Select a User Data Plugin

One of the main features of this project is variable-driven User Data script selection.

Instead of modifying the EC2 resource or maintaining separate Terraform configurations, change the `user_data_plugin` variable in `terraform.tfvars`.

#### Example: Docker installation

```hcl
user_data_plugin = "docker"
machine_type     = "t3.micro"
volume_size      = 10
```

#### Example: Kubernetes tools installation

```hcl
user_data_plugin = "kind+kubectl"
machine_type     = "t3.medium"
volume_size      = 30
```

Terraform selects the matching shell script using the configured variable. The EC2 resource can use an expression such as:

```hcl
user_data = file("${path.module}/ud-plugins/${var.user_data_plugin}.sh")
```

The mapping is:

| Variable value | Script selected |
|---|---|
| `docker` | `ud-plugins/docker.sh` |
| `kind+kubectl` | `ud-plugins/kind+kubectl.sh` |

To add another installation option:

1. Create a new `.sh` script inside `ud-plugins/`.
2. Add the required installation and configuration commands to it.
3. Set `user_data_plugin` to the script filename without the `.sh` extension.

For example, `ud-plugins/nginx.sh` can be selected with:

```hcl
user_data_plugin = "nginx"
```

**Make sure the selected script exists before running Terraform.**

### 10. Start EC2 Using Automation Scripts

This project includes automated scripts for both Windows and Linux/macOS users.

These scripts simplify the Terraform workflow by automating infrastructure initialization, validation, deployment, and destruction.

#### Windows

Windows users can execute the following batch files from the project directory.

**Start EC2**

```bat
launch_ec2.bat
```

**Stop EC2**

```bat
destroy_ec2.bat
```

The batch files automate the respective Terraform operations. Make sure AWS CLI credentials and Terraform are configured before execution.

#### Linux / macOS

Linux and macOS users can use the Bash scripts.

First, provide execution permissions:

```bash
chmod +x launch_ec2.sh destroy_ec2.sh
```

**Start EC2**

```bash
./launch_ec2.sh
```

The startup script performs the following operations:

1. Checks whether Terraform is installed.
2. Checks whether AWS CLI is installed.
3. Validates AWS credentials using `aws sts get-caller-identity`.
4. Checks whether the SSH client is installed.
5. Verifies that the `id_ed25519` private key exists.
6. Checks for Terraform configuration files.
7. Initializes Terraform if it has not already been initialized.
8. Formats Terraform configuration files.
9. Validates the Terraform configuration.
10. Generates a Terraform execution plan.
11. Applies the Terraform configuration.
12. Retrieves the EC2 instance's public IP address.
13. Provides an option to connect to the instance through SSH.

After deployment, the script displays the EC2 public IP.

You will be prompted:

- Press **ENTER** to connect to the EC2 instance using SSH.
- Press any other key to exit.

The SSH connection uses:

```bash
ssh -i id_ed25519 ubuntu@<AWS-EC2-PUBLIC-IP>
```

**Stop EC2**

```bash
./destroy_ec2.sh
```

This script automatically destroys the Terraform-managed infrastructure.

#### Important Notes

- Execute scripts from the root directory of the Terraform project.
- Ensure AWS CLI credentials are configured.
- Ensure the SSH private key exists before running the startup script.
- The startup script assumes the Terraform output is named `instance_public_ip`.
- The SSH connection assumes an Ubuntu EC2 instance.
- Review your Terraform configuration and AWS environment before deployment.

### 11. Validate the Configuration

Format and validate the Terraform configuration:

```bash
terraform fmt -recursive
terraform validate
```

Before proceeding, check:

- AWS region and AMI configuration.
- EC2 instance type.
- SSH public key path.
- Security group rules.
- Selected User Data plugin and script path.

Ensure SSH access on port `22` is restricted to your trusted public IP address rather than exposed to the entire internet.

### 12. Create a Terraform Plan

Generate an execution plan:

```bash
terraform plan -out=tfplan
```

Review the proposed changes before applying them.

Treat the plan file as potentially sensitive. Do not commit it to Git.

### 13. Create the EC2 Instance

Apply the reviewed plan:

```bash
terraform apply tfplan
```

Terraform provisions the AWS resources defined in the configuration.

During the EC2 instance's initial launch, the instance executes the selected User Data script. Depending on the selected plugin, the corresponding tools are installed automatically.

Wait for Terraform to finish successfully.

> **Important:** Terraform completing successfully does not necessarily mean all User Data commands have finished. Allow instance initialization to complete before verifying the software installation.

### 14. Connect to the EC2 Instance

Check the Terraform outputs:

```bash
terraform output
```

If your configuration defines an output named `instance_public_ip`, retrieve it with:

```bash
terraform output -raw instance_public_ip
```

Connect to the instance:

```bash
ssh -i id_ed25519 ubuntu@<AWS-EC2-PUBLIC-IP>
```

Replace `<AWS-EC2-PUBLIC-IP>` with the instance's actual public IP address.

This example assumes an Ubuntu AMI and the default Ubuntu SSH username. Other AMIs may use a different SSH username.

On Linux or macOS, if required, restrict private key permissions:

```bash
chmod 600 id_ed25519
```

### 15. Verify the Installation

The verification steps depend on the selected User Data plugin.

#### Docker

Check the Docker version:

```bash
docker --version
```

Check the Docker service:

```bash
sudo systemctl status docker
```

Run a test container:

```bash
sudo docker run hello-world
```

If you want to run Docker without `sudo`, you can add your user to the Docker group:

```bash
sudo usermod -aG docker "$USER"
```

Log out and reconnect for the group change to take effect.

> **Security note:** Membership in the Docker group grants highly privileged access to the host.

#### Kubernetes (Kind + kubectl)

Check kubectl:

```bash
kubectl version --client
```

Check Kind:

```bash
kind version
```

If your plugin creates a Kind cluster, list the clusters:

```bash
kind get clusters
```

Check Kubernetes nodes:

```bash
kubectl get nodes
```

Refer to the selected plugin script for the exact installation and cluster initialization steps. The commands above verify the tools and, where applicable, the cluster created by the script.

### 16. Destroy the Infrastructure

When you no longer need the EC2 instance and other Terraform-managed resources, you can destroy the infrastructure using the automated scripts.

**Windows:**

```bat
destroy_ec2.bat
```

**Linux / macOS:**

```bash
./destroy_ec2.sh
```

Both scripts execute:

```bash
terraform destroy --auto-approve
```

This automatically destroys the infrastructure managed by the active Terraform configuration without requesting interactive confirmation.

Alternatively, you can manually destroy the infrastructure:

```bash
terraform destroy
```

Terraform will display the resources scheduled for deletion and ask for confirmation.

> **Warning:** The automated stop scripts use `-auto-approve`. Always verify your AWS account, region, Terraform workspace, and state before executing them.

After destruction, check the AWS Console for resources that may exist outside Terraform's management.

## Important Note About User Data Changes

The `user_data` configuration in this project is intended for initial EC2 provisioning.

Changing `user_data_plugin` after an instance has already been created does **not** mean Terraform will simply rerun the new installation script on that existing machine. Depending on the AWS provider configuration and resource lifecycle behavior, a User Data change may cause the EC2 instance to be replaced.

Always review the Terraform plan before applying a plugin change. If Terraform proposes replacing the instance, remember that replacement can interrupt services and may affect data stored on resources that are not persistent.

For repeatable configuration management on existing instances, consider a dedicated configuration-management or deployment approach rather than assuming EC2 User Data will rerun automatically.

## Troubleshooting

### Terraform command not found

- Confirm Terraform is installed.
- Ensure the Terraform executable is available in your system's `PATH`.
- Reopen the terminal after installation if necessary.

### AWS access denied

Check the active AWS identity:

```bash
aws sts get-caller-identity
```

Then verify that:

- The intended AWS account is active.
- The configured region is correct.
- The IAM identity has the permissions required by the Terraform configuration.

### SSH connection timed out

Check:

- EC2 instance state and status checks.
- Public IP address.
- Security group inbound rules.
- Subnet routing.
- Internet gateway configuration.
- Network ACL rules, if applicable.

### Permission denied (publickey)

- Confirm the private key matches the public key registered with EC2.
- Confirm the correct private key is being used.
- Confirm the SSH username matches the AMI.
- Check private key file permissions.

### User Data script did not execute successfully

Check the EC2 initialization output:

```bash
sudo cat /var/log/cloud-init-output.log
```

Check cloud-init status:

```bash
sudo cloud-init status --long
```

### Docker is not running

Inspect the Docker service:

```bash
sudo systemctl status docker
```

Review recent Docker service logs:

```bash
sudo journalctl -u docker --no-pager -n 100
```

### Selected plugin file not found

Make sure the selected script exists inside `ud-plugins/`.

For example, this configuration:

```hcl
user_data_plugin = "docker"
```

requires this file:

```text
ud-plugins/docker.sh
```

Also check spelling and capitalization because file paths are case-sensitive on Linux.

## Best Practices

- Prefer temporary AWS credentials.
- Follow the principle of least privilege for IAM permissions.
- Never commit private keys or AWS credentials.
- Never commit Terraform state or sensitive plan files.
- Review Terraform plans before applying changes.
- Restrict SSH access to trusted IP addresses.
- Use remote Terraform state with appropriate access controls for collaborative projects.
- Keep installation scripts modular and maintainable.
- Test new User Data scripts before using them in production.
- Monitor AWS resource usage and costs.
- Destroy unused infrastructure.

## Future Improvements

- Add more User Data installation plugins.
- Support additional DevOps tools and technologies.
- Introduce reusable Terraform modules.
- Add automated deployment through GitLab CI/CD.
- Implement remote Terraform state management.
- Improve infrastructure validation and security checks.

## Useful Resources

| Resource | Link |
|---|---|
| Portfolio | https://connect2sazad.github.io/ |
| GitLab Repository | https://gitlab.com/connect2sazad/aws-terraform-modular-ec2 |
| GitHub Repository | https://github.com/connect2sazad/aws-terraform-modular-ec2 |
| AWS CLI Documentation | https://docs.aws.amazon.com/cli/latest/userguide/ |
| AWS IAM Documentation | https://docs.aws.amazon.com/iam/ |
| Amazon EC2 Documentation | https://docs.aws.amazon.com/ec2/ |
| Terraform Documentation | https://developer.hashicorp.com/terraform/docs |
| Docker Documentation | https://docs.docker.com/ |
| Kind Documentation | https://kind.sigs.k8s.io/ |
| Kubernetes Documentation | https://kubernetes.io/docs/ |

## Author

**Sazad**

- **Portfolio:** https://connect2sazad.github.io/
- **GitHub:** https://github.com/connect2sazad
- **GitLab:** https://gitlab.com/connect2sazad

If you find this project useful, consider giving the repository a ⭐.
