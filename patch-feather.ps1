# ============================================================
#  Patch Feather - keep Feather, block the forced "Dawn" update
#  Re-applies these edits to an EXISTING Feather install:
#    - disable auto-update to Dawn
#    - turn ads off
#    - copyright year -> 2026
#    - enable DevTools (Ctrl+Shift+I)
#    - restore the version list + mod lists (Feather's servers are gone)
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

# Replace strings with different-length ones inside ONE packed file of an asar (Latin1 text in/out).
# Rewrites the header: that file's size + SHA256 integrity, and shifts every later file's offset.
# Returns the new text, or $null if none of the old strings are present.
function Edit-AsarResize([string]$text, $pairs) {
    $hp   = [BitConverter]::ToUInt32($enc.GetBytes($text.Substring(4,4)),0)
    $jl   = [BitConverter]::ToUInt32($enc.GetBytes($text.Substring(12,4)),0)
    $base = 8 + $hp
    $hdr  = $text.Substring(16,$jl)
    $idx  = -1
    foreach ($p in $pairs) { $idx = $text.IndexOf($p.old,$base); if ($idx -ge 0) { break } }
    if ($idx -lt 0) { return $null }
    $rx = '"size":(\d+),"offset":"(\d+)"(,"integrity":\{"algorithm":"SHA256","hash":"[0-9a-f]+","blockSize":(\d+),"blocks":\[[^\]]*\]\})?'
    $m = [regex]::Matches($hdr,$rx) | Where-Object {
        $o=[long]$_.Groups[2].Value; $s=[long]$_.Groups[1].Value; ($base+$o) -le $idx -and $idx -lt ($base+$o+$s) } | Select-Object -First 1
    if (-not $m) { throw "couldn't find the asar entry holding the edit" }
    $size = [long]$m.Groups[1].Value; $off = [long]$m.Groups[2].Value
    $body = $text.Substring($base+$off,$size)
    foreach ($p in $pairs) { $body = $body.Replace($p.old,$p.new) }
    $delta = $body.Length - $size
    $entry = '"size":' + $body.Length + ',"offset":"' + $off + '"'
    if ($m.Groups[3].Success) {
        $bs  = [int]$m.Groups[4].Value
        $sha = [System.Security.Cryptography.SHA256]::Create()
        $raw = $enc.GetBytes($body)
        $hex = { param($b) -join ($b | ForEach-Object { $_.ToString('x2') }) }
        $blocks = for ($i=0; $i -lt $raw.Length; $i+=$bs) { '"' + (& $hex $sha.ComputeHash($raw,$i,[Math]::Min($bs,$raw.Length-$i))) + '"' }
        $entry += ',"integrity":{"algorithm":"SHA256","hash":"' + (& $hex $sha.ComputeHash($raw)) + '","blockSize":' + $bs + ',"blocks":[' + ($blocks -join ',') + ']}'
    }
    $hdr = $hdr.Substring(0,$m.Index) + $entry + $hdr.Substring($m.Index+$m.Length)
    $hdr = [regex]::Replace($hdr,'"offset":"(\d+)"',{ param($x) $o=[long]$x.Groups[1].Value
        if ($o -gt $off) { '"offset":"' + ($o+$delta) + '"' } else { $x.Value } })
    $pad = (4 - $hdr.Length % 4) % 4
    $payload = 4 + $hdr.Length + $pad
    $u = { param($n) $enc.GetString([BitConverter]::GetBytes([uint32]$n)) }
    $data = $text.Substring($base)
    return (& $u 4) + (& $u (4+$payload)) + (& $u $payload) + (& $u $hdr.Length) + $hdr + ([string][char]0 * $pad) +
           $data.Substring(0,$off) + $body + $data.Substring($off+$size)
}

# ---- app.asar edits (same-length ones first; the resize below rewrites the header) ----
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
     old='FEATHER_DEVTOOLS==="1"'; new='FEATHER_DEVTOOLS!=="1"'; critical=$false },
  @{ name='allow versions newer than Feather''s frozen list';
     old='const u=t.mcVersions.includes(o);return u||this.notificationService';
     new='const u=(t.mcVersions.length,!0);return u||this.notificationService'; critical=$false },
  # Versions are named e.g. 26.1.1-feather-fabric / 26.3-dawn-fabric. The custom-mod folder watcher only
  # accepted "<version>" or "<version>-fabric" folders, so uploads and custom mods were ignored.
  @{ name='custom mods on -feather / -dawn versions';
     old='3}){1,2}(-fabric)?$/'; new='3}){1,2}(-[a-z]+)*$/'; critical=$false },
  # Modrinth search/updates derived the Minecraft version by stripping "-fabric" ("26.3-dawn" matched nothing).
  @{ name='Modrinth browsing on -feather / -dawn versions';
     old='[(0,_.w)(d.controls.version.value.replace("-fabric",""))]';
     new='[(0,_.w)(d.controls.version.value.split("-")[0]        )]'; critical=$false },
  @{ name='Modrinth mod loading on -feather / -dawn versions';
     old='ue=(0,Ar.w)(o.replace("-fabric",""))'; new='ue=(0,Ar.w)(o.split("-")[0]        )'; critical=$false },
  @{ name='Modrinth mod updates on -feather / -dawn versions';
     old='const g=(0,Ar.w)(u.replace("-fabric",""));'; new='const g=(0,Ar.w)(u.split("-")[0]        );'; critical=$false },
  @{ name='mod compatibility checks on -feather / -dawn versions (1/3)';
     old='u=f.replace("-fabric",""),p;'; new='u=f.split("-")[0]        ,p;'; critical=$false },
  @{ name='mod compatibility checks on -feather / -dawn versions (2/3)';
     old='u=o.replace("-fabric",""),p;'; new='u=o.split("-")[0]        ,p;'; critical=$false },
  @{ name='mod compatibility checks on -feather / -dawn versions (3/3)';
     old='l=t.replace("-fabric",""),u;'; new='l=t.split("-")[0]        ,u;'; critical=$false },
  # The launch engine downloads cosmetics from a hard-coded host. Dawn's CDN serves every Feather
  # cosmetic plus Dawn's newer ones at the same paths (same-length swap; the trailing NUL pins it
  # to the engine's copy, not the UI's icon URLs).
  @{ name='cosmetics from Dawn''s CDN (all Feather + Dawn cosmetics)';
     old="https://assets.feathercdn.net/`0"; new="https://assets.dawn.gg/assets/`0"; critical=$false }
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
}

# ---- Point the launcher's frozen mod lists at updated copies (these edits change the file size) ----
# Feather's mods.json/modrinth.json stop at 26.2; newer versions hang on "Version Loading" without them.
$cfg = 'https://raw.githubusercontent.com/dtesters/FeatherClient-Patch/main/index/'
$resize = @(
  @{ old='"https://electron-launcher.feathermc.com/mods.json"';     new="`"${cfg}mods.json`"" },
  @{ old='"https://electron-launcher.feathermc.com/modrinth.json"'; new="`"${cfg}modrinth.json`"" }
)
$resized = Edit-AsarResize $textA $resize
if ($null -ne $resized) {
    $textA = $resized; $applied++
    Say "  [+] mod lists -> updated copies (adds 26.3+)" 'Green'
} elseif ($textA.Contains($resize[0].new)) {
    Say "  [=] mod lists -> updated copies (already done)" 'DarkGray'
} else {
    Say "  [!] mod lists (not found in this build - skipped)" 'Yellow'
}

# ---- Load the launcher's other files (languages, backgrounds, server lists) from this repo's mirror ----
# Without the language files the launcher can't even get past its splash screen, so it would die
# with Feather's electron-launcher server. The mirror keeps the last good copy of each file.
$mirror = @( @{ old='https://electron-launcher.feathermc.com/';
                new='https://raw.githubusercontent.com/dtesters/FeatherClient-Patch/main/mirror/electron-launcher/' } )
$files = 0
while ($null -ne ($resized = Edit-AsarResize $textA $mirror)) { $textA = $resized; $files++; $applied++ }
if ($files -gt 0) { Say "  [+] launcher files -> repo mirror ($files files)" 'Green' }
elseif ($textA.Contains($mirror[0].new)) { Say "  [=] launcher files -> repo mirror (already done)" 'DarkGray' }
else { Say "  [!] launcher files (not found in this build - skipped)" 'Yellow' }
if ($applied -gt 0) { [System.IO.File]::WriteAllBytes($asar,$enc.GetBytes($textA)) }

# ---- Restore the version list (Feather's game-launcher.feathermc.com host was shut down) ----
# Feather's launch engine honours the VERSION_INDEX env var. Dawn re-hosts the index, but its manifests now
# contain 'linux-arm' entries this engine can't parse, so we use a cleaned mirror (rebuilt every 6h).
# v2 lists Dawn's full cosmetic set, which needs the cosmetics edit above (index/ is for older patches)
$vi = 'https://raw.githubusercontent.com/dtesters/FeatherClient-Patch/main/index/v2/version_index.json'
[Environment]::SetEnvironmentVariable('VERSION_INDEX', $vi, 'User')
Say "  [+] version list source -> $vi" 'Green'

# ---- Carry your per-version mods over to the "-feather" / "-dawn" version names ----
# Versions are now listed as e.g. 1.21.8-feather (original Feather client) and 1.21.8-dawn. The launcher
# keys mod selections and custom mod folders by version name, so copy them (never move or delete).
$featherVersions = @('1.8.9','1.12.2','1.17.1','1.18.2','1.19','1.19.2','1.19.3','1.19.4','1.20','1.20.1',
    '1.20.2','1.20.4','1.20.6','1.21','1.21.1','1.21.3','1.21.4','1.21.5','1.21.7','1.21.8','1.21.10',
    '1.21.11','26.1','26.1.1','26.1.2','26.2')
function Get-NewVersionName([string]$n) {
    if ($n -match '^(.+)-dawn-forge$') { return "$($Matches[1])-dawn" }
    if ($n -match '-(feather|dawn)(-|$)') { return $null }
    if ($n -match '^([\d.]+)-fabric$') {
        if ($featherVersions -contains $Matches[1]) { return "$($Matches[1])-feather-fabric" }
        return "$($Matches[1])-dawn-fabric"
    }
    if ($n -match '^[\d.]+$') {   # legacy names, and versionToLaunch (stored without "-fabric")
        if ($featherVersions -contains $n) { return "$n-feather" }
        return "$n-dawn"
    }
    return $null
}
$moved = 0
$modsFile = Join-Path $env:APPDATA '.feather\mods\feather-mods.json'
if (Test-Path $modsFile) {
    $mj = Get-Content $modsFile -Raw | ConvertFrom-Json
    foreach ($sec in 'addedMods','customAddedMods','modrinthAddedMods','profiles') {
        $o = $mj.$sec
        if (-not $o) { continue }
        foreach ($p in @($o.PSObject.Properties)) {
            $new = Get-NewVersionName $p.Name
            if ($new -and -not $o.PSObject.Properties[$new]) {
                $o | Add-Member -NotePropertyName $new -NotePropertyValue $p.Value; $moved++
            }
        }
    }
    $sv = Get-NewVersionName ([string]$mj.selectedVersion)
    if ($sv) { $mj.selectedVersion = $sv }
    if ($moved -gt 0 -or $sv) {
        if (-not (Test-Path "$modsFile.featherfix.bak")) { Copy-Item $modsFile "$modsFile.featherfix.bak" }
        [System.IO.File]::WriteAllText($modsFile, ($mj | ConvertTo-Json -Depth 32 -Compress))
    }
}
$userMods = Join-Path $env:APPDATA '.feather\user-mods'
if (Test-Path $userMods) {
    foreach ($d in Get-ChildItem $userMods -Directory) {
        $new = Get-NewVersionName $d.Name
        if ($new -and -not (Test-Path (Join-Path $userMods $new))) {
            Copy-Item $d.FullName (Join-Path $userMods $new) -Recurse; $moved++
        }
    }
}
$setFile = Join-Path $env:APPDATA '.feather\settings.json'
if (Test-Path $setFile) {
    $sj = Get-Content $setFile -Raw | ConvertFrom-Json
    $vl = Get-NewVersionName ([string]$sj.versionToLaunch)
    if ($vl) {
        $sj.versionToLaunch = $vl
        [System.IO.File]::WriteAllText($setFile, ($sj | ConvertTo-Json -Depth 8 -Compress))
    }
}
if ($moved -gt 0) { Say "  [+] copied your mods to the new -feather / -dawn version names ($moved)" 'Green' }
else { Say "  [=] mods on the new -feather / -dawn version names (nothing to copy)" 'DarkGray' }

Say "`nDone. Feather is patched - it will stay Feather (no Dawn update, no ads)." 'Cyan'
Say "Open it normally; press Ctrl+Shift+I for DevTools.`n" 'Cyan'
Read-Host "Press Enter to exit"
