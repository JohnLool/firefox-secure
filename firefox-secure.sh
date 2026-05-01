#!/bin/bash
#
# firefox-secure.sh
# Encrypts your Firefox profile with gocryptfs and mounts it only during the session.
# https://github.com/yourusername/firefox-secure
#
# BEFORE USE
#
# 1. Find your Firefox profile name:
#       Open Firefox and go to: about:profiles
#       (or: ls "$HOME/.config/mozilla/firefox/")
#       Find the profile marked as default (root directory ending in .default-release)
#       Copy the directory name, e.g. "uwk1dhs9.default-release"
#       Set it as PROFILE_NAME below.
#
# 2. Run the setup script (recommended):
#       bash setup.sh
#
#    Or manually:
#       mkdir -p "$HOME/browser_opened"
#       gocryptfs -init "$HOME/browser_closed"
#       gocryptfs "$HOME/browser_closed" "$HOME/browser_opened"
#       mv "$HOME/.config/mozilla/firefox/YOUR_PROFILE_NAME" "$HOME/browser_opened/"
#       fusermount -u "$HOME/browser_opened"
#
# 3. Make this script executable:
#       chmod +x firefox-secure.sh
#
# Done. Run this script instead of Firefox from now on.
#

PROFILE_NAME=""                                            # <-- set your profile name here
VAULT="$HOME/browser_closed"
MOUNT_POINT="$HOME/browser_opened"
LINK_PATH="$HOME/.config/mozilla/firefox/$PROFILE_NAME"
UNMOUNT_TIMEOUT=30

# --- Sanity checks ---

if [ -z "$PROFILE_NAME" ]; then
    zenity --error --text="PROFILE_NAME is not set. Edit the script and set your profile name." --title="Error" 2>/dev/null
    exit 1
fi

if [ ! -f "$VAULT/gocryptfs.conf" ]; then
    zenity --error --text="Vault not found: $VAULT\nRun setup.sh first." --title="Error" 2>/dev/null
    exit 1
fi

# --- If vault already mounted, Firefox is running — just open new window ---

if mountpoint -q "$MOUNT_POINT"; then
    firefox --new-window
    exit 0
fi

if [ -d "$LINK_PATH" ] && [ ! -L "$LINK_PATH" ]; then
    zenity --error --text="$LINK_PATH is a real directory, not a symlink.\nMove your profile into the vault manually." --title="Error" 2>/dev/null
    exit 1
fi

# --- Setup ---

MOUNTED=false
PASS_FILE=$(mktemp)
chmod 600 "$PASS_FILE"

trap '
    rm -f "$PASS_FILE"
    if $MOUNTED; then
        fusermount -u "$MOUNT_POINT" 2>/dev/null
        echo "Vault unmounted."
    fi
' EXIT INT TERM

mkdir -p "$MOUNT_POINT"

# --- Unlock ---

while true; do
    zenity --password --title="Unlock Firefox Vault" 2>/dev/null > "$PASS_FILE"
    if [ $? -ne 0 ]; then
        echo "Cancelled"
        exit 0
    fi

    gocryptfs -extpass "cat $PASS_FILE" "$VAULT" "$MOUNT_POINT"
    GC_EXIT=$?

    if [ $GC_EXIT -eq 0 ]; then
        MOUNTED=true
        echo "Success"
        break
    else
        zenity --error --text="Wrong password! Try again." --title="Error" 2>/dev/null
    fi
done

# --- Symlink ---

ln -sfn "$MOUNT_POINT/$PROFILE_NAME" "$LINK_PATH"

# --- Launch ---

firefox --no-remote

# --- Wait for Firefox to release mount, then clean up ---

ELAPSED=0
while lsof "$MOUNT_POINT" >/dev/null 2>&1; do
    sleep 1
    ELAPSED=$((ELAPSED + 1))
    if [ $ELAPSED -ge $UNMOUNT_TIMEOUT ]; then
        echo "Timeout waiting for mount release, forcing unmount"
        break
    fi
done

rm -rf "$HOME/.cache/mozilla/firefox/$PROFILE_NAME"/*
echo "Browser session closed"
