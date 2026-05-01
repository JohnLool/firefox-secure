# firefox-secure

Encrypts your Firefox profile with [gocryptfs](https://github.com/rfjakob/gocryptfs) and mounts it only for the duration of the browser session. When Firefox closes, the vault is unmounted and the profile is inaccessible on disk.

Protects against infostealers and other malware that reads from disk while the browser is not running.

---

## Install

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/JohnLool/firefox-secure/main/install.sh)
```

Detects your distro, installs dependencies, downloads scripts, and runs interactive setup. 
Supported: Arch, Debian/Ubuntu, Fedora.

---

## How it works

```
~/browser_closed/   ← encrypted vault (always on disk)
~/browser_opened/   ← decrypted mount (exists only during session)
~/.config/mozilla/firefox/YOUR_PROFILE/ ← symlink → browser_opened/
```

On launch: password prompt → vault mounts → symlink created → Firefox starts.  
On close: vault unmounts → symlink points to nothing → profile inaccessible.

---

## ⚠️ Warning: forgotten password

If you forget your vault password, **your Firefox profile will be permanently inaccessible** — all sessions, history, bookmarks, saved passwords, and cookies will be lost.

gocryptfs generates a **master key** during vault initialization. It is the only recovery option if you forget your password. **Copy it and store it somewhere safe** — a password manager, printed paper in a secure location, etc.

The setup script will pause after vault initialization and prompt you to confirm you have saved the key before continuing.

---

## What it protects against

| Threat | Protected |
|---|---|
| Infostealers reading profile from disk (browser closed) | ✓ |
| Physical access to unlocked machine (browser closed) | ✓ |
| Memory dump while browser is running | ✗ |
| Keylogger capturing vault password | ✗ |
| Root-level malware | ✗ |

---

## Usage

Run `firefox-secure` instead of Firefox. Opening a new window while Firefox is already running works normally — the script detects the mounted vault and calls `firefox --new-window` directly.

### Replace the Firefox desktop launcher

To make your app launcher, taskbar, and `xdg-open` use the script instead of Firefox:

```bash
mkdir -p ~/.local/share/applications
cp /usr/share/applications/firefox.desktop ~/.local/share/applications/
```

Edit `~/.local/share/applications/firefox.desktop` and replace the `Exec=` lines:

```ini
[Desktop Entry]
Exec=/home/YOUR_NAME/.local/bin/firefox-secure %U

[Desktop Action new-window]
Exec=/home/YOUR_NAME/.local/bin/firefox-secure --new-window %U

[Desktop Action new-private-window]
Exec=/home/YOUR_NAME/.local/bin/firefox-secure --private-window %U
```

> Private window is launched directly via Firefox since the vault is already mounted at that point.

Then update the desktop database:

```bash
update-desktop-database ~/.local/share/applications
```

---

## Manual setup

<details>
<summary>Expand if you prefer to set things up manually</summary>

### Dependencies

| Package | Purpose |
|---|---|
| `gocryptfs` | FUSE-based file encryption |
| `firefox` | Browser |
| `zenity` | GUI password prompt |
| `lsof` | Wait for Firefox to release mount |
| `fuse2` | Required by gocryptfs |

**Arch:**
```bash
sudo pacman -S gocryptfs firefox zenity lsof fuse2
```

**Debian/Ubuntu:**
```bash
sudo apt install gocryptfs firefox zenity lsof fuse
```

**Fedora:**
```bash
sudo dnf install gocryptfs firefox zenity lsof fuse
```

### Steps

**1. Find your profile name**

Open Firefox and go to `about:profiles`. Copy the root directory name of your default profile (ends in `.default-release`).

**2. Back up your profile**

```bash
cp -r ~/.config/mozilla/firefox/YOUR_PROFILE_NAME ~/firefox_profile_backup
```

> **Important:** Keep this backup until you have verified the encrypted setup works correctly. Delete it when confident:
> ```bash
> rm -rf ~/firefox_profile_backup
> ```

**3. Initialize the vault**

```bash
mkdir -p ~/browser_opened
gocryptfs -init ~/browser_closed
```

gocryptfs will display a master key — copy it and store it somewhere safe. It is the only way to recover your profile if you forget your password.

**4. Mount temporarily and move your profile**

```bash
gocryptfs ~/browser_closed ~/browser_opened
mv ~/.config/mozilla/firefox/YOUR_PROFILE_NAME ~/browser_opened/
fusermount -u ~/browser_opened
```

**5. Set your profile name in the script**

Edit `firefox-secure.sh` and set:
```bash
PROFILE_NAME="YOUR_PROFILE_NAME"
```

**6. Make executable**

```bash
chmod +x firefox-secure.sh
```

</details>

---

## Notes

- Performance overhead is negligible on CPUs with AES-NI (virtually all x86 CPUs since ~2010)
- Browser cache is cleared on session close (`~/.cache/mozilla/firefox/PROFILE/`)

---

## License

MIT
