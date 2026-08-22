# M-Vave Cube Suite (via Wine)

`install.sh` installs **Cube Suite** — the Windows editor for the M-Vave
**Cube Baby** multi-effects pedal — on Linux, running it under
[Wine](https://www.winehq.org/). M-Vave doesn't ship a native Linux build,
but Cube Suite turns out to be a plain portable 32-bit Windows app (no
installer, just an `.exe` plus a few DLLs), and it runs well under Wine
as-is — no patches or workarounds needed.

This is the simplest, standalone version of the installer: it only handles
Cube Suite, and it's meant to work out of the box on any Ubuntu-family
Linux distribution.

## What the script does

1. Installs `wine` (32-bit) and `unzip` via `apt`, if they aren't already
   present on your system. Also installs `icoutils`/`imagemagick`
   (best-effort, used only for the menu icon in step 3).
2. Creates a dedicated Wine prefix just for Cube Suite
   (`~/.local/share/wineprefixes/cubesuite`), so it won't interfere with
   any other Wine setup or software you may already have.
3. Extracts `CubeSuite.zip` into that prefix and adds "M-Vave Cube Suite"
   to your application menu, using Cube Suite's own icon (extracted from
   its `.exe` via `icoutils`/`imagemagick`) when those tools are available,
   falling back to a generic Wine icon otherwise.

It's idempotent — safe to run again any time, for example after replacing
`CubeSuite.zip` with a newer version.

## Requirements

- An Ubuntu-family Linux distribution (Ubuntu, Pop!_OS, Linux Mint,
  Kubuntu, etc.) with `apt` and `sudo` access. Other distributions aren't
  automated by this script — see [Other distributions](#other-distributions)
  below.
- `CubeSuite.zip`, downloaded by you from the official M-Vave site (see
  below). **This repository does not include or redistribute it.**

## How to use

1. Download `CubeSuite.zip` from the official M-Vave downloads page:
   https://www.m-vave.com/download (look under the Cube Baby section).
2. Place `CubeSuite.zip` in this same folder, right next to `install.sh`.
3. Run:

   ```sh
   chmod +x install.sh
   ./install.sh
   ```

4. Look for **M-Vave Cube Suite** in your application menu, or launch it
   directly from a terminal:

   ```sh
   WINEPREFIX="$HOME/.local/share/wineprefixes/cubesuite" wine "$HOME/.local/share/wineprefixes/cubesuite/drive_c/CubeSuite/CubeSuite.exe"
   ```

### Uninstalling

To remove everything the script created (the Wine prefix, the menu
shortcut, and the icon):

```sh
./install.sh --uninstall
```

This leaves Wine itself (the apt packages) installed on your system, since
you may be using it for other things. Remove it yourself with your package
manager if you no longer need it.

### Other distributions

The automatic dependency install only supports `apt`-based systems. On any
other distribution, install `wine` (with 32-bit/multiarch support) and
`unzip` yourself, then run the script telling it to skip the dependency
step:

```sh
SKIP_DEPS=1 ./install.sh
```

## Compatibility

Tested on Pop!_OS / Ubuntu 24.04 (noble). Expected to work unmodified on
any apt-based Ubuntu/Debian derivative.

## Disclaimer

This project is **not affiliated with, endorsed by, or supported by
M-Vave**. Cube Suite is proprietary software © M-Vave — this script only
automates installing the official build under Wine; it does not include
or redistribute the software itself. Use at your own risk.
