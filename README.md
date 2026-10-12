# Feather Client Patch

This is a small Windows script that patches the **Feather Client** launcher so it keeps working as **Feather** instead of auto-migrating to the new **"Dawn"** client. It also turns off ads and brings back the Minecraft version list that disappeared when Feather's servers were shut down.

> Feather was acquired and its launcher now auto-updates itself into "Dawn". This tool stops that on a Feather install you already have (or one you reinstall from the link below).

> [!IMPORTANT]
> **Latest (October 2026): pick the original Feather client or Dawn's, per version.**
>
> - **Every version up to 26.2 is listed twice** in the version picker: `1.21.8-feather` runs the **original Feather client** (Feather's final build) and `1.21.8-dawn` runs **Dawn's** client. Switch with one click under **Change Version**.
> - **26.3 and newer are Dawn only** (`26.3-dawn`, ...) and show up automatically as Dawn releases them. Feather's client can't be carried forward: its 26.2 build crashes on 26.3 because the Minecraft code it hooks into changed, and Feather's source isn't public.
> - Both variants use the newer Fabric Loader / Fabric API that Dawn ships, and follow Dawn's updates.
> - **No Play button / no versions?** Feather's version server (`game-launcher.feathermc.com`) was shut down. This repo now hosts the version list in [`index/`](index/), rebuilt from Dawn's public one every 6 hours, with fixes so Feather's launch engine can read it.
>
> **If you patched before**, download this repo again and re-run `Patch Feather.bat`. It only applies what's missing, and it **copies your mods** (enabled mods, Modrinth mods, custom mod files) from the old version names to the new `-feather` / `-dawn` ones. Without the re-run your versions still work, but their mod lists start empty. If a version hangs on "Version Loading" right after an update, close and reopen Feather once.

---

## What it does

It applies these edits to your installed Feather launcher:

- **Blocks the auto-update to Dawn**: the launcher stops replacing itself.
- **Disables ads**: no ad bar, no ad panel.
- **Enables DevTools**: open with `Ctrl+Shift+I`.
- **Sets the copyright year in the launcher's footer to 2026**: cosmetic text only.
- **Disables the Electron asar-integrity fuse**: required so the modified launcher is allowed to load.
- **Restores the Minecraft version list** by setting a per-user environment variable, `VERSION_INDEX`, to this repo's auto-updated version list.
- **Removes Feather's frozen version allow-list check**, so versions released after Feather was abandoned can be launched.
- **Points the launcher's mod lists (`mods.json`, `modrinth.json`) at updated copies in this repo**, which add the newer versions and the `-feather` / `-dawn` entries. Without them those versions hang on "Version Loading".
- **Copies your per-version mods to the new version names** (a backup of `feather-mods.json` is kept as `feather-mods.json.featherfix.bak`).

The launcher edits are small in-place changes to files you already have (the mod-list edit makes `app.asar` 68 bytes larger, and the script updates its file table to match). The script itself downloads nothing; Feather then fetches its version list and game files as usual.

### Where the game files come from

| You pick | In-game client | Source |
| --- | --- | --- |
| `1.8.9-feather` … `26.2-feather` | Original Feather (final build) | Feather's own jars, archived at [featherarchived](https://github.com/featherarchived/builds-cf.feathercdn.net), pinned by SHA-1 in [`tools/feather_builds.json`](tools/feather_builds.json) |
| `1.8.9-dawn` … `26.2-dawn` | Dawn | Dawn's public CDN |
| `26.3-dawn` and newer | Dawn | Dawn's public CDN |

Minecraft itself, Fabric and the other libraries come from the usual Mojang/Fabric/Maven servers. Dawn's NeoForge builds use a newer format Feather's launcher can't read, so they're left out.

## Requirements

- Windows
- Feather installed at `%LOCALAPPDATA%\Programs\feather` (see the next section if it isn't)

## Don't have Feather (anymore)?

The official download link still serves the last Feather launcher (2.6.13, ~128 MB):

**https://feathermc.com/download/windows**

Alternatively, Feather's updater may have left a cached copy at `%LOCALAPPDATA%\feather-updater\installer.exe` (ignore the small `dawn.exe` in the `pending` subfolder; that one is Dawn). Both are the same file:

```
SHA-256  e36573f9990060e72e3083c949baa444d1bc96a192c58a9f416b7c96a2494ba0
```

To check, run `certutil -hashfile "path\to\installer.exe" SHA256`, or right-click it → **Properties → Details** and look for **"Feather Launcher" / "Digital Ingot, Inc."**.

**Important:** when the installer finishes, **close Feather right away if it opens** (or untick "Run Feather" at the end), then run this patch **before** using the launcher. Otherwise it updates itself into Dawn.

## How to use

1. Click **Code → Download ZIP**, then unzip it.
2. Make sure Feather is closed.
3. Double-click **`Patch Feather.bat`** (or right-click `patch-feather.ps1` → **Run with PowerShell**).
4. Wait for the **Done** message, then open Feather normally.

No administrator rights are needed. It's safe to run more than once: it detects what's already patched and won't double-apply, and it aborts without changing anything if it doesn't recognize your Feather version.

## Backups & how to undo

Before changing anything, the script backs up the originals next to them:

```
%LOCALAPPDATA%\Programs\feather\Feather Launcher.exe.featherfix.bak
%LOCALAPPDATA%\Programs\feather\resources\app.asar.featherfix.bak
```

To revert, restore those two `.bak` files over the originals (remove the `.featherfix.bak` suffix). That brings back the stock launcher **including ads and the Dawn auto-update.**

To also remove the version-list setting, run `reg delete HKCU\Environment /v VERSION_INDEX /f` (without it, Feather will show no versions again).

## Antivirus note

Patching changes the launcher, so its digital signature no longer matches. Antivirus (Windows Defender, AVAST, etc.) may warn about or quarantine `Feather Launcher.exe`. That's expected for any patched app: allow/restore it, or add the folder to your exclusions. If it gets deleted, run the patcher again after allowing it.

## How long will this keep working?

Launcher updates are disabled on purpose; that's what stops the Dawn takeover. The launcher itself is frozen, so this depends on a few outside things staying up:

- **Dawn's public version list** (for new versions and the Dawn entries).
- **The featherarchived copy of Feather's client jars** (for the original Feather entries).
- **Feather's asset, mod-list and account servers**, which are still answering today.

If one of those moves or gets locked, this repo has to be updated. For the latest Minecraft with full Forge/NeoForge support, a maintained launcher such as [Prism Launcher](https://prismlauncher.org/) is the safer long-term option.

## Disclaimer

This project is **not affiliated with, endorsed by, or connected to** Feather, InPVP, Dawn, or Digital Ingot, Inc. "Feather", "Dawn" and related names are trademarks of their respective owners. This tool only modifies a copy of software already installed on your own machine; it does not distribute that software. Provided **as-is**, for personal use, with no warranty: **use at your own risk.**
