
# Fresh EC2 with Docker Setup using Terraform

Automate the creation of an AWS EC2 instance and install Docker using Terraform.

**Portfolio:** [https://connect2sazad.github.io/](https://connect2sazad.github.io/)

**GitHub Repository:** [fresh-ec2-with-docker-setup](https://github.com/connect2sazad/fresh-ec2-with-docker-setup)

## Prerequisites

Before getting started, ensure you have:

- An AWS account.
- Git and Git Bash installed (Windows users).
- AWS CLI installed.
- Terraform installed.
- An SSH key pair.
- Basic knowledge of AWS, EC2, SSH, and Terraform.

> **Note:** AWS resources may incur charges. Destroy resources when they are no longer needed.

## Step 1: Clone the Repository

Open Git Bash or your terminal and run:

```bash
git clone https://github.com/connect2sazad/fresh-ec2-with-docker-setup.git
cd fresh-ec2-with-docker-setup
```

## Step 2: Generate an SSH Key Pair

Run the following command inside the repository directory:

```bash
ssh-keygen -t ed25519 -C "your_email@example.com" -f id_ed25519
```

Replace `your_email@example.com` with your email address.

This generates two files:

- `id_ed25519` — Private key.
- `id_ed25519.pub` — Public key.

Never share or commit your private key.

## Step 3: Configure the SSH Key Files

Ensure the public key path in your Terraform configuration matches `id_ed25519.pub`.

Your repository may look like this:

```text
fresh-ec2-with-docker-setup/
├── id_ed25519
├── id_ed25519.pub
├── main.tf
├── variables.tf
├── outputs.tf
└── .gitignore
```

The Terraform filenames may differ depending on the repository configuration.

Make sure `.gitignore` excludes sensitive and generated files:

```gitignore
id_ed25519
*.tfstate
*.tfstate.*
*.tfplan
tfplan
.terraform/
.terraform.lock.hcl
```

If you commit `.terraform.lock.hcl` to version control for reproducible provider installations, remove that entry from `.gitignore`.

Never commit private keys, AWS credentials, Terraform state, or sensitive plan files.

## Step 4: Install AWS CLI

### Windows

Run in PowerShell:

```powershell
Invoke-WebRequest -Uri "https://awscli.amazonaws.com/AWSCLIV2.msi" -OutFile "$env:TEMP\AWSCLIV2.msi"

Start-Process msiexec.exe -ArgumentList "/i `"$env:TEMP\AWSCLIV2.msi`" /qn" -Wait
```

Verify:

```powershell
aws --version
```

### Linux (x86_64)

```bash
curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
unzip awscliv2.zip
sudo ./aws/install
aws --version
```

### macOS

```bash
curl "https://awscli.amazonaws.com/AWSCLIV2.pkg" -o "AWSCLIV2.pkg"
sudo installer -pkg AWSCLIV2.pkg -target /
aws --version
```

Official guide: https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html

## Step 5: Configure AWS Access

Prefer AWS IAM Identity Center or an approved IAM role with temporary credentials when available.

Alternatively, create an IAM user in the AWS Console:

1. Open the [AWS IAM Console](https://console.aws.amazon.com/iam/).
2. Navigate to **Users** and select **Create user**.
3. Enter a username.
4. Leave AWS Management Console access disabled if the user only needs programmatic access.
5. Assign the minimum permissions required by the Terraform configuration.
6. Create the user.

Avoid unrestricted administrator permissions unless explicitly required and approved.

## Step 6: Generate AWS Access Keys

If using an IAM user's access keys:

1. Open the user in IAM.
2. Select **Security credentials**.
3. Under **Access keys**, select **Create access key**.
4. Choose the appropriate use case for local development.
5. Follow the prompts and securely save the credentials.

Do not share or commit your access keys.

## Step 7: Configure the AWS CLI

Run:

```bash
aws configure
```

Enter your credentials and preferred AWS region when prompted.

For example:

```text
AWS Access Key ID: YOUR_ACCESS_KEY_ID
AWS Secret Access Key: YOUR_SECRET_ACCESS_KEY
Default region name: ap-south-1
Default output format: json
```

Replace `ap-south-1` with your intended AWS region.

Verify your AWS identity:

```bash
aws sts get-caller-identity
```

## Step 8: Install Terraform

Install Terraform by following the official guide:

https://developer.hashicorp.com/terraform/install

Verify the installation:

```bash
terraform -version
```

## Step 9: Initialize Terraform

Navigate to the repository directory:

```bash
cd fresh-ec2-with-docker-setup
terraform init
```

## Step 10: Validate the Configuration

Format and validate the Terraform files:

```bash
terraform fmt -recursive
terraform validate
```

Check the AWS region, AMI, instance type, SSH public key path, and security group rules.

Ensure SSH access on port `22` is restricted to your trusted public IP address.

## Step 11: Create a Terraform Plan

Generate the execution plan:

```bash
terraform plan -out=tfplan
```

Review the proposed changes before applying them.

Treat the plan file as potentially sensitive and never commit it to Git.

## Step 12: Create the EC2 Instance

Apply the reviewed plan:

```bash
terraform apply tfplan
```

Terraform will create the AWS resources defined in your configuration.

Depending on the configuration, the EC2 instance may also install Docker automatically.

Wait for Terraform to finish successfully.

## Step 13: Connect to the EC2 Instance

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

Replace `<AWS-EC2-PUBLIC-IP>` with the actual public IP address.

This example assumes the instance uses Ubuntu and the private key is named `id_ed25519`.

If required on Linux or macOS, restrict private key permissions:

```bash
chmod 600 id_ed25519
```

## Step 14: Verify Docker

Once connected, check the Docker installation:

```bash
docker --version
```

Check whether the Docker service is running:

```bash
sudo systemctl status docker
```

Test Docker:

```bash
sudo docker run hello-world
```

If you want to use Docker without `sudo`, you can add your user to the Docker group:

```bash
sudo usermod -aG docker "$USER"
```

Log out and reconnect for the change to take effect.

**Security note:** Membership in the Docker group grants highly privileged access to the host.

## Step 15: Destroy the Infrastructure

When you no longer need the EC2 instance, run:

```bash
terraform destroy
```

Review the proposed deletions and confirm when prompted.

For automated environments, you can use:

```bash
terraform destroy -auto-approve
```

Use the non-interactive command only after confirming the AWS account, region, and Terraform workspace.

Check the AWS Console afterward for resources that might remain outside Terraform's management.

## Troubleshooting

### Terraform command not found

Ensure Terraform is installed and available in your system's PATH.

### AWS access denied

Check the active AWS identity:

```bash
aws sts get-caller-identity
```

Verify the region and required IAM permissions.

### SSH connection timed out

Check the instance status, public IP, security group, subnet routing, and internet gateway.

### Permission denied (publickey)

Ensure the private key matches the configured public key and that you are using the correct SSH username.

### Docker is not running

Inspect the Docker service:

```bash
sudo systemctl status docker
sudo journalctl -u docker --no-pager -n 100
```

## Best Practices

- Prefer temporary AWS credentials.
- Use least-privilege IAM permissions.
- Never commit private keys or AWS credentials.
- Review Terraform plans before applying changes.
- Restrict SSH access to trusted IP addresses.
- Use remote Terraform state with appropriate access controls for collaborative projects.
- Monitor AWS costs.
- Destroy unused resources.

## Useful Resources

- [Portfolio](https://connect2sazad.github.io/)
- [GitHub Repository](https://github.com/connect2sazad/fresh-ec2-with-docker-setup)
- [AWS CLI Documentation](https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html)
- [AWS IAM Documentation](https://docs.aws.amazon.com/IAM/latest/UserGuide/introduction.html)
- [Amazon EC2 Documentation](https://docs.aws.amazon.com/ec2/)
- [Terraform Documentation](https://developer.hashicorp.com/terraform/docs)
- [Docker Documentation](https://docs.docker.com/)

## Author

**Sazad**

Portfolio: https://connect2sazad.github.io/

GitHub: https://github.com/connect2sazad

If you find this project useful, consider giving the repository a ⭐.