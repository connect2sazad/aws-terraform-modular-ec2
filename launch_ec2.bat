@echo off
setlocal enabledelayedexpansion

title Terraform EC2 Deployment

echo.
echo ======================================
echo       TERRAFORM PRE-FLIGHT CHECK
echo ======================================
echo.

:: Check Terraform
echo [CHECK] Terraform...
where terraform >nul 2>&1
if errorlevel 1 (
    echo ERROR: Terraform is not installed or not in PATH.
    goto error
)
terraform version

:: Check AWS CLI
echo.
echo [CHECK] AWS CLI...
where aws >nul 2>&1
if errorlevel 1 (
    echo ERROR: AWS CLI is not installed or not in PATH.
    goto error
)
aws --version

:: Check AWS credentials
echo.
echo [CHECK] AWS Credentials...
aws sts get-caller-identity
if errorlevel 1 (
    echo ERROR: AWS credentials invalid or not configured.
    goto error
)

:: Check SSH client
echo.
echo [CHECK] SSH Client...
where ssh >nul 2>&1
if errorlevel 1 (
    echo ERROR: SSH client is not installed or not in PATH.
    goto error
)
ssh -V

:: Check private key
echo.
echo [CHECK] SSH Private Key...
if not exist "id_ed25519" (
    echo ERROR: id_ed25519 private key not found.
    goto error
)
echo SSH private key found.

:: Check Terraform files
echo.
echo [CHECK] Terraform Configuration...
dir /b *.tf >nul 2>&1
if errorlevel 1 (
    echo ERROR: No Terraform .tf files found.
    goto error
)
echo Terraform configuration files found.

echo.
echo ======================================
echo       ALL CHECKS PASSED
echo ======================================
echo.

:: Initialize Terraform if not initialized
if not exist ".terraform" (
    echo [1/6] Initializing Terraform...
    terraform init
    if errorlevel 1 goto error
) else (
    echo [1/6] Terraform already initialized. Skipping init.
)

:: Format Terraform files
echo.
echo [2/6] Formatting Terraform files...
terraform fmt -recursive
if errorlevel 1 goto error

:: Validate Terraform configuration
echo.
echo [3/6] Validating Terraform configuration...
terraform validate
if errorlevel 1 goto error

:: Create Terraform plan
echo.
echo [4/6] Creating Terraform plan...
terraform plan -out=tfplan
if errorlevel 1 goto error

:: Apply Terraform plan
echo.
echo [5/6] Applying Terraform configuration...
terraform apply --auto-approve tfplan
if errorlevel 1 goto error

:: Get EC2 public IP
echo.
echo [6/6] Fetching EC2 public IP...
for /f "delims=" %%i in ('terraform output -raw instance_public_ip') do set INSTANCE_IP=%%i

if not defined INSTANCE_IP (
    echo ERROR: Could not retrieve EC2 public IP.
    goto error
)

echo.
echo ======================================
echo  EC2 INSTANCE PUBLIC IP
echo  !INSTANCE_IP!
echo ======================================
echo.

:: SSH or Exit
choice /c YN /n /m "Press Y to SSH into Ubuntu or N to exit: "

if errorlevel 2 goto exit
if errorlevel 1 goto ssh

:ssh
echo.
echo Connecting to Ubuntu instance...
ssh -i id_ed25519 ubuntu@!INSTANCE_IP!
goto end

:exit
echo.
echo Exiting...
goto end

:error
echo.
echo ======================================
echo       DEPLOYMENT STOPPED!
echo ======================================
pause
exit /b 1

:end
echo.
pause
endlocal
