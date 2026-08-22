#!/usr/bin/env bash
#
# install.sh - Install M-Vave Cube Suite on Linux via Wine
#
# Cube Suite is the Windows editor for the M-Vave Cube Baby multi-effects
# pedal. M-Vave doesn't ship a native Linux build, but Cube Suite is a
# plain portable Win32 app (no installer, just an .exe plus a handful of
# DLLs), and it runs fine under Wine.
#
# This script:
#   1. Installs Wine (32-bit) and unzip via apt, if they aren't already
#      present.
#   2. Creates a dedicated Wine prefix just for Cube Suite, so it doesn't
#      interfere with any other Wine setup you may already have.
#   3. Extracts CubeSuite.zip and creates an application-menu shortcut,
#      using Cube Suite's own icon (extracted from its .exe) when possible.
#
# It's idempotent: safe to re-run any time, e.g. after dropping in a newer
# CubeSuite.zip.
#
# ---------------------------------------------------------------------------
# HOW TO USE
# ---------------------------------------------------------------------------
#   1) Download "CubeSuite.zip" yourself from the official M-Vave site:
#        https://www.m-vave.com/download
#      (under the Cube Baby section). This repo does NOT bundle the
#      software itself - only the automation to install it.
#   2) Place CubeSuite.zip in this same folder, next to this script.
#   3) Run:
#        chmod +x install.sh
#        ./install.sh
#   4) To remove everything this script created:
#        ./install.sh --uninstall
#
# ---------------------------------------------------------------------------
# COMPATIBILITY
# ---------------------------------------------------------------------------
# Tested on Pop!_OS / Ubuntu 24.04 (noble). Should work unmodified on any
# apt-based Ubuntu/Debian derivative (Mint, Kubuntu, etc). On other package
# managers you'll need to install "wine" (32-bit support) and "unzip"
# yourself first, then run this script with SKIP_DEPS=1 (see below).
#
# ---------------------------------------------------------------------------
# DISCLAIMER
# ---------------------------------------------------------------------------
# This project is NOT affiliated with, endorsed by, or supported by M-Vave.
# Cube Suite is proprietary software (c) M-Vave - this script only
# automates installing the official build under Wine; it neither includes
# nor redistributes the software itself. Use at your own risk.
#
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

WINEPREFIX_DEFAULT="$HOME/.local/share/wineprefixes/cubesuite"
export WINEPREFIX="${WINEPREFIX:-$WINEPREFIX_DEFAULT}"
export WINEARCH="win32"   # Cube Suite is a 32-bit app - a 32-bit-only prefix
                          # is smaller and needs no wine64/WoW64 setup at all.

APP_DIR="$WINEPREFIX/drive_c/CubeSuite"
DESKTOP_DIR="$HOME/.local/share/applications"
DESKTOP_FILE="$DESKTOP_DIR/mvave-cubesuite.desktop"
ICON_DIR="$HOME/.local/share/icons/hicolor/128x128/apps"
ICON_FILE="$ICON_DIR/mvave-cubesuite.png"

SKIP_DEPS="${SKIP_DEPS:-0}"
FOUND_EXE=""

log()  { printf '\033[1;32m[cubesuite]\033[0m %s\n' "$*"; }
warn() { printf '\033[1;33m[cubesuite]\033[0m %s\n' "$*" >&2; }
err()  { printf '\033[1;31m[cubesuite]\033[0m %s\n' "$*" >&2; }

find_zip() {
  find "$SCRIPT_DIR" -maxdepth 1 -iname 'CubeSuite*.zip' -type f -print0 \
    | xargs -0r ls -t 2>/dev/null | head -n1 || true
}

install_dependencies() {
  if [ "$SKIP_DEPS" -eq 1 ]; then
    log "SKIP_DEPS=1 set - not touching system packages."
    return
  fi

  if command -v wine >/dev/null 2>&1 && command -v unzip >/dev/null 2>&1; then
    log "Wine and unzip are already installed - skipping package install."
    return
  fi

  if ! command -v apt-get >/dev/null 2>&1; then
    err "This script only automates apt-based systems (Ubuntu/Debian/Pop!_OS/Mint/...)."
    err "Install 'wine' (with 32-bit support) and 'unzip' yourself, then re-run with SKIP_DEPS=1."
    exit 1
  fi

  log "Installing wine and unzip (this may ask for your sudo password)..."
  sudo dpkg --add-architecture i386
  sudo apt-get update \
    || warn "apt-get update reported errors in some repository; continuing anyway."
  sudo apt-get install -y wine wine32:i386 unzip \
    || { err "Failed to install wine/unzip. Check your connection or apt repositories."; exit 1; }

  command -v wine  >/dev/null 2>&1 || { err "wine did not become available after installation."; exit 1; }
  command -v unzip >/dev/null 2>&1 || { err "unzip did not become available after installation."; exit 1; }

  # icoutils + imagemagick let us extract Cube Suite's real icon for the menu
  # shortcut. Best-effort only: if this fails, the shortcut still works, just
  # with a generic Wine icon instead of Cube Suite's own.
  if ! command -v wrestool >/dev/null 2>&1 || ! command -v icotool >/dev/null 2>&1 \
     || ! command -v convert >/dev/null 2>&1; then
    sudo apt-get install -y icoutils imagemagick \
      || warn "Could not install icoutils/imagemagick - the shortcut will use a generic icon."
  fi
}

setup_prefix() {
  if [ ! -d "$WINEPREFIX" ]; then
    log "Creating a dedicated Wine prefix at $WINEPREFIX ..."
  else
    log "Reusing existing Wine prefix at $WINEPREFIX ..."
  fi

  mkdir -p "$(dirname "$WINEPREFIX")"

  if ! wineboot --init >/tmp/cubesuite-wineboot.log 2>&1; then
    err "Failed to initialize the Wine prefix. Details:"
    sed 's/^/    /' /tmp/cubesuite-wineboot.log >&2
    exit 1
  fi
  wineserver -w
}

extract_app() {
  local zip_path
  zip_path="$(find_zip)"

  if [ -z "$zip_path" ]; then
    err "Could not find a CubeSuite*.zip file in: $SCRIPT_DIR"
    err "Download it from https://www.m-vave.com/download and place it next to this script."
    exit 1
  fi

  log "Extracting $(basename "$zip_path")..."
  rm -rf "$APP_DIR"
  mkdir -p "$APP_DIR"
  unzip -o -q "$zip_path" -d "$APP_DIR"

  FOUND_EXE="$(find "$APP_DIR" -iname 'CubeSuite.exe' -type f | head -n1 || true)"
  if [ -z "$FOUND_EXE" ]; then
    err "Could not find CubeSuite.exe inside $(basename "$zip_path")."
    err "Is this really the official CubeSuite.zip from m-vave.com?"
    exit 1
  fi
}

extract_icon() {
  if ! command -v wrestool >/dev/null 2>&1 || ! command -v icotool >/dev/null 2>&1 \
     || ! command -v convert >/dev/null 2>&1; then
    return 1
  fi

  mkdir -p "$ICON_DIR"
  local tmp_dir tmp_ico biggest
  tmp_dir="$(mktemp -d)"
  tmp_ico="$tmp_dir/icon.ico"

  # The .ico embedded in the .exe usually bundles several resolutions;
  # wrestool pulls out the icon group and icotool splits each resolution
  # into its own .png (convert can't take a multi-resolution .ico directly
  # without producing several numbered output files).
  if ! wrestool -x --output="$tmp_ico" -t14 "$FOUND_EXE" >/dev/null 2>&1; then
    rm -rf "$tmp_dir"; return 1
  fi
  if ! icotool -x -o "$tmp_dir" "$tmp_ico" >/dev/null 2>&1; then
    rm -rf "$tmp_dir"; return 1
  fi

  # Keep the largest PNG produced (in practice, the highest resolution).
  biggest="$(ls -S "$tmp_dir"/*.png 2>/dev/null | head -n1 || true)"
  if [ -z "$biggest" ]; then
    rm -rf "$tmp_dir"; return 1
  fi

  if convert "$biggest" -resize 128x128 "$ICON_FILE" >/dev/null 2>&1; then
    rm -rf "$tmp_dir"
    return 0
  fi

  rm -rf "$tmp_dir"
  return 1
}

create_launcher() {
  local icon="wine"
  if extract_icon; then
    icon="$ICON_FILE"
    log "Extracted Cube Suite's own icon."
  else
    warn "Could not extract Cube Suite's icon - the shortcut will use a generic Wine icon."
  fi

  mkdir -p "$DESKTOP_DIR"
  cat > "$DESKTOP_FILE" <<EOF
[Desktop Entry]
Type=Application
Name=M-Vave Cube Suite
Comment=M-Vave Cube Suite (via Wine)
Exec=env WINEPREFIX="$WINEPREFIX" wine "$FOUND_EXE"
Path=$(dirname "$FOUND_EXE")
Icon=$icon
Terminal=false
StartupNotify=true
Categories=AudioVideo;Audio;Music;
EOF
  chmod +x "$DESKTOP_FILE"
  log "Desktop shortcut created: $DESKTOP_FILE"

  command -v update-desktop-database >/dev/null 2>&1 \
    && update-desktop-database "$DESKTOP_DIR" >/dev/null 2>&1 || true
  command -v gtk-update-icon-cache >/dev/null 2>&1 \
    && gtk-update-icon-cache -q -t -f "$HOME/.local/share/icons/hicolor" >/dev/null 2>&1 || true
}

uninstall() {
  log "Removing desktop shortcut and icon..."
  rm -f "$DESKTOP_FILE"
  rm -f "$ICON_FILE"

  if [ -d "$WINEPREFIX" ]; then
    log "Removing Wine prefix at $WINEPREFIX ..."
    rm -rf "$WINEPREFIX"
  fi

  command -v update-desktop-database >/dev/null 2>&1 \
    && update-desktop-database "$DESKTOP_DIR" >/dev/null 2>&1 || true

  log "Done. Wine itself (the apt packages) was left installed on your system -"
  log "remove it manually with your package manager if you don't need it for anything else."
}

main() {
  if [ "${1:-}" = "--uninstall" ]; then
    uninstall
    exit 0
  fi

  install_dependencies
  setup_prefix
  extract_app
  create_launcher

  echo
  log "Installation complete! Look for 'M-Vave Cube Suite' in your application menu, or run:"
  echo "    WINEPREFIX=\"$WINEPREFIX\" wine \"$FOUND_EXE\""
  echo
  log "Re-run this script any time to reinstall/update (e.g. after replacing CubeSuite.zip)."
  log "To remove everything this script created: ./install.sh --uninstall"
}

main "$@"
