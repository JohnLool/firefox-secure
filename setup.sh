#!/bin/bash
#
# setup.sh — one-time setup for firefox-secure.sh
#

set -e

VAULT="$HOME/browser_closed"
MOUNT_POINT="$HOME/browser_opened"
FIREFOX_DIR="$HOME/.config/mozilla/firefox"
BACKUP_DIR="$HOME/firefox_profile_backup"

echo ""
echo "=== firefox-secure setup ==="
echo ""

# Check dependencies
echo "[1/6] Checking dependencies..."
MISSING=()
for cmd in gocryptfs fusermount firefox zenity lsof; do
    if ! command -v "$cmd" &>/dev/null; then
        MISSING+=("$cmd")
    fi
done

if [ ${#MISSING[@]} -ne 0 ]; then
    echo "Missing dependencies: ${MISSING[*]}"
    echo "Install them and re-run setup.sh"
    exit 1
fi
echo "     All dependencies found."

# Find profile
echo ""
echo "[2/6] Available Firefox profiles:"
ls "$FIREFOX_DIR" | grep -E '\.default(-release)?$' || true
echo ""
echo "     Not sure which one is your main profile?"
echo "     Open Firefox and go to: about:profiles"
echo "     Your main profile is marked as 'This is the profile in use' or 'Default Profile'."
echo ""
read -p "     Enter your profile name (e.g. uwk1dhs9.default-release): " PROFILE_NAME

if [ -z "$PROFILE_NAME" ]; then
    echo "Profile name cannot be empty."
    exit 1
fi

if [ ! -d "$FIREFOX_DIR/$PROFILE_NAME" ]; then
    echo "Profile not found: $FIREFOX_DIR/$PROFILE_NAME"
    exit 1
fi

# Backup profile
echo ""
echo "[3/6] Backing up profile..."
echo ""
echo "     A backup of your profile will be created at:"
echo "     $BACKUP_DIR"
echo ""
echo "     IMPORTANT: Verify everything works correctly before deleting it."
echo "     Delete it manually when you're confident:"
echo "     rm -rf $BACKUP_DIR"
echo ""
read -p "     Create backup? (yes/no): " DO_BACKUP
if [ "$DO_BACKUP" = "yes" ]; then
    mkdir -p "$BACKUP_DIR"
    cp -a "$FIREFOX_DIR/$PROFILE_NAME" "$BACKUP_DIR/$(basename "$PROFILE_NAME")"
    echo "     Backup created at $BACKUP_DIR"
else
    echo "     Skipping backup. Proceed at your own risk."
fi

# Init vault
echo ""
echo "[4/6] Initializing encrypted vault at $VAULT..."
if [ -f "$VAULT/gocryptfs.conf" ]; then
    echo "     Vault already exists, skipping init."
else
    mkdir -p "$VAULT"
    echo ""
    echo "     ┌──────────────────────────────────────────────────────────────┐"
    echo "     │  IMPORTANT: gocryptfs will now display a master key.         │"
    echo "     │  Copy it and store it somewhere safe — password manager,     │"
    echo "     │  printed paper, etc.                                         │"
    echo "     │  It is the ONLY recovery option if you forget your password. │"
    echo "     │  Your profile CANNOT be recovered without it.                │"
    echo "     └──────────────────────────────────────────────────────────────┘"
    echo ""
    gocryptfs -init "$VAULT"
    echo ""
    read -p "     Have you saved the master key? (yes/no): " SAVED
    if [ "$SAVED" != "yes" ]; then
        echo ""
        echo "     Please save the master key before continuing."
        echo "     WARNING: The master key is shown only once and cannot be retrieved later."
        echo "     If you did not save it, re-run setup.sh to re-initialize (all data will be lost)."
        read -p "     Press Enter when ready..."
    fi
fi

# Mount vault
echo ""
echo "[5/6] Mounting vault..."
mkdir -p "$MOUNT_POINT"
gocryptfs "$VAULT" "$MOUNT_POINT"

# Move profile
echo ""
echo "[6/6] Moving profile into vault..."
if [ -d "$MOUNT_POINT/$PROFILE_NAME" ]; then
    echo "     Profile already in vault, skipping move."
else
    mv "$FIREFOX_DIR/$PROFILE_NAME" "$MOUNT_POINT/"
    echo "     Profile moved."
fi

# Unmount
fusermount -u "$MOUNT_POINT"
echo "     Vault unmounted."

# Patch PROFILE_NAME into firefox-secure.sh
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
SCRIPT="$SCRIPT_DIR/firefox-secure.sh"

if [ -f "$SCRIPT" ]; then
    sed -i "s/^PROFILE_NAME=\"\"/PROFILE_NAME=\"$PROFILE_NAME\"/" "$SCRIPT"
    chmod +x "$SCRIPT"
    echo ""
    echo "     PROFILE_NAME set in firefox-secure.sh automatically."
fi


# Replace Firefox desktop launcher
BIN_LINK="$HOME/.local/bin/firefox-secure"
DESKTOP_SRC="/usr/share/applications/firefox.desktop"
DESKTOP_DST="$HOME/.local/share/applications/firefox.desktop"

echo ""
read -p "Replace Firefox desktop launcher to use firefox-secure? (yes/no): " DO_DESKTOP
if [ "$DO_DESKTOP" = "yes" ]; then
    if [ ! -f "$DESKTOP_SRC" ]; then
        echo "     firefox.desktop not found at $DESKTOP_SRC, skipping."
    else
        mkdir -p "$HOME/.local/share/applications"
        cp "$DESKTOP_SRC" "$DESKTOP_DST"
        # Replace Exec= lines, preserve any arguments like %u
        sed -i -E "s|^Exec=(/usr(/local)?/bin/)?firefox([[:space:]]*.*)$|Exec=$BIN_LINK\3|g" "$DESKTOP_DST"
        # Update desktop database
        if command -v update-desktop-database &>/dev/null; then
            update-desktop-database "$HOME/.local/share/applications"
        fi
        echo "     Desktop launcher updated: $DESKTOP_DST"
    fi
else
    echo "     Skipping. You can do it manually — see README."
fi

echo ""
echo "=== Setup complete ==="
echo ""
echo "Run firefox-secure.sh instead of Firefox from now on."
echo ""
echo "When you've verified everything works correctly, delete the backup:"
echo "  rm -rf $BACKUP_DIR"
echo ""
