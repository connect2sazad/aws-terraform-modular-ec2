# AWS Terraform Modular EC2 Infrastructure v1.0.1

Automate the provisioning and initial configuration of AWS EC2 instances with Terraform and reusable, variable-driven User Data scripts.

This project uses a reusable Terraform configuration to provision EC2 infrastructure and install different tools by selecting User Data talent scripts. The selected talents are configured through Terraform variables, allowing multiple tools to be installed on one EC2 instance.

**Portfolio:** <https://connect2sazad.github.io/>  
**GitLab:** <https://gitlab.com/connect2sazad/aws-terraform-modular-ec2>  
**GitHub:** <https://github.com/connect2sazad/aws-terraform-modular-ec2>

---

## Table of Contents

- [Features](#features)
- [Available User Data Talents](#available-user-data-talents)
  - [Supported Talents](#supported-talents)
  - [Talent Selection Syntax](#talent-selection-syntax)
  - [Version Selection Behavior](#version-selection-behavior)
  - [Adding a New Talent](#adding-a-new-talent)
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
  - [9. Select User Data Talents and Versions](#9-select-user-data-talents-and-versions)
  - [10. Launch EC2 Using Automation Scripts](#10-launch-ec2-using-automation-scripts)
  - [11. Validate the Configuration](#11-validate-the-configuration)
  - [12. Create a Terraform Plan](#12-create-a-terraform-plan)
  - [13. Create the EC2 Instance](#13-create-the-ec2-instance)
  - [14. Connect to the EC2 Instance](#14-connect-to-the-ec2-instance)
  - [15. Verify the Installation](#15-verify-the-installation)
  - [16. Destroy the Infrastructure](#16-destroy-the-infrastructure)
- [How It Works](#how-it-works)
- [Talent Execution Workflow](#talent-execution-workflow)
- [Important Note About User Data Changes](#important-note-about-user-data-changes)
- [Installation Logs](#installation-logs)
- [Troubleshooting](#troubleshooting)
- [Best Practices](#best-practices)
- [Future Improvements](#future-improvements)
- [Useful Resources](#useful-resources)
- [Author](#author)

## Features

- Modular, reusable Terraform infrastructure.
- Variable-driven User Data talent selection.
- Terraform-side parsing of optional talent version values and `PLUGIN_VERSION` injection.
- Support for selecting multiple installation talents for one EC2 instance.
- Reusable and independently maintained installation scripts.
- Configurable EC2 instance types and EBS volume sizes.
- Customizable EC2 instance names, roles, and environments.
- AWS security group and SSH key pair integration.
- GMT-timestamped installation logs.
- Installation duration tracking.
- Automated software installation during EC2 initialization.
- Automated EC2 provisioning using Windows batch scripts.
- Linux/macOS support through Bash automation scripts.

> **Version support status:** Terraform parses optional version suffixes and injects `PLUGIN_VERSION`. The current variable validation needs a fix before versioned entries are accepted, and each installation script must independently implement the requested-version behavior.

## Available User Data Talents

The `talents/` directory contains reusable shell scripts responsible for installing and configuring software on the EC2 instance.

### Supported Talents

| Talent | Description |
|---|---|
| `ansible` | Installs Ansible, Python, Boto3, Botocore, and AWS Ansible collection. |
| `argocd` | Installs the Argo CD CLI. |
| `awscli` | Installs AWS CLI v2. |
| `docker` | Installs and configures Docker Engine and Docker Compose. |
| `go` | Installs Go programming language. |
| `helm` | Installs Helm Kubernetes package manager. |
| `java` | Installs Java JDK. |
| `jenkins` | Installs and configures Jenkins LTS. |
| `kind_k8s` | Installs Kind Kubernetes. |
| `kubectl` | Installs Kubernetes kubectl CLI. |
| `terraform` | Installs HashiCorp Terraform. |

### Talent Selection Syntax

The talent selection string is configured through `user_data_talent_string`.

Use `+` to combine talents. Use `:` to separate a talent name from its requested version:

```text
talent_name
talent_name:version
talent_name+talent_name
talent_name:version+talent_name:version
```

**Examples:**

| Configuration | Intended selection |
|---|---|
| `docker` | Docker, using the script's default behavior. |
| `docker+go` | Docker and Go. |
| `docker:27.5.1` | Docker with `PLUGIN_VERSION` set to `27.5.1`. |
| `docker:27.5.1+go:1.23.4` | Docker and Go, each with its own requested version. |
| `docker+kind_k8s+kubectl+helm` | Multiple Kubernetes-related tools. |

The version values above are examples. Use versions that the corresponding installation scripts know how to install.

### Version Selection Behavior

The Terraform configuration in `ec2.tf` parses the talent selection string and injects a `PLUGIN_VERSION` environment variable before each selected script.

The implementation works as follows:

1. `split("+", var.user_data_talent_string)` separates the selected talents.
2. `trimspace(talent)` removes surrounding whitespace from each talent entry.
3. `split(":", ...)` separates the talent name from its optional version.
4. The talent name is used to load `talents/<talent-name>.sh`.
5. Terraform generates an `export PLUGIN_VERSION='<version>'` command immediately before that talent's script content.
6. `join("\n", ...)` combines the generated commands and script contents into `local.user_data`.
7. The EC2 instance executes the generated User Data during initialization.

For an unversioned talent, Terraform sets `PLUGIN_VERSION` to an empty string. The installation script should treat an empty value as a request to use its default installation behavior.

**Important distinction:** Terraform's version parsing and environment-variable injection are implemented. Actual explicit version installation depends on each talent script reading `PLUGIN_VERSION` and using it in its installation commands. Do not claim that every talent supports every version until each script has been checked and tested.

#### Important validation limitation in the supplied `variables.tf`

The current `user_data_talent_string` validation checks each complete `+`-separated entry against `available_user_data_talents`. It does not remove the `:version` suffix before checking the talent name.

As a result, a value such as:

```hcl
user_data_talent_string = "docker:27.5.1"
```

will fail the current validation if `available_user_data_talents` contains `docker` rather than `docker:27.5.1`.

The version parsing in `ec2.tf` is present, but the current variable validation must also be updated to validate the talent name separately from its version before versioned selections can pass Terraform validation.

The current validation also checks duplicates using the complete talent entries. It can therefore treat `docker` and `docker:27.5.1` as different entries even though both select the same talent. Prefer validating uniqueness using parsed talent names.

#### Version support by installation script

Each talent script must explicitly handle `PLUGIN_VERSION`. For example, a script can use the requested version when it is non-empty and otherwise use its default installation method:

```bash
if [ -n "${PLUGIN_VERSION:-}" ]; then
    echo "Requested version: ${PLUGIN_VERSION}"
    # Install the requested version here.
else
    echo "No version requested; using the script's default version."
    # Install the default version here.
fi
```

This is an illustrative pattern, not a claim that every existing talent script already implements it.

**Shell-safety note:** `ec2.tf` currently places the version inside single quotes in a generated shell command. Validate version strings to allow only expected version characters (for example, letters, digits, dots, underscores, plus signs, and hyphens) so that a value cannot break out of the quoted shell assignment.

### Adding a New Talent

1. Create a shell script inside `talents/`.
2. Implement the installation and verification logic.
3. Add the talent name to `available_user_data_talents` in `terraform.tfvars`, if that variable is used by the current configuration.
4. Select the talent using `user_data_talent_string`.
5. If explicit version support is added, implement and test `PLUGIN_VERSION` handling in both Terraform and the installation script.

For example, `talents/nginx.sh` could be selected using:

```hcl
user_data_talent_string = "nginx"
```

A versioned selection such as `nginx:1.26.0` should only be used after version parsing and injection have been implemented.

## Project Structure

The following structure reflects the files and talent scripts identified in the supplied README. Runtime installation logs are created on the EC2 instance and are therefore not shown as a repository directory here.

```text
aws-terraform-modular-ec2/
│
├── talents/
│   ├── ansible.sh
│   ├── argocd.sh
│   ├── awscli.sh
│   ├── docker.sh
│   ├── go.sh
│   ├── helm.sh
│   ├── java.sh
│   ├── jenkins.sh
│   ├── kind_k8s.sh
│   ├── kubectl.sh
│   └── terraform.sh
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
│
├── launch_ec2.bat
├── destroy_ec2.bat
├── launch_ec2.sh
├── destroy_ec2.sh
│
├── terraform.tf
├── terraform.tfvars
├── variables.tf
└── README.md
```

> This tree is based on the files named in the supplied README, not a fresh inspection of the repository. Add or remove entries to match the actual checked-in files. The `logs/` directory is intentionally omitted because the README describes logs being generated on the EC2 instance.

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
logs/
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

### 9. Select User Data Talents and Versions

The `user_data_talent_string` variable is used to select the software installation scripts that should execute during EC2 initialization. The supplied `ec2.tf` parses optional version suffixes and injects `PLUGIN_VERSION`; however, the current `variables.tf` validation must be fixed before versioned entries will pass validation.

You can select a single talent or combine multiple talents using `+`.

#### Example 1: Docker

```hcl
user_data_talent_string = "docker"
machine_type            = "t3.micro"
volume_size             = 10
```

#### Example 2: Multiple talents

```hcl
user_data_talent_string = "docker+go+terraform"
```

#### Example 3: Kubernetes development environment

```hcl
user_data_talent_string = "docker+kind_k8s+kubectl+helm"
machine_type            = "t3.medium"
volume_size             = 30
```

#### Versioned configuration examples (proposed)

Terraform parses these version suffixes and injects them through `PLUGIN_VERSION`. However, the current `variables.tf` validation rejects versioned entries until it is updated to validate the talent name separately. The selected installation scripts must also implement support for `PLUGIN_VERSION`.

```hcl
user_data_talent_string = "docker:VERSION"
```

```hcl
user_data_talent_string = "docker:VERSION+go:VERSION+terraform:VERSION"
```

```hcl
user_data_talent_string = "docker+go:VERSION+terraform:VERSION+kubectl:VERSION"
```

Replace `VERSION` with a version that the relevant installation script can install.

#### How It Works

The supplied `ec2.tf` uses Terraform locals to build the EC2 User Data content:

- `local.user_data_talents` parses the `user_data_talent_string` into talent names and version strings.
- `local.user_data` loads each corresponding shell script using `file("${path.module}/talents/${talent.name}.sh")`.
- Before each script's contents, Terraform adds `export PLUGIN_VERSION='<version>'`.
- The generated script contents are joined together and assigned to `aws_instance.tfserver1.user_data`.

The version variable is exported immediately before each talent script. Since the scripts are concatenated into the generated User Data, each script runs after its corresponding version assignment.

### Talent Execution Workflow

The following workflow reflects the supplied `ec2.tf` implementation:

```text
terraform.tfvars
      |
      v
user_data_talent_string
Example: docker+go:1.23.4+terraform:1.9.8
      |
      v
local.user_data_talents
      |
      +--> Split entries using "+"
      +--> Extract talent name using ":"
      +--> Extract optional version
      |
      v
local.user_data
      |
      +--> Load talents/<talent-name>.sh
      +--> Add export PLUGIN_VERSION='<version>'
      +--> Join each talent's command and script content
      |
      v
aws_instance.tfserver1.user_data
      |
      v
EC2 instance initialization
      |
      +--> Set PLUGIN_VERSION for selected talent
      +--> Execute that talent's installation script
      +--> Repeat for the next selected talent
      |
      v
Installation logs and software verification
```

**Current implementation caveat:** `ec2.tf` parses versions and injects `PLUGIN_VERSION`, but the supplied `variables.tf` validation currently rejects versioned entries because it compares the full `talent:version` string with the available talent names. Update that validation before using versioned selections. Also verify that each installation script actually consumes `PLUGIN_VERSION`; injection alone does not make a script version-aware.

## Important Note About User Data Changes

EC2 User Data scripts are generally executed during the initial instance launch.

Changing `user_data_talent_string` or modifying an installation script does not automatically reinstall software on an existing instance.

Depending on the AWS provider configuration, changing User Data may trigger EC2 instance replacement.

For example, changing:

```hcl
user_data_talent_string = "docker+go"
```

to:

```hcl
user_data_talent_string = "docker+go+terraform"
```

may cause Terraform to replace the existing EC2 instance.

Always review `terraform plan` before applying changes.

For persistent environments, consider using dedicated configuration-management tools or deployment automation instead of relying exclusively on EC2 User Data.

**Make sure every selected talent has a corresponding `.sh` file inside `talents/` before running Terraform.**

### 10. Launch EC2 Using Automation Scripts

This project includes automated scripts for both Windows and Linux/macOS users.

These scripts simplify the Terraform workflow by automating infrastructure initialization, validation, deployment, and destruction.

#### Windows

Windows users can execute the following batch files from the project directory.

**Launch EC2**

```bat
launch_ec2.bat
```

**Destroy EC2 infrastructure**

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

**Launch EC2**

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

**Destroy EC2 infrastructure**

```bash
./destroy_ec2.sh
```

This script destroys the Terraform-managed infrastructure.

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
- Selected User Data talent and script path.

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

During the EC2 instance's initial launch, the instance executes the selected User Data script. Depending on the selected talent, the corresponding tools are installed automatically.

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

The verification steps depend on the selected User Data talent.

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

If your talent creates a Kind cluster, list the clusters:

```bash
kind get clusters
```

Check Kubernetes nodes:

```bash
kubectl get nodes
```

Refer to the selected talent script for the exact installation and cluster initialization steps. The commands above verify the tools and, where applicable, the cluster created by the script.

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

Both scripts are described as executing:

```bash
terraform destroy --auto-approve
```

This automatically destroys the infrastructure managed by the active Terraform configuration without requesting interactive confirmation.

Alternatively, you can manually destroy the infrastructure:

```bash
terraform destroy
```

Terraform will display the resources scheduled for deletion and ask for confirmation.

> **Warning:** The automated destroy scripts use `-auto-approve`. Always verify your AWS account, region, Terraform workspace, and state before executing them.

After destruction, check the AWS Console for resources that may exist outside Terraform's management.

## Installation Logs

Each User Data talent generates its own installation log during EC2 initialization.

All installation logs are stored on the EC2 instance in:

```text
/home/ubuntu/aws-terraform-modular-ec2/logs/
```

### Available Log Files

| Talent | Log file |
|---|---|
| Docker | `docker-install.log` |
| Go | `go-install.log` |
| Ansible | `ansible-install.log` |
| Argo CD | `argocd-install.log` |
| AWS CLI | `awscli-install.log` |
| Helm | `helm-install.log` |
| Java | `java-install.log` |
| Jenkins | `jenkins-install.log` |
| Kind | `kind_k8s-install.log` |
| kubectl | `kubectl-install.log` |
| Terraform | `terraform-install.log` |

### Viewing Installation Logs

Connect to your EC2 instance using SSH and navigate to the logs directory:

```bash
cd /home/ubuntu/aws-terraform-modular-ec2/logs
```

List available log files:

```bash
ls -lh
```

View a specific installation log:

```bash
cat docker-install.log
```

Monitor installation progress in real time:

```bash
tail -f docker-install.log
```

Each log includes GMT timestamps, installation output, error messages, and installation duration information.

> **Note:** Log files are generated on the EC2 instance. They are not automatically downloaded to your local machine and are not necessarily part of the Git repository.

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

### Selected talent file not found

Make sure the selected script exists inside `talents/`.

For example, this configuration:

```hcl
user_data_talent_string = "docker"
```

requires this file:

```text
talents/docker.sh
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

- Add more DevOps tool installation talents.
- Extend explicit version support to all talents.
- Support additional Linux distributions.
- Introduce reusable Terraform modules.
- Add automated deployment through GitLab CI/CD.
- Implement remote Terraform state management.
- Add automated testing for installation scripts.
- Improve installation failure reporting and rollback mechanisms.
- Add automated infrastructure security scanning.

## Useful Resources

| Resource | Link |
|---|---|
| Portfolio | <https://connect2sazad.github.io/> |
| GitLab Repository | <https://gitlab.com/connect2sazad/aws-terraform-modular-ec2> |
| GitHub Repository | <https://github.com/connect2sazad/aws-terraform-modular-ec2> |
| AWS CLI Documentation | <https://docs.aws.amazon.com/cli/latest/userguide/> |
| AWS IAM Documentation | <https://docs.aws.amazon.com/iam/> |
| Amazon EC2 Documentation | <https://docs.aws.amazon.com/ec2/> |
| Terraform Documentation | <https://developer.hashicorp.com/terraform/docs> |
| Docker Documentation | <https://docs.docker.com/> |
| Kind Documentation | <https://kind.sigs.k8s.io/> |
| Kubernetes Documentation | <https://kubernetes.io/docs/> |

## Author

**Sazad**

- **Portfolio:** <https://connect2sazad.github.io/>
- **GitHub:** <https://github.com/connect2sazad>
- **GitLab:** <https://gitlab.com/connect2sazad>

If you find this project useful, consider giving the repository a ⭐.
