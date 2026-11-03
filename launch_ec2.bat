@echo off
setlocal enabledelayedexpansion

title Terraform EC2 Deployment

echo.
echo ======================================
echo       TERRAFORM PRE-FLIGHT CHECK
echo ======================================
echo.

:: ======================================
:: PRE-FLIGHT CHECKS
:: ======================================

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

:: ======================================
:: TERRAFORM DEPLOYMENT
:: ======================================

:: Step 1: Initialize Terraform
if not exist ".terraform" (
    echo [1/6] Initializing Terraform...
    terraform init
    if errorlevel 1 goto deployment_error
) else (
    echo [1/6] Terraform already initialized. Skipping init.
)

:: Step 2: Format Terraform files
echo.
echo [2/6] Formatting Terraform files...
terraform fmt -recursive
if errorlevel 1 goto deployment_error

:: Step 3: Validate Terraform configuration
echo.
echo [3/6] Validating Terraform configuration...
terraform validate
if errorlevel 1 goto deployment_error

:: Step 4: Create Terraform plan
echo.
echo [4/6] Creating Terraform plan...
terraform plan -out=tfplan
if errorlevel 1 goto deployment_error

:: Step 5: Apply Terraform plan
echo.
echo [5/6] Applying Terraform configuration...
terraform apply --auto-approve tfplan
if errorlevel 1 goto deployment_error

:: ======================================
:: DEPLOYMENT SUCCESSFUL
:: ======================================

echo.
echo ======================================
echo    TERRAFORM DEPLOYMENT SUCCESSFUL!
echo ======================================
echo Infrastructure has been deployed.
echo.

:: ======================================
:: GET EC2 PUBLIC IP
:: ======================================

echo [6/6] Fetching EC2 public IP...

set "INSTANCE_IP="

for /f "delims=" %%i in ('powershell -NoProfile -Command "(terraform output -json instance_public_ip | ConvertFrom-Json)[0]"') do (
    set "INSTANCE_IP=%%i"
)

if not defined INSTANCE_IP (
    echo.
    echo WARNING: Could not retrieve EC2 public IP.
    echo Infrastructure deployment was successful.
    echo Run: terraform output instance_public_ip
    goto post_deployment_end
)

echo.
echo ======================================
echo       EC2 INSTANCE PUBLIC IP
echo       !INSTANCE_IP!
echo ======================================
echo.

:: ======================================
:: SSH OR EXIT
:: ======================================

choice /c YN /n /m "Press Y to SSH into Ubuntu or N to exit: "

if errorlevel 2 goto exit
if errorlevel 1 goto ssh

:ssh
echo.
echo Connecting to Ubuntu instance...
echo.

echo.
echo Configuring SSH private key permissions...

:: Remove inherited permissions
icacls "id_ed25519" /inheritance:r

:: Grant access only to current user
icacls "id_ed25519" /grant:r "%USERNAME%:R"

echo SSH key permissions configured.

ssh -i id_ed25519 ubuntu@!INSTANCE_IP!

if errorlevel 1 (
    echo.
    echo WARNING: SSH connection failed.
    echo Infrastructure is still deployed successfully.
)

goto post_deployment_end

:: ======================================
:: USER EXIT
:: ======================================

:exit
echo.
echo Exiting...
goto post_deployment_end

:: ======================================
:: TERRAFORM DEPLOYMENT ERROR
:: ======================================

:deployment_error
echo.
echo ======================================
echo      TERRAFORM DEPLOYMENT FAILED!
echo ======================================
echo Please check the error messages above.
echo Infrastructure deployment may be incomplete.
pause
exit /b 1

:: ======================================
:: PRE-FLIGHT ERROR
:: ======================================

:error
echo.
echo ======================================
echo       PRE-FLIGHT CHECK FAILED!
echo ======================================
echo Please fix the missing requirements.
pause
exit /b 1

:: ======================================
:: POST DEPLOYMENT COMPLETION
:: ======================================

:post_deployment_end
echo.
echo ======================================
echo       DEPLOYMENT COMPLETED
echo ======================================
echo Terraform apply completed successfully.
echo.
pause
goto end

:end
endlocal
exit /b 0
