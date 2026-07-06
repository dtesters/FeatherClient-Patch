PATCH FEATHER  -  SCRIPT VERSION  (small, patches your install)


Use this ONLY if you still have the Feather launcher installed
(i.e. it hasn't already turned into "Dawn"). It patches your
existing Feather so it stops updating to Dawn and turns ads off.

  >> If Feather is already gone / became Dawn, this script can't
     help - There will be a (zip) version soon instead, which ships the
     actual Feather app. BUT YOU MAY STILL BE ABLE TO GET THE FEATHER INSTALL

Run 
```%LOCALAPPDATA%\feather-updater```
In explorer or the run window, there should be a installer.exe from feather, install it and run the patch
--------------------------------------------------------------------
HOW TO RUN
--------------------------------------------------------------------
1. Double-click:  "Patch Feather.bat"
   (or right-click "patch-feather.ps1" -> Run with PowerShell)
2. Read the messages. When it says "Done", close the window.
3. Open Feather normally - it stays Feather.

No administrator rights are needed.

--------------------------------------------------------------------
WHAT IT DOES  /  NOTES
--------------------------------------------------------------------
- Disables the auto-update to Dawn, turns ads off, changes the copyright year shown in the launcher's footer to 2026, and enables DevTools (Ctrl+Shift+I).
- It BACKS UP the originals first as:
    "Feather Launcher.exe.featherfix.bak"  and
    "resources\app.asar.featherfix.bak"
  (inside %LOCALAPPDATA%\Programs\feather). To undo, just restore
  those two backups over the originals.
- Safe to run twice - it detects what's already patched.
- If it says the version isn't supported, it changed nothing.

ANTIVIRUS: patching changes the launcher, so its signature no longer
matches and antivirus may warn about "Feather Launcher.exe". That's
expected - allow/restore it if needed.

UPDATES ARE OFF ON PURPOSE: that's what blocks Dawn, but it also
means Feather won't get NEW Minecraft versions. For the newest
Minecraft use a launcher like Prism.
====================================================================
