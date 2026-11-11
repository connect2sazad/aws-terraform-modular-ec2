
#!/bin/bash
set -euxo pipefail

# ==========================================
# Java Version Configuration
# ==========================================

JAVA_VERSION="${PLUGIN_VERSION:-}"

# Set timezone to GMT/UTC for logging
export TZ=UTC

# Log directory
LOG_DIR="/home/ubuntu/aws-terraform-modular-ec2/logs"
mkdir -p "$LOG_DIR"

# Log all output with GMT timestamps
exec > >(while IFS= read -r line; do
    echo "[$(date '+%Y-%m-%d %H:%M:%S GMT')] $line"
done | tee -a "$LOG_DIR/java-install.log") 2>&1

# Record installation start time
START_TIME=$(date +%s%3N)

echo "========================================"
echo "Starting Java installation..."
echo "========================================"

if [[ -n "$JAVA_VERSION" ]]; then
    echo "Requested Java version: ${JAVA_VERSION}"
else
    echo "Java version not specified. Installing latest available OpenJDK."
fi

# ==========================================
# Update Package Lists
# ==========================================

apt-get update -y

# ==========================================
# Determine Java Version
# ==========================================

if [[ -n "$JAVA_VERSION" ]]; then

    JAVA_PACKAGE="openjdk-${JAVA_VERSION}-jdk"

    echo "Installing requested Java package: ${JAVA_PACKAGE}"

    if ! apt-cache show "$JAVA_PACKAGE" >/dev/null 2>&1; then
        echo "ERROR: Java version ${JAVA_VERSION} is not available."
        echo "Available OpenJDK packages:"
        apt-cache search '^openjdk-[0-9]+-jdk$'
        exit 1
    fi

else

    echo "Detecting latest available OpenJDK version..."

    JAVA_PACKAGE=$(
        apt-cache search --names-only '^openjdk-[0-9]+-jdk$' |
        awk '{print $1}' |
        sort -V |
        tail -n 1
    )

    if [[ -z "$JAVA_PACKAGE" ]]; then
        echo "ERROR: No OpenJDK JDK package found."
        exit 1
    fi

fi

echo "Selected Java package: ${JAVA_PACKAGE}"

# ==========================================
# Install Java JDK
# ==========================================

apt-get install -y "$JAVA_PACKAGE"

# ==========================================
# Configure JAVA_HOME
# ==========================================

JAVA_PATH=$(readlink -f "$(command -v javac)")
JAVA_HOME_PATH="${JAVA_PATH%/bin/javac}"

echo "Detected JAVA_HOME: ${JAVA_HOME_PATH}"

cat > /etc/profile.d/java.sh <<EOF
export JAVA_HOME="${JAVA_HOME_PATH}"
export PATH="\$JAVA_HOME/bin:\$PATH"
EOF

export JAVA_HOME="$JAVA_HOME_PATH"
export PATH="$JAVA_HOME/bin:$PATH"

# ==========================================
# Verify Java Installation
# ==========================================

echo "========================================"
echo "Verifying Java installation..."
echo "========================================"

java -version
javac -version

INSTALLED_JAVA_VERSION=$(
    java -version 2>&1 |
    awk -F '"' '/version/ {print $2; exit}' |
    sed -E 's/^1\.//; s/^([0-9]+).*/\1/'
)

INSTALLED_JAVAC_VERSION=$(
    javac -version 2>&1 |
    awk '{print $2}' |
    sed -E 's/^1\.//; s/^([0-9]+).*/\1/'
)

echo "Requested Java version: ${JAVA_VERSION:-latest}"
echo "Installed Java version: ${INSTALLED_JAVA_VERSION}"
echo "Installed Javac version: ${INSTALLED_JAVAC_VERSION}"
echo "JAVA_HOME: ${JAVA_HOME}"

# Verify requested version
if [[ -n "$JAVA_VERSION" ]]; then

    if [[ "$INSTALLED_JAVA_VERSION" != "$JAVA_VERSION" ]]; then
        echo "ERROR: Java version mismatch!"
        echo "Expected: ${JAVA_VERSION}"
        echo "Installed: ${INSTALLED_JAVA_VERSION}"
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
echo "Java installation successfully completed!"
echo "Installed Java Version: ${INSTALLED_JAVA_VERSION}"
echo "JAVA_HOME: ${JAVA_HOME}"
echo "Installation Duration: ${MINUTES}m ${SECONDS}s ${MILLISECONDS}ms"
echo "========================================"

echo "Java installation completed successfully."
