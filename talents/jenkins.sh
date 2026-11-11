
#!/bin/bash
set -euxo pipefail

# ==========================================
# Jenkins Version Configuration
# ==========================================

JENKINS_VERSION="${PLUGIN_VERSION:-}"

# Set timezone to GMT/UTC for logging
export TZ=UTC

# Log directory
LOG_DIR="/home/ubuntu/aws-terraform-modular-ec2/logs"
mkdir -p "$LOG_DIR"

# Log all output with GMT timestamps
exec > >(while IFS= read -r line; do
    echo "[$(date '+%Y-%m-%d %H:%M:%S GMT')] $line"
done | tee -a "$LOG_DIR/jenkins-install.log") 2>&1

# Record installation start time
START_TIME=$(date +%s%3N)

echo "========================================"
echo "Starting Jenkins LTS installation..."
echo "========================================"

if [[ -n "$JENKINS_VERSION" ]]; then
    echo "Requested Jenkins version: ${JENKINS_VERSION}"
else
    echo "Jenkins version not specified. Installing latest LTS."
fi

# ==========================================
# Verify Java Installation
# ==========================================

echo "Checking Java installation..."

if ! command -v java >/dev/null 2>&1; then
    echo "ERROR: Java is not installed."
    exit 1
fi

java -version

# ==========================================
# Install Required Packages
# ==========================================

apt-get update -y

apt-get install -y \
    ca-certificates \
    curl \
    fontconfig

# ==========================================
# Configure Jenkins Repository
# ==========================================

install -m 0755 -d /etc/apt/keyrings

# Download Jenkins official GPG key
curl -fsSL \
    https://pkg.jenkins.io/debian-stable/jenkins.io-2026.key \
    -o /etc/apt/keyrings/jenkins-keyring.asc

chmod a+r /etc/apt/keyrings/jenkins-keyring.asc

# Add Jenkins LTS repository
echo "deb [signed-by=/etc/apt/keyrings/jenkins-keyring.asc] https://pkg.jenkins.io/debian-stable binary/" \
    > /etc/apt/sources.list.d/jenkins.list

# ==========================================
# Update Package Lists
# ==========================================

apt-get update -y

# ==========================================
# Install Jenkins
# ==========================================

if [[ -n "$JENKINS_VERSION" ]]; then

    echo "Installing requested Jenkins version: ${JENKINS_VERSION}"

    # Find requested Jenkins package version
    JENKINS_PACKAGE_VERSION=$(
        apt-cache madison jenkins |
        awk -v version="$JENKINS_VERSION" '
            {
                package_version = $3

                if (
                    package_version == version ||
                    index(package_version, version "-") == 1 ||
                    index(package_version, version "+") == 1
                ) {
                    print package_version
                    exit
                }
            }
        '
    )

    if [[ -z "$JENKINS_PACKAGE_VERSION" ]]; then
        echo "ERROR: Jenkins version ${JENKINS_VERSION} not found."
        echo "Available Jenkins versions:"
        apt-cache madison jenkins
        exit 1
    fi

    echo "Resolved Jenkins package version: ${JENKINS_PACKAGE_VERSION}"

    apt-get install -y "jenkins=${JENKINS_PACKAGE_VERSION}"

else

    echo "Installing latest Jenkins LTS..."

    apt-get install -y jenkins

fi

# ==========================================
# Enable and Start Jenkins
# ==========================================

systemctl enable jenkins

systemctl start jenkins

# ==========================================
# Verify Jenkins Service
# ==========================================

echo "========================================"
echo "Verifying Jenkins installation..."
echo "========================================"

systemctl is-active jenkins

jenkins --version

INSTALLED_JENKINS_VERSION=$(jenkins --version | head -n 1)

echo "Requested Jenkins version: ${JENKINS_VERSION:-latest}"
echo "Installed Jenkins version: ${INSTALLED_JENKINS_VERSION}"

# Verify requested version
if [[ -n "$JENKINS_VERSION" ]]; then

    if [[ "$INSTALLED_JENKINS_VERSION" != "$JENKINS_VERSION" ]]; then
        echo "ERROR: Jenkins version mismatch!"
        echo "Expected: ${JENKINS_VERSION}"
        echo "Installed: ${INSTALLED_JENKINS_VERSION}"
        exit 1
    fi

fi

# ==========================================
# Installation Duration
# ==========================================

END_TIME=$(date +%s%3N)
DURATION=$((END_TIME - START_TIME))

MINUTES=$((DURATION / 60000))
SECONDS=$(((DURATION % 60000) / 1000))
MILLISECONDS=$((DURATION % 1000))

echo "========================================"
echo "Jenkins installation successfully completed!"
echo "Installed Jenkins Version: ${INSTALLED_JENKINS_VERSION}"
echo "Installation Duration: ${MINUTES}m ${SECONDS}s ${MILLISECONDS}ms"
echo "========================================"

# ==========================================
# Jenkins Initial Admin Password
# ==========================================

echo "Jenkins initial admin password:"

if [[ -f /var/lib/jenkins/secrets/initialAdminPassword ]]; then
    cat /var/lib/jenkins/secrets/initialAdminPassword
else
    echo "Initial admin password is not available yet."
    echo "Check /var/lib/jenkins/secrets/ after Jenkins initialization."
fi

echo "========================================"
echo "Jenkins installation completed successfully."
echo "========================================"
