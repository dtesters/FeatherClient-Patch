<div align="center">

# Feather Client Patch

**Keep using Feather.** Stops the forced update to Dawn, removes ads, and brings back the version list,<br>
mods and in-game menu that broke when Feather's servers were shut down.

[![Watch the setup guide](https://img.shields.io/badge/▶%20Setup%20guide-Watch%20on%20YouTube-FF0000?style=for-the-badge&logo=youtube&logoColor=white)](https://www.youtube.com/watch?v=bSvNIxyM1WM)
[![Join the Discord for support](https://img.shields.io/badge/Need%20help%3F-Join%20our%20Discord-5865F2?style=for-the-badge&logo=discord&logoColor=white)](https://discord.gg/RBUwmddb7s)
[![Download the patch](https://img.shields.io/badge/⬇%20Download-Patch%20(ZIP)-2ea44f?style=for-the-badge&logo=github&logoColor=white)](https://github.com/dtesters/FeatherClient-Patch/archive/refs/heads/main.zip)

</div>

## 🔗 Quick links

| | |
| --- | --- |
| 🎬 **Video guide** | [How to install it, step by step (YouTube)](https://www.youtube.com/watch?v=bSvNIxyM1WM) |
| 💬 **Support & updates** | **[Join the Discord server](https://discord.gg/RBUwmddb7s)**: ask for help, report problems, hear about fixes first |
| ⬇️ **Download the patch** | [FeatherClient-Patch (ZIP)](https://github.com/dtesters/FeatherClient-Patch/archive/refs/heads/main.zip) |
| 🪶 **Download Feather** (if you don't have it) | [feathermc.com/download/windows](https://feathermc.com/download/windows) |
| 🛠️ **Something broke?** | [Troubleshooting](#-troubleshooting) · [Discord](https://discord.gg/RBUwmddb7s) |

[![Setup guide video](https://img.youtube.com/vi/bSvNIxyM1WM/maxresdefault.jpg)](https://www.youtube.com/watch?v=bSvNIxyM1WM)

> [!TIP]
> **Stuck or something not working? [Join the Discord](https://discord.gg/RBUwmddb7s).** That's where fixes are announced first and where you can get help.

---

## 🚀 Quick start

1. **[Download the patch](https://github.com/dtesters/FeatherClient-Patch/archive/refs/heads/main.zip)** and unzip it.
2. Double-click **`Patch Feather.bat`**.
   - No Feather on this PC? It asks **"Would you like to install Feather automatically?"** Press **Y** and it installs it for you.
   - It asks **"Would you like this patch to update itself automatically?"** Press **Y** (recommended) and you never have to download it again.
3. Wait for **Done**, then open Feather from its **Desktop or Start Menu shortcut**.

No administrator rights needed. Safe to run again any time: it only applies what's missing.

## ✨ What you get

- **No forced update to Dawn**, and **no ads**.
- **All versions back**, each listed twice so you can pick the client:

  | You pick | In-game client |
  | --- | --- |
  | `1.21.8-feather` (1.8.9 … 26.2) | the **original Feather client** (its final build) |
  | `1.21.8-dawn` (1.8.9 … 26.2) | **Dawn's** client |
  | `26.3-dawn` and newer | **Dawn's** client: Feather stopped at 26.2, new versions appear automatically |

- **Mods work**: Feather mods, Modrinth browsing/updates, and your own uploaded mods on every version.
- **The in-game Feather menu works** even while Feather's menu server is down.
- **Cosmetics** load from Dawn's CDN, which still has every Feather cosmetic plus Dawn's newer ones.
- **DevTools** with `Ctrl+Shift+I`.

## 🔄 Auto-update

Feather keeps losing servers, and every fix used to mean downloading the patch again. Now you run it once:

- When you open Feather from its **Desktop / Start Menu shortcut**, it quietly checks this repo. If there's a newer patch, it applies it, then starts Feather. Usually that adds about a second; an actual update takes a few more.
- It **never touches a running Feather or game**. If Feather is already open, the update waits until next time.
- Version lists, mod lists and other data fixes are live for everyone immediately, with no update needed.
- The log is at `%APPDATA%\.feather\featherfix\update.log`.

To turn it off, run the patch again and press **N** when it asks about auto-update. Without auto-update, download and run the patch again whenever there's a fix.

> [!NOTE]
> Opening Feather from a **taskbar pin** made before patching skips the check. Re-pin it from the Start Menu shortcut.

## 🧰 Troubleshooting

| Problem | Fix |
| --- | --- |
| A version hangs on **"Version Loading"** right after an update | Close Feather completely and open it again. |
| **No Play button / no versions** | Run `Patch Feather.bat` again (it sets the version list source). |
| In-game menu shows **"Connection timed out" (Cloudflare 522)** | Run the latest patch (or open Feather from its shortcut so it auto-updates). |
| Game won't start: **"Error opening zip file … javaagent"** | Fixed in patch 2026.10.14 (usernames with a space). Update the patch. |
| Antivirus warns about `Feather Launcher.exe` | Expected for a patched app: allow/restore it in your antivirus, then re-run the patch (details under **Safety** below). |
| Mods missing after updating | Re-run the patch: it copies your mods to the new version names. |
| **Dawn's own launcher opens Feather** or shows "Connection timed out" | Fixed in patch 2026.10.14.3. Update the patch, then restart Dawn. |
| **"Unable to connect to the remote server"** while installing Feather | Your network is blocking feathermc.com. Download Feather in your browser from [feathermc.com/download/windows](https://feathermc.com/download/windows), leave it in Downloads (or put it next to the patch), and run the patch again. |
| Anything else | **[Ask on Discord](https://discord.gg/RBUwmddb7s)**, ideally with the launcher log (log window → Copy Logs). |

## Don't have Feather (anymore)?

The patch can install it for you (press **Y** when asked). It uses the installer Feather's updater left on your PC if there is one, otherwise it downloads it from **https://feathermc.com/download/windows** (2.6.13, ~128 MB), and only runs it if the file matches the hash below.

Feather's updater may also have left a copy at `%LOCALAPPDATA%\feather-updater\installer.exe` (ignore the small `dawn.exe` in `pending`; that's Dawn). Both are the same file:

```
SHA-256  e36573f9990060e72e3083c949baa444d1bc96a192c58a9f416b7c96a2494ba0
```

Check with `certutil -hashfile "path\to\installer.exe" SHA256`. **When the installer finishes, close Feather right away if it opens**, then run the patch before using the launcher.

---

<details>
<summary><b>🔍 What exactly the patch changes</b></summary>

Edits to your installed launcher (`%LOCALAPPDATA%\Programs\feather`):

- **Blocks the auto-update to Dawn.**
- **Disables ads** (ad bar and ad panel).
- **Enables DevTools** (`Ctrl+Shift+I`), sets the footer year to 2026.
- **Disables the Electron asar-integrity fuse**, so the modified launcher is allowed to load.
- **Version list:** Feather loads this repo's list ([`index/`](index/)), rebuilt from Dawn's public one every 6 hours. Feather's own version server was shut down. It's set inside Feather only, so Dawn's launcher keeps using its own list.
- **Removes Feather's frozen version allow-list**, so newer versions can launch.
- **Mod lists** (`mods.json`, `modrinth.json`) load from this repo, with the newer versions and `-feather` / `-dawn` entries.
- **Launcher language / background / server-list files** load from this repo's [`mirror/`](mirror/) (the launcher can't get past its splash screen without them).
- **Mods on the new version names:** custom mod folders, Modrinth search/updates/version rows and the incompatible-mod checks assumed names like `26.1-fabric`.
- **Cosmetics** download from Dawn's CDN (same paths, plus Dawn's newer items).
- **In-game menu fallback:** a ~4 KB Java agent ([`agent/`](agent/), our own code, source included). At game start it checks `mc-webapp.feathermc.com`; only if that's down it points the menu at Feather's own beta web app.
- **Copies your per-version mods** to the new version names (backup: `feather-mods.json.featherfix.bak`).
- **Auto-update:** `%APPDATA%\.feather\featherfix\` plus the Desktop / Start Menu shortcuts.

Where game files come from: original Feather jars from the [featherarchived](https://github.com/featherarchived/builds-cf.feathercdn.net) copy (pinned by hash in [`tools/feather_builds.json`](tools/feather_builds.json)); Dawn's client and newer versions from Dawn's public CDN; Minecraft, Fabric and libraries from the usual Mojang/Fabric/Maven servers. Dawn's NeoForge builds use a format Feather's launcher can't read, so they're left out.

</details>

<details>
<summary><b>🛡️ Safety</b></summary>

- **Feather jars:** every one is pinned by hash, matching Feather's own version files. The launcher checks hashes on download; a test serving a different jar under a pinned hash was refused (`Hash check failed`) and the game never started.
- **Auto-update** downloads `patch-feather.ps1` and `agent/featherfix-agent.jar` from this repository over HTTPS and runs them. Only use it if you trust this repo; you can turn it off (see above) and update manually instead.
- **Antivirus note:** patching changes the launcher, so its digital signature no longer matches. Windows Defender, AVAST, etc. may warn about or quarantine `Feather Launcher.exe`. Allow/restore it (or add the folder to exclusions), then run the patch again if it was removed.

</details>

<details>
<summary><b>⚠️ Known limits</b></summary>

- **`-dawn` versions:** Dawn's client gets some things from Dawn's own launcher, which isn't running here: your head icon in Dawn's menu stays generic, cosmetic thumbnails show "?", and the "new release" store card stays empty (`Cosmetic atlas doesn't exist` in the log). The game itself runs fine; `-feather` versions don't have this. `DRM check failed` / `FieldNamingPolicy` log lines are normal (Dawn's own launcher shows them too).
- **If Feather's account server shuts down:** before every launch Feather's launch engine checks a token signed by Feather's account server (`api.feathermc.com`, the engine calls this `DRM`). Without it nothing can launch, `-feather` or `-dawn`. Getting around that would mean defeating Feather's DRM, which this project doesn't do. [Prism Launcher](https://prismlauncher.org/) still runs Fabric with your own Microsoft account.
- **What this depends on:** Dawn's public version list, the featherarchived jars, and Feather's asset/mod-list/account servers. If one moves, this repo gets updated (and auto-update brings it to you).

</details>

<details>
<summary><b>↩️ Backups & how to undo</b></summary>

The script backs up the originals once:

```
%LOCALAPPDATA%\Programs\feather\Feather Launcher.exe.featherfix.bak
%LOCALAPPDATA%\Programs\feather\resources\app.asar.featherfix.bak
```

To revert, restore those two over the originals (remove `.featherfix.bak`). That brings back the stock launcher, **including ads and the Dawn auto-update**. Also run the patch once more and press **N** for auto-update.

</details>

---

<div align="center">

**Questions, bugs, or just want updates? [Join the Discord](https://discord.gg/RBUwmddb7s)** · **[Watch the guide](https://www.youtube.com/watch?v=bSvNIxyM1WM)**

</div>

## Disclaimer

This project is **not affiliated with, endorsed by, or connected to** Feather, InPVP, Dawn, or Digital Ingot, Inc. "Feather", "Dawn" and related names are trademarks of their respective owners. This tool only modifies a copy of software already installed on your own machine; it does not distribute that software. Provided **as-is**, for personal use, with no warranty: **use at your own risk.**
