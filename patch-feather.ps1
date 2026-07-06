# ============================================================
#  Patch Feather - keep Feather, block the forced "Dawn" update
#  Re-applies these edits to an EXISTING Feather install:
#    - disable auto-update to Dawn
#    - turn ads off
#    - copyright year -> 2026
#    - enable DevTools (Ctrl+Shift+I)
#    - disable the Electron asar-integrity fuse (so the edits load)
#  Safe & idempotent: backs up first, verifies the version,
#  and aborts without changing anything if it doesn't match.
# ============================================================
$ErrorActionPreference = 'Stop'
function Say($m,$c='Gray'){ Write-Host $m -ForegroundColor $c }

Say "`n  Patch Feather (keep Feather, no Dawn, no ads)`n" 'Cyan'

$prog = Join-Path $env:LOCALAPPDATA 'Programs\feather'
$exe  = Join-Path $prog 'Feather Launcher.exe'
$asar = Join-Path $prog 'resources\app.asar'

if (-not (Test-Path $exe) -or -not (Test-Path $asar)) {
    Say "Feather is not installed at:" 'Red'
    Say "  $prog" 'Red'
    Say "`nYou've most likely already been migrated to Dawn and no longer have" 'Yellow'
    Say "the Feather files. In that case use the FOLDER / zip version instead" 'Yellow'
    Say "(it ships Feather itself) rather than this script.`n" 'Yellow'
    Read-Host "Press Enter to exit"; exit 1
}

# Close Feather so its files aren't locked
Get-Process -Name 'Feather Launcher' -ErrorAction SilentlyContinue | Stop-Process -Force
Start-Sleep -Milliseconds 600

$enc = [System.Text.Encoding]::GetEncoding(28591)   # Latin1: 1 byte = 1 char

# ---- app.asar edits (all same-length, so offsets stay valid) ----
$edits = @(
  @{ name='disable Dawn update';
     old='if(this.devMode){this.launcherWindowManager.window.webContents.send(YT.Update,KT.UpdateNotAvailable)';
     new='if((1,2,3,4,!0)){this.launcherWindowManager.window.webContents.send(YT.Update,KT.UpdateNotAvailable)'; critical=$true },
  @{ name='turn ads off';
     old='({showAds:u})=>u'; new='({showAds:u})=>0'; critical=$false },
  @{ name='remove ad panel';
     old='fee||this.browserWindowManager.createAdWebviewManager()';
     new='fee&&this.browserWindowManager.createAdWebviewManager()'; critical=$false },
  @{ name='copyright year 2026';
     old='Feather Client 2025. All rights reserved.';
     new='Feather Client 2026. All rights reserved.'; critical=$false },
  @{ name='enable DevTools';
     old='FEATHER_DEVTOOLS==="1"'; new='FEATHER_DEVTOOLS!=="1"'; critical=$false }
)

$bytesA = [System.IO.File]::ReadAllBytes($asar)
$textA  = $enc.GetString($bytesA)

# Validate all edits before touching anything
$plan = @(); $anyMatch = $false
foreach ($e in $edits) {
    if ($e.old.Length -ne $e.new.Length) { throw "internal length mismatch: $($e.name)" }
    $hasOld = $textA.Contains($e.old)
    $hasNew = $textA.Contains($e.new)
    if ($hasOld)      { $plan += @{ e=$e; state='apply' }; $anyMatch=$true }
    elseif ($hasNew)  { $plan += @{ e=$e; state='done'  }; $anyMatch=$true }
    else {
        if ($e.critical) {
            Say "This doesn't look like a supported Feather version" 'Red'
            Say "(couldn't find: $($e.name)). Nothing was changed.`n" 'Red'
            Read-Host "Press Enter to exit"; exit 1
        }
        $plan += @{ e=$e; state='missing' }
    }
}
if (-not $anyMatch) {
    Say "This doesn't look like Feather. Nothing was changed.`n" 'Red'
    Read-Host "Press Enter to exit"; exit 1
}

# Locate + validate the Electron fuse (must be able to disable it, or the
# modified asar won't load). Marker + 38 = the integrity-validation fuse byte.
$bytesE = [System.IO.File]::ReadAllBytes($exe)
$sidx   = $enc.GetString($bytesE).IndexOf('dL7pKGdnNz796PbbjQWNKmHXBZaB9tsX')
if ($sidx -lt 0) { throw "Couldn't find the Electron fuse marker in the launcher. Nothing changed." }
$fuseOff = $sidx + 38
$fuseVal = $bytesE[$fuseOff]
if ($fuseVal -ne 48 -and $fuseVal -ne 49) { throw "Unexpected fuse byte ($fuseVal). Nothing changed." }

# ---- Back up originals (once) ----
if (-not (Test-Path "$exe.featherfix.bak"))  { Copy-Item $exe  "$exe.featherfix.bak"  -Force }
if (-not (Test-Path "$asar.featherfix.bak")) { Copy-Item $asar "$asar.featherfix.bak" -Force }
Say "Backups: *.featherfix.bak next to the originals`n" 'DarkGray'

# ---- Disable the fuse FIRST (harmless on an unmodified asar) ----
if ($fuseVal -eq 49) {
    $fs=[System.IO.File]::Open($exe,'Open','ReadWrite'); $fs.Seek($fuseOff,'Begin')|Out-Null; $fs.WriteByte(48); $fs.Close()
    Say "  [+] disabled asar-integrity fuse" 'Green'
} else { Say "  [=] asar-integrity fuse (already off)" 'DarkGray' }

# ---- Apply the asar edits ----
$applied = 0
foreach ($p in $plan) {
    switch ($p.state) {
        'apply'   { $textA = $textA.Replace($p.e.old,$p.e.new); $applied++; Say "  [+] $($p.e.name)" 'Green' }
        'done'    { Say "  [=] $($p.e.name) (already done)" 'DarkGray' }
        'missing' { Say "  [!] $($p.e.name) (not found in this build - skipped)" 'Yellow' }
    }
}
if ($applied -gt 0) {
    $outA = $enc.GetBytes($textA)
    if ($outA.Length -ne $bytesA.Length) { throw "asar size changed - restore from app.asar.featherfix.bak" }
    [System.IO.File]::WriteAllBytes($asar,$outA)
}

Say "`nDone. Feather is patched - it will stay Feather (no Dawn update, no ads)." 'Cyan'
Say "Open it normally; press Ctrl+Shift+I for DevTools.`n" 'Cyan'
Read-Host "Press Enter to exit"
