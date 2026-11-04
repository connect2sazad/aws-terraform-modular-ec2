
#!/bin/bash
set -euxo pipefail

# ==========================================
# Go Version Configuration
# ==========================================

GO_VERSION="${PLUGIN_VERSION:-}"

# Set timezone to GMT/UTC for logging
export TZ=UTC

# Log directory
LOG_DIR="/home/ubuntu/aws-terraform-modular-ec2/logs"
mkdir -p "$LOG_DIR"

# Log all output with GMT timestamps
exec > >(while IFS= read -r line; do
    echo "[$(date '+%Y-%m-%d %H:%M:%S GMT')] $line"
done | tee -a "$LOG_DIR/go-install.log") 2>&1

# Record installation start time
START_TIME=$(date +%s%3N)

echo "========================================"
echo "Starting GoLang installation..."
echo "========================================"

if [[ -n "$GO_VERSION" ]]; then
    echo "Requested Go version: ${GO_VERSION}"
else
    echo "Go version not specified. Installing latest stable version."
fi

# ==========================================
# Install Required Packages
# ==========================================

apt-get update -y

apt-get install -y \
    curl \
    ca-certificates

# ==========================================
# Detect System Architecture
# ==========================================

ARCH=$(uname -m)

case "$ARCH" in
    x86_64)
        GO_ARCH="amd64"
        ;;
    aarch64)
        GO_ARCH="arm64"
        ;;
    *)
        echo "ERROR: Unsupported architecture: $ARCH"
        exit 1
        ;;
esac

echo "Detected architecture: ${GO_ARCH}"

# ==========================================
# Determine Go Version
# ==========================================

if [[ -z "$GO_VERSION" ]]; then

    echo "Fetching latest stable Go version..."

    GO_VERSION=$(
        curl -fsSL https://go.dev/VERSION?m=text |
        head -n 1 |
        sed 's/^go//'
    )

fi

# Remove optional go prefix
GO_VERSION="${GO_VERSION#go}"

echo "Installing Go version: ${GO_VERSION}"

# ==========================================
# Download Go Binary
# ==========================================

TMP_DIR=$(mktemp -d)
trap 'rm -rf "$TMP_DIR"' EXIT

GO_TARBALL="go${GO_VERSION}.linux-${GO_ARCH}.tar.gz"

DOWNLOAD_URL="https://go.dev/dl/${GO_TARBALL}"

echo "Downloading: ${DOWNLOAD_URL}"

curl -fsSL \
    --retry 3 \
    --retry-delay 2 \
    "$DOWNLOAD_URL" \
    -o "$TMP_DIR/$GO_TARBALL"

# ==========================================
# Remove Existing Go Installation
# ==========================================

if [[ -d /usr/local/go ]]; then

    echo "Removing existing Go installation..."

    rm -rf /usr/local/go

fi

# ==========================================
# Install Go
# ==========================================

tar -C /usr/local -xzf "$TMP_DIR/$GO_TARBALL"

# Configure Go PATH
cat > /etc/profile.d/go.sh <<'EOF'
export PATH="/usr/local/go/bin:$PATH"
EOF

export PATH="/usr/local/go/bin:$PATH"

# ==========================================
# Verify Go Installation
# ==========================================

echo "========================================"
echo "Verifying Go installation..."
echo "========================================"

go version

INSTALLED_GO_VERSION=$(
    go version |
    awk '{print $3}' |
    sed 's/^go//'
)

echo "Requested Go version: ${GO_VERSION}"
echo "Installed Go version: ${INSTALLED_GO_VERSION}"

if [[ "$INSTALLED_GO_VERSION" != "$GO_VERSION" ]]; then
    echo "ERROR: Go version mismatch!"
    exit 1
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
echo "GoLang installation successfully completed!"
echo "Installed Version: ${INSTALLED_GO_VERSION}"
echo "Installation Duration: ${MINUTES}m ${SECONDS}s ${MILLISECONDS}ms"
echo "========================================"

echo "GoLang installation completed successfully."
