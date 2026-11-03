@echo off
setlocal

title Terraform Infrastructure Destroy

:: ======================================
:: RED WARNING SCREEN
:: ======================================

color 4F
cls

echo.
echo ==========================================
echo.
echo       TERRAFORM INFRASTRUCTURE
echo.
echo                 DESTROY
echo.
echo ==========================================
echo.
echo WARNING: This will permanently destroy
echo all infrastructure managed by Terraform.
echo.
echo ==========================================
echo.

choice /c YN /n /m "Are you SURE you want to DESTROY? (Y/N): "

if errorlevel 2 goto cancel
if errorlevel 1 goto checks

:: ======================================
:: PRE-FLIGHT CHECKS
:: ======================================

:checks
color 07
cls

echo.
echo ==========================================
echo       TERRAFORM PRE-FLIGHT CHECK
echo ==========================================
echo.

echo [CHECK] Terraform...
where terraform >nul 2>&1
if errorlevel 1 (
    echo ERROR: Terraform is not installed.
    goto error
)
terraform version

echo.
echo [CHECK] Terraform Configuration...
dir /b *.tf >nul 2>&1
if errorlevel 1 (
    echo ERROR: No Terraform .tf files found.
    goto error
)

:: Initialize Terraform if needed
if not exist ".terraform" (
    echo.
    echo Initializing Terraform...
    terraform init
    if errorlevel 1 goto error
) else (
    echo Terraform already initialized.
)

:: Validate Terraform
echo.
echo Validating Terraform configuration...
terraform validate
if errorlevel 1 goto error

:: ======================================
:: DESTROY INFRASTRUCTURE
:: ======================================

color 4F
echo.
echo ==========================================
echo          DESTROYING INFRASTRUCTURE
echo ==========================================
echo.

terraform destroy --auto-approve

if errorlevel 1 goto destroy_error

:: ======================================
:: DESTROY SUCCESS
:: ======================================

color 2F
echo.
echo ==========================================
echo.
echo          DESTROY SUCCESSFUL!
echo.
echo ==========================================
echo.
echo All Terraform-managed resources destroyed.
goto end

:: ======================================
:: CANCEL
:: ======================================

:cancel
color 2F
echo.
echo ==========================================
echo          DESTROY CANCELLED
echo ==========================================
echo.
echo No checks or destroy operations performed.
goto end

:: ======================================
:: ERRORS
:: ======================================

:error
color 4F
echo.
echo ==========================================
echo          PRE-CHECK FAILED!
echo ==========================================
goto finish_error

:destroy_error
color 4F
echo.
echo ==========================================
echo          DESTROY FAILED!
echo ==========================================
goto finish_error

:finish_error
echo.
pause
exit /b 1

:end
echo.
pause
color 07
endlocal
exit /b 0
