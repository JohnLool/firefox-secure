#!/bin/bash
#
# firefox-secure installer
# Usage: bash <(curl -fsSL https://raw.githubusercontent.com/yourusername/firefox-secure/main/install.sh)
#

set -e

REPO="https://raw.githubusercontent.com/yourusername/firefox-secure/main"
INSTALL_DIR="$HOME/.local/bin/firefox-secure"

echo ""
echo "=== firefox-secure installer ==="
echo ""

# --- Detect package manager ---

if command -v pacman &>/dev/null; then
    DISTRO="arch"
elif command -v apt &>/dev/null; then
    DISTRO="debian"
elif command -v dnf &>/dev/null; then
    DISTRO="fedora"
else
    echo "Unsupported package manager. Install dependencies manually:"
    echo "  gocryptfs, zenity, lsof, fuse"
    exit 1
fi

# --- Check and install dependencies ---

echo "[1/4] Checking dependencies..."

MISSING=()
for cmd in gocryptfs zenity lsof fusermount; do
    if ! command -v "$cmd" &>/dev/null; then
        MISSING+=("$cmd")
    fi
done

if [ ${#MISSING[@]} -ne 0 ]; then
    echo "     Missing: ${MISSING[*]}"
    echo "     Installing..."

    case "$DISTRO" in
        arch)
            # fusermount comes from fuse2 on Arch
            PKGS=()
            for dep in "${MISSING[@]}"; do
                [ "$dep" = "fusermount" ] && PKGS+=("fuse2") || PKGS+=("$dep")
            done
            sudo pacman -Sy --noconfirm "${PKGS[@]}"
            ;;

        debian)
            sudo apt update -qq
            # gocryptfs may not be in older Ubuntu repos — handle separately
            APT_PKGS=()
            NEED_GOCRYPTFS=false
            for dep in "${MISSING[@]}"; do
                if [ "$dep" = "gocryptfs" ]; then
                    NEED_GOCRYPTFS=true
                elif [ "$dep" = "fusermount" ]; then
                    APT_PKGS+=("fuse")
                else
                    APT_PKGS+=("$dep")
                fi
            done
            [ ${#APT_PKGS[@]} -ne 0 ] && sudo apt install -y "${APT_PKGS[@]}"
            if $NEED_GOCRYPTFS; then
                sudo apt install -y gocryptfs 2>/dev/null || _install_gocryptfs_binary
            fi
            ;;

        fedora)
            PKGS=()
            for dep in "${MISSING[@]}"; do
                [ "$dep" = "fusermount" ] && PKGS+=("fuse") || PKGS+=("$dep")
            done
            sudo dnf install -y "${PKGS[@]}"
            ;;
    esac
else
    echo "     All dependencies already installed."
fi

# Verify fusermount available after install
if ! command -v fusermount &>/dev/null; then
    echo "fusermount not found after install. Try rebooting or loading the fuse module manually."
    exit 1
fi

# --- Download scripts ---

echo ""
echo "[2/4] Downloading scripts to $INSTALL_DIR..."
mkdir -p "$INSTALL_DIR"

curl -fsSL "$REPO/firefox-secure.sh" -o "$INSTALL_DIR/firefox-secure.sh"
curl -fsSL "$REPO/setup.sh"          -o "$INSTALL_DIR/setup.sh"

chmod +x "$INSTALL_DIR/firefox-secure.sh"
chmod +x "$INSTALL_DIR/setup.sh"

echo "     Done."

# --- PATH check ---

echo ""
echo "[3/4] Checking PATH..."
if [[ ":$PATH:" != *":$HOME/.local/bin:"* ]]; then
    echo "     Adding ~/.local/bin to PATH in ~/.bashrc"
    echo 'export PATH="$HOME/.local/bin:$PATH"' >> "$HOME/.bashrc"
    export PATH="$HOME/.local/bin:$PATH"
else
    echo "     PATH already includes ~/.local/bin"
fi

ln -sfn "$INSTALL_DIR/firefox-secure.sh" "$HOME/.local/bin/firefox-secure"

# --- Run setup ---

echo ""
echo "[4/4] Running setup..."
echo ""
bash "$INSTALL_DIR/setup.sh"

echo ""
echo "=== Installation complete ==="
echo ""
echo "Run from anywhere:  firefox-secure"
echo "Or directly:        $INSTALL_DIR/firefox-secure.sh"
echo ""

# --- Helpers ---

_install_gocryptfs_binary() {
    echo "     gocryptfs not found in apt, installing from GitHub releases..."
    local LATEST
    LATEST=$(curl -fsSL https://api.github.com/repos/rfjakob/gocryptfs/releases/latest \
        | grep "browser_download_url.*linux_amd64.tar.gz" \
        | cut -d '"' -f 4)
    if [ -z "$LATEST" ]; then
        echo "     Failed to find gocryptfs release. Install it manually: https://github.com/rfjakob/gocryptfs"
        exit 1
    fi
    curl -fsSL "$LATEST" | sudo tar -xz -C /usr/local/bin gocryptfs
    echo "     gocryptfs installed to /usr/local/bin"
}
