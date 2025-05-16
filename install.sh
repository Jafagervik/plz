#!/bin/sh

set -e

GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo "${BLUE}Installing plz...${NC}"

# Detect system architecture
ARCH=$(uname -m)
if [ "$ARCH" = "x86_64" ]; then
    ARCH="x86_64"
elif [ "$ARCH" = "arm64" ] || [ "$ARCH" = "aarch64" ]; then
    ARCH="aarch64"
else
    echo "Unsupported architecture: $ARCH"
    exit 1
fi

# Detect OS
OS=$(uname -s)
if [ "$OS" = "Darwin" ]; then
    OS="macos"
elif [ "$OS" = "Linux" ]; then
    OS="linux"
else
    echo "Unsupported OS: $OS"
    exit 1
fi

TEMP_DIR=$(mktemp -d)
trap 'rm -rf "$TEMP_DIR"' EXIT

# GitHub repo information
REPO="Jafagervik/plz"
VERSION="latest" #

# Get latest release if version is "latest"
if [ "$VERSION" = "latest" ]; then
    RELEASE_URL="https://api.github.com/repos/$REPO/releases/latest"
    VERSION=$(curl -s $RELEASE_URL | grep -o '"tag_name": "[^"]*' | cut -d'"' -f4)
fi

echo "Downloading version $VERSION for $OS-$ARCH..."

DOWNLOAD_URL="https://github.com/$REPO/releases/download/$VERSION/plz-$OS-$ARCH.tar.gz"

curl -sL "$DOWNLOAD_URL" -o "$TEMP_DIR/plz.tar.gz"
mkdir -p "$TEMP_DIR/extract"
tar -xzf "$TEMP_DIR/plz.tar.gz" -C "$TEMP_DIR/extract"

# Install location
INSTALL_DIR="/usr/local/bin"
if [ ! -w "$INSTALL_DIR" ]; then
    INSTALL_DIR="$HOME/.local/bin"
    mkdir -p "$INSTALL_DIR"
fi

# Move executable to install location
if [ -f "$TEMP_DIR/extract/plz" ]; then
    cp "$TEMP_DIR/extract/plz " "$INSTALL_DIR/"
    chmod +x "$INSTALL_DIR/plz"
else
    echo "Could not find the executable in the downloaded archive."
    exit 1
fi

echo "${GREEN}Installation complete!${NC}"

if ! command -v your-tool >/dev/null; then
    case $SHELL in
    */zsh)
        PROFILE="$HOME/.zshrc"
        ;;
    */bash)
        PROFILE="$HOME/.bashrc"
        [ "$(uname -s)" = "Darwin" ] && PROFILE="$HOME/.bash_profile"
        ;;
    *)
        PROFILE="$HOME/.profile"
        ;;
    esac

    if [ "$INSTALL_DIR" != "/usr/local/bin" ]; then
        echo "${BLUE}Adding $INSTALL_DIR to your PATH...${NC}"
        echo "export PATH=\"\$PATH:$INSTALL_DIR\"" >>"$PROFILE"
        echo "${GREEN}Added $INSTALL_DIR to PATH in $PROFILE${NC}"
        echo "Please restart your terminal or run 'source $PROFILE' to use plz."
    fi
fi

echo "${GREEN}plz is now installed and ready to use!${NC}"
