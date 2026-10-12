# Feather Client Patch

> [!IMPORTANT]
> **Update (October 2026): missing Play button / no Minecraft versions — fixed.**
>
> Feather's version server (`game-launcher.feathermc.com`) was shut down, so patched launchers suddenly showed **no Minecraft versions and no Play button**. Your install wasn't broken; the list it downloads at startup was gone.
>
> Dawn still publishes the same version list, but its version files now contain `linux-arm` entries that Feather's last launch engine can't read, so pointing Feather straight at Dawn brings the versions back yet **every launch crashes** at "Loading version". This repo now hosts a cleaned copy (in [`index/`](index/)) that a GitHub Action rebuilds from Dawn every 6 hours, so new versions keep appearing. It also lifts Feather's frozen list of allowed versions and serves updated copies of the launcher's mod lists (Feather's stop at 26.2), so newer versions such as 26.3 download, launch and show their mods. Dawn's NeoForge builds use a newer format Feather can't read, so they're left out of the list.
>
> **If you patched before this fix**, download this repo again and re-run `Patch Feather.bat`. It only applies what's missing.
>
> Only need the version list back (up to 26.2)? Running this once in a terminal and reopening Feather is enough:
>
> ```
> setx VERSION_INDEX "https://raw.githubusercontent.com/dtesters/FeatherClient-Patch/main/index/version_index.json"
> ```
>
> Versions newer than 26.2 (26.3 and up) also need the re-run, otherwise they hang on "Version Loading" and the Mods tab freezes.

This is a small Windows script that patches an **existing** Feather Client launcher so it keeps working as **Feather** instead of auto-migrating to the new **"Dawn"** client and turns off ads while it's at it.

> Feather was acquired and its launcher now auto-updates itself into "Dawn". This tool stops that on a Feather install you already have.

---

## What it does

It applies these edits to your installed Feather launcher:

- **Blocks the auto-update to Dawn** the launcher stops replacing itself.
- **Disables ads** no ad bar, no ad panel.
- **Enables DevTools** open with `Ctrl+Shift+I`.
- **Sets the copyright year in the launcher's footer to 2026** cosmetic text only.
- **Disables the Electron asar-integrity fuse** required so the modified launcher is allowed to load.
- **Restores the Minecraft version list** by setting a per-user environment variable, `VERSION_INDEX`, to this repo's cleaned, auto-updated version list (see the update note above).
- **Removes Feather's frozen version allow-list check**, so versions released after Feather was abandoned can be launched.
- **Points the launcher's mod lists (`mods.json`, `modrinth.json`) at updated copies in this repo**, which add the newer versions. Without them those versions hang on "Version Loading".

The launcher edits are small in-place changes to files you already have (the mod-list edit makes `app.asar` 68 bytes larger, and the script updates its file table to match). The script itself downloads nothing; Feather then fetches its version list and game files as usual.

## Requirements

- Windows
- Feather must **still be installed** at `%LOCALAPPDATA%\Programs\feather`

If your launcher has **already turned into Dawn**, the script has nothing to patch on its own but you may be able to get Feather back first (see the next section). This repository does not distribute the Feather program files themselves.

## Already on Dawn, or uninstalled?

Before giving up, check whether Feather's updater left a cached **Feather installer** on your machine:

1. Open `%LOCALAPPDATA%\feather-updater` paste that path into the File Explorer address bar.
2. Look for a large (~128 MB) **`installer.exe`**. Right-click it → **Properties → Details**; if the product/company reads **"Feather Launcher" / "Digital Ingot, Inc."**, it's the genuine Feather installer.
   - Ignore the small `dawn.exe` in the `pending` subfolder that one is **Dawn**, not Feather.
3. Run `installer.exe` to reinstall Feather, then run this patch **before** you open the launcher, so it doesn't immediately update itself back to Dawn.

If that folder is missing, empty, or only contains Dawn files, this recovery won't work you'd need the Feather program files from another source.

## How to use

1. Click **Code → Download ZIP**, then unzip it.
2. Double-click **`Patch Feather.bat`** (or right-click `patch-feather.ps1` → **Run with PowerShell**).
3. Wait for the **Done** message, then open Feather normally.

No administrator rights are needed. It's safe to run more than once, it detects what's already patched and won't double-apply, and it aborts without changing anything if it doesn't recognize your Feather version.

## Backups & how to undo

Before changing anything, the script backs up the originals next to them:

```
%LOCALAPPDATA%\Programs\feather\Feather Launcher.exe.featherfix.bak
%LOCALAPPDATA%\Programs\feather\resources\app.asar.featherfix.bak
```

To revert, restore those two `.bak` files over the originals (remove the `.featherfix.bak` suffix). That brings back the stock launcher **including ads and the Dawn auto-update.**

To also remove the version-list setting, run `reg delete HKCU\Environment /v VERSION_INDEX /f` (without it, Feather will show no versions again).

## Antivirus note

Patching changes the launcher, so its digital signature no longer matches. Antivirus (Windows Defender, AVAST, etc.) may warn about or quarantine `Feather Launcher.exe`. That's expected for any patched app allow/restore it, or add the folder to your exclusions. If it gets deleted, run the patcher again after allowing it.

## Trade-off: no new Minecraft versions

Launcher updates are disabled on purpose and that's what stops the Dawn takeover. The launcher itself is frozen, and the list of playable Minecraft versions now depends on Dawn keeping its copy of the version list public (and on Feather's mod lists and asset servers staying up). If that copy is moved or locked, versions disappear again until this patch is updated. For the latest Minecraft, with more loader support like Forge/NeoForge, use a maintained launcher such as [Prism Launcher](https://prismlauncher.org/).

## Disclaimer

This project is **not affiliated with, endorsed by, or connected to** Feather, InPVP, or Digital Ingot, Inc. "Feather" and related names are trademarks of their respective owners. This tool only modifies a copy of software already installed on your own machine; it does not distribute that software. Provided **as-is**, for personal use, with no warranty **use at your own risk.**
