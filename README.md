# Feather Client Patch

A small Windows script that patches an **existing** Feather Client launcher so it keeps working as **Feather** instead of auto-migrating to the new **"Dawn"** client and turns off ads while it's at it.

> Feather was acquired and its launcher now auto-updates itself into "Dawn". This tool stops that on a Feather install you already have.

---

## What it does

It applies these edits to your installed Feather launcher:

- **Blocks the auto-update to Dawn** — the launcher stops replacing itself.
- **Disables ads** — no ad bar, no ad panel.
- **Enables DevTools** — open with `Ctrl+Shift+I`.
- **Sets the copyright year in the launcher's footer to 2026** — cosmetic text only; it does **not** change your system clock or any time settings.
- **Disables the Electron asar-integrity fuse** — required so the modified launcher is allowed to load.

All edits are same-length, in-place changes to files you already have. Nothing is downloaded.

## Requirements

- Windows
- Feather must **still be installed** at `%LOCALAPPDATA%\Programs\feather`.

If your launcher has **already turned into Dawn**, the script has nothing to patch on its own but you may be able to get Feather back first (see the next section). This repository does not distribute the Feather program files themselves.

## Already on Dawn, or uninstalled?

Before giving up, check whether Feather's updater left a cached **Feather installer** on your machine:

1. Open `%LOCALAPPDATA%\feather-updater` — paste that path into the File Explorer address bar.
2. Look for a large (~128 MB) **`installer.exe`**. Right-click it → **Properties → Details**; if the product/company reads **"Feather Launcher" / "Digital Ingot, Inc."**, it's the genuine Feather installer.
   - Ignore the small `dawn.exe` in the `pending` subfolder — that one is **Dawn**, not Feather.
3. Run `installer.exe` to reinstall Feather, then run this patch **before** you open the launcher, so it doesn't immediately update itself back to Dawn.

If that folder is missing, empty, or only contains Dawn files, this recovery won't work you'd need the Feather program files from another source.

## How to use

1. Click **Code → Download ZIP**, then unzip it.
2. Double-click **`Patch Feather.bat`** (or right-click `patch-feather.ps1` → **Run with PowerShell**).
3. Wait for the **Done** message, then open Feather normally.

No administrator rights are needed. It's safe to run more than once — it detects what's already patched and won't double-apply, and it aborts without changing anything if it doesn't recognize your Feather version.

## Backups & how to undo

Before changing anything, the script backs up the originals next to them:

```
%LOCALAPPDATA%\Programs\feather\Feather Launcher.exe.featherfix.bak
%LOCALAPPDATA%\Programs\feather\resources\app.asar.featherfix.bak
```

To revert, restore those two `.bak` files over the originals (remove the `.featherfix.bak` suffix). That brings back the stock launcher — **including ads and the Dawn auto-update.**

## Antivirus note

Patching changes the launcher, so its digital signature no longer matches. Antivirus (Windows Defender, AVAST, etc.) may warn about or quarantine `Feather Launcher.exe`. That's expected for any patched app — allow/restore it, or add the folder to your exclusions. If it gets deleted, run the patcher again after allowing it.

## Trade-off: no new Minecraft versions

Updates are disabled on purpose — that's what stops the Dawn takeover. The downside is that Feather is now frozen on its current Minecraft version and won't receive new ones. For the latest Minecraft, or Forge/NeoForge, use a maintained launcher such as [Prism Launcher](https://prismlauncher.org/).

## Disclaimer

This project is **not affiliated with, endorsed by, or connected to** Feather, InPVP, or Digital Ingot, Inc. "Feather" and related names are trademarks of their respective owners. This tool only modifies a copy of software already installed on your own machine; it does not distribute that software. Provided **as-is**, for personal use, with no warranty — **use at your own risk.**
