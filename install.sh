#!/bin/bash
# VulneraXSS Installer — Linux / macOS
# Usage: bash <(curl -fsSL https://store.krazeplanet.com/install.sh)

set -e

BINARY="VulneraXSS"
BASE_URL="https://store.krazeplanet.com/VulneraXSS/releasefiles"
VERSION_URL="https://store.krazeplanet.com/VulneraXSS/releasefiles/latest.txt"
INSTALL_DIR="/usr/local/bin"

# Colors
GREEN='\033[0;32m'
CYAN='\033[0;36m'
RED='\033[0;31m'
RESET='\033[0m'

info()  { echo -e "  ${CYAN}[*]${RESET} $1"; }
ok()    { echo -e "  ${GREEN}[✓]${RESET} $1"; }
fail()  { echo -e "  ${RED}[✗]${RESET} $1"; exit 1; }

# Detect OS
OS="$(uname -s | tr '[:upper:]' '[:lower:]')"
case "$OS" in
    linux)  OS="linux"  ;;
    darwin) OS="darwin" ;;
    *)      fail "Unsupported OS: $OS" ;;
esac

# Detect architecture
ARCH="$(uname -m)"
case "$ARCH" in
    x86_64|amd64)   ARCH="amd64" ;;
    i386|i686)       ARCH="386"   ;;
    *)               fail "Unsupported architecture: $ARCH" ;;
esac

# Get latest version
VERSION=$(curl -fsSL "$VERSION_URL" 2>/dev/null | tr -d '[:space:]')
if [ -z "$VERSION" ]; then
    fail "Could not determine latest version"
fi

echo ""
info "Downloading VulneraXSS v${VERSION} (${OS}/${ARCH})..."

# Download
FILENAME="${BINARY}-${OS}-${ARCH}-${VERSION}.tgz"
DOWNLOAD_URL="${BASE_URL}/${FILENAME}"
TMPDIR="$(mktemp -d)"
trap 'rm -rf "$TMPDIR"' EXIT

if ! curl -fsSL "$DOWNLOAD_URL" -o "${TMPDIR}/${FILENAME}"; then
    fail "Download failed"
fi

# Extract & install
cd "$TMPDIR"
tar xzf "$FILENAME"

BIN_PATH=$(find "$TMPDIR" -name "$BINARY" -type f -perm -u+x | head -1)
if [ -z "$BIN_PATH" ]; then
    BIN_PATH=$(find "$TMPDIR" -name "$BINARY" -type f | head -1)
fi
if [ -z "$BIN_PATH" ]; then
    fail "Binary not found in archive"
fi

chmod +x "$BIN_PATH"

if [ -w "$INSTALL_DIR" ]; then
    mv "$BIN_PATH" "${INSTALL_DIR}/${BINARY}"
else
    sudo mv "$BIN_PATH" "${INSTALL_DIR}/${BINARY}"
fi

ok "VulneraXSS v${VERSION} installed"

# Return to a safe directory (TMPDIR was deleted by trap)
cd /tmp 2>/dev/null || cd /

# ── Install dependencies (silent) ──
info "Setting up dependencies..."

DEP_FAIL=0

# Helper: install build tools if missing
install_build_deps() {
    if command -v cmake &>/dev/null && command -v make &>/dev/null && command -v g++ &>/dev/null; then
        return 0
    fi
    if [ "$OS" = "linux" ]; then
        if command -v apt-get &>/dev/null; then
            sudo apt-get update -qq >/dev/null 2>&1
            sudo apt-get install -y -qq cmake build-essential git >/dev/null 2>&1
        elif command -v yum &>/dev/null; then
            sudo yum install -y cmake make gcc-c++ git >/dev/null 2>&1
        elif command -v dnf &>/dev/null; then
            sudo dnf install -y cmake make gcc-c++ git >/dev/null 2>&1
        elif command -v pacman &>/dev/null; then
            sudo pacman -S --noconfirm cmake make gcc git >/dev/null 2>&1
        elif command -v apk &>/dev/null; then
            sudo apk add --no-cache cmake make g++ git >/dev/null 2>&1
        fi
    elif [ "$OS" = "darwin" ]; then
        if command -v brew &>/dev/null; then
            brew install cmake git >/dev/null 2>&1
        else
            xcode-select --install 2>/dev/null || true
        fi
    fi
}

# urldedupe
if ! command -v urldedupe &>/dev/null; then
    install_build_deps
    DEPDIR="$(mktemp -d)"
    git clone https://github.com/ameenmaali/urldedupe.git "$DEPDIR/urldedupe" --depth 1 --quiet 2>/dev/null
    cd "$DEPDIR/urldedupe"
    cmake CMakeLists.txt -DCMAKE_BUILD_TYPE=Release >/dev/null 2>&1
    make -j"$(nproc 2>/dev/null || echo 2)" >/dev/null 2>&1
    if [ -w "$INSTALL_DIR" ]; then
        mv urldedupe "$INSTALL_DIR/"
    else
        sudo mv urldedupe "$INSTALL_DIR/"
    fi
    rm -rf "$DEPDIR"
    cd /tmp 2>/dev/null || cd /
    command -v urldedupe &>/dev/null || DEP_FAIL=1
fi

# x8
if ! command -v x8 &>/dev/null; then
    DEPDIR="$(mktemp -d)"
    X8_VERSION="4.3.0"
    X8_DONE=0
    if [ "$OS" = "linux" ]; then
        curl -fsSL "https://github.com/Sh1Yo/x8/releases/download/v${X8_VERSION}/x86_64-linux-x8.gz" -o "$DEPDIR/x8.gz" 2>/dev/null
        gunzip "$DEPDIR/x8.gz" 2>/dev/null
        chmod +x "$DEPDIR/x8" 2>/dev/null
        if [ -f "$DEPDIR/x8" ]; then
            if [ -w "$INSTALL_DIR" ]; then
                mv "$DEPDIR/x8" "$INSTALL_DIR/"
            else
                sudo mv "$DEPDIR/x8" "$INSTALL_DIR/"
            fi
            X8_DONE=1
        fi
    elif [ "$OS" = "darwin" ]; then
        if ! command -v cargo &>/dev/null; then
            curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y >/dev/null 2>&1
            export PATH="$HOME/.cargo/bin:$PATH"
        fi
        cargo install x8 --version "$X8_VERSION" --quiet 2>/dev/null
        command -v x8 &>/dev/null && X8_DONE=1
    fi
    rm -rf "$DEPDIR" 2>/dev/null
    [ "$X8_DONE" = "0" ] && DEP_FAIL=1
fi

# cewl
if ! command -v cewl &>/dev/null; then
    if [ "$OS" = "linux" ]; then
        if command -v apt-get &>/dev/null; then
            sudo apt-get install -y -qq cewl >/dev/null 2>&1
        elif command -v yum &>/dev/null; then
            sudo yum install -y rubygem-nokogiri ruby-devel >/dev/null 2>&1
            sudo gem install cewl --no-document >/dev/null 2>&1
        elif command -v dnf &>/dev/null; then
            sudo dnf install -y rubygem-nokogiri ruby-devel >/dev/null 2>&1
            sudo gem install cewl --no-document >/dev/null 2>&1
        elif command -v pacman &>/dev/null; then
            sudo pacman -S --noconfirm ruby >/dev/null 2>&1
            sudo gem install cewl --no-document >/dev/null 2>&1
        elif command -v apk &>/dev/null; then
            sudo apk add --no-cache ruby ruby-dev build-base libffi-dev >/dev/null 2>&1
            sudo gem install cewl --no-document >/dev/null 2>&1
        fi
    elif [ "$OS" = "darwin" ]; then
        if command -v brew &>/dev/null; then
            brew install cewl >/dev/null 2>&1
        else
            gem install cewl --no-document >/dev/null 2>&1
        fi
    fi
    command -v cewl &>/dev/null || DEP_FAIL=1
fi

# Google Chrome / Chromium
if ! command -v google-chrome &>/dev/null && ! command -v google-chrome-stable &>/dev/null && ! command -v chromium-browser &>/dev/null && ! command -v chromium &>/dev/null; then
    if [ "$OS" = "linux" ]; then
        if command -v apt-get &>/dev/null; then
            if [ "$ARCH" = "amd64" ]; then
                DEPDIR="$(mktemp -d)"
                wget -q https://dl.google.com/linux/direct/google-chrome-stable_current_amd64.deb -O "$DEPDIR/chrome.deb" 2>/dev/null
                sudo dpkg -i "$DEPDIR/chrome.deb" >/dev/null 2>&1 || true
                sudo apt-get install -f -y -qq >/dev/null 2>&1
                rm -rf "$DEPDIR"
            else
                sudo apt-get update -qq >/dev/null 2>&1
                sudo apt-get install -y -qq chromium-browser >/dev/null 2>&1 || \
                sudo apt-get install -y -qq chromium >/dev/null 2>&1
            fi
        elif command -v yum &>/dev/null; then
            if [ "$ARCH" = "amd64" ]; then
                sudo yum install -y https://dl.google.com/linux/direct/google-chrome-stable_current_x86_64.rpm >/dev/null 2>&1
            else
                sudo yum install -y chromium >/dev/null 2>&1
            fi
        elif command -v dnf &>/dev/null; then
            if [ "$ARCH" = "amd64" ]; then
                sudo dnf install -y https://dl.google.com/linux/direct/google-chrome-stable_current_x86_64.rpm >/dev/null 2>&1
            else
                sudo dnf install -y chromium >/dev/null 2>&1
            fi
        elif command -v pacman &>/dev/null; then
            sudo pacman -S --noconfirm chromium >/dev/null 2>&1
        elif command -v apk &>/dev/null; then
            sudo apk add --no-cache chromium >/dev/null 2>&1
        fi
    elif [ "$OS" = "darwin" ]; then
        if command -v brew &>/dev/null; then
            brew install --cask google-chrome >/dev/null 2>&1
        fi
    fi
fi

if [ "$DEP_FAIL" = "0" ]; then
    ok "Dependencies ready"
else
    echo -e "  ${RED}[!]${RESET} Some dependencies could not be installed"
fi

echo ""
echo -e "  ${GREEN}VulneraXSS v${VERSION}${RESET} is ready. Run:"
echo -e "  ${CYAN}cat urls.txt | VulneraXSS --api-key YOUR_KEY${RESET}"
echo ""
