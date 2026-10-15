# Patch Feather - keeps Feather working after the Dawn takeover.
# Blocks the Dawn update, removes ads, and restores the version list, mods and in-game menu.
# Safe to run again: it only applies what's missing. Originals are kept as *.featherfix.bak.
# -Auto: no questions, used by the auto-updater.
param([switch]$Auto)
$PatchVersion = '2026.10.14.3'
$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

function Say($m,$c='Gray'){ Write-Host $m -ForegroundColor $c }
function Finish([int]$code=0){ if (-not $Auto) { Read-Host "Press Enter to exit" | Out-Null }; exit $code }
function Ask($q) {
    do { $a = (Read-Host "$q Press Y for yes, N for no").Trim().ToUpper() } until ($a -eq 'Y' -or $a -eq 'N')
    return $a -eq 'Y'
}

Say "`n  Patch Feather $PatchVersion`n" 'Cyan'

$prog = Join-Path $env:LOCALAPPDATA 'Programs\feather'
$exe  = Join-Path $prog 'Feather Launcher.exe'
$asar = Join-Path $prog 'resources\app.asar'

# Last Feather installer (2.6.13). Anything else from that link is probably Dawn, so we refuse it.
$installerSha = 'E36573F9990060E72E3083C949BAA444D1BC96A192C58A9F416B7C96A2494BA0'

function Install-Feather {
    $file = Join-Path $env:LOCALAPPDATA 'feather-updater\installer.exe'
    if ((Test-Path $file) -and (Get-FileHash $file -Algorithm SHA256).Hash -eq $installerSha) {
        Say "Found the Feather installer on this PC."
    } else {
        Say "Downloading Feather from feathermc.com (about 128 MB)..."
        $file = Join-Path $env:TEMP 'FeatherLauncherSetup.exe'
        Invoke-WebRequest -UseBasicParsing -Uri 'https://feathermc.com/download/windows' -OutFile $file
        if ((Get-FileHash $file -Algorithm SHA256).Hash -ne $installerSha) {
            Remove-Item $file -Force
            Say "That download isn't the Feather installer this patch knows (it may be Dawn now). Not installing it." 'Red'
            return $false
        }
    }
    Say "Installing Feather..."
    Start-Process -FilePath $file -ArgumentList '/S' -Wait
    for ($i = 0; $i -lt 30 -and -not (Test-Path $asar); $i++) { Start-Sleep 1 }
    # don't let it run before it's patched, or it updates itself into Dawn
    Start-Sleep 3
    Get-Process -Name 'Feather Launcher' -ErrorAction SilentlyContinue | Stop-Process -Force
    Start-Sleep 2
    return (Test-Path $asar)
}

if (-not (Test-Path $exe) -or -not (Test-Path $asar)) {
    if ($Auto) { Say "Feather isn't installed."; exit 1 }
    Say "Feather isn't installed on this PC." 'Yellow'
    if (-not (Ask "Would you like to install Feather automatically?")) {
        Say "`nGet it from https://feathermc.com/download/windows (close it right after installing), then run this again." 'Yellow'
        Finish 1
    }
    if (-not (Install-Feather)) { Say "Feather couldn't be installed." 'Red'; Finish 1 }
    Say "Feather installed.`n" 'Green'
}

if (Get-Process -Name 'Feather Launcher' -ErrorAction SilentlyContinue) {
    if ($Auto) { Say "Feather is running, the update will apply next time."; exit 0 }
    Get-Process -Name 'Feather Launcher' -ErrorAction SilentlyContinue | Stop-Process -Force
    Start-Sleep -Milliseconds 1500
}

$enc = [System.Text.Encoding]::GetEncoding(28591)   # Latin1: 1 byte = 1 char

# Edit one file inside app.asar when the new text has a different length (fixes the asar header).
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

# Same-length edits
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
  @{ name='custom mods on -feather / -dawn versions';
     old='3}){1,2}(-fabric)?$/'; new='3}){1,2}(-[a-z]+)*$/'; critical=$false },
  @{ name='Modrinth browsing on -feather / -dawn versions';
     old='[(0,_.w)(d.controls.version.value.replace("-fabric",""))]';
     new='[(0,_.w)(d.controls.version.value.split("-")[0]        )]'; critical=$false },
  @{ name='Modrinth mod loading on -feather / -dawn versions';
     old='ue=(0,Ar.w)(o.replace("-fabric",""))'; new='ue=(0,Ar.w)(o.split("-")[0]        )'; critical=$false },
  @{ name='Modrinth mod updates on -feather / -dawn versions';
     old='const g=(0,Ar.w)(u.replace("-fabric",""));'; new='const g=(0,Ar.w)(u.split("-")[0]        );'; critical=$false },
  @{ name='Modrinth mod panel versions on -feather / -dawn versions';
     old='const s=_.loaders.includes(R.AW.Fabric)&&C.mcVersions.hasOwnProperty(h),o=_.loaders.includes("forge")&&C.mcVersions.hasOwnProperty(P);s&&l.add(h),o&&l.add(P)';
     new='for(const[k,q]of Object.entries(C.mcVersions))q.version===P&&_.loaders.includes(q.loader)&&l.add(k)                                                          '; critical=$false },
  @{ name='mod compatibility checks on -feather / -dawn versions (1/3)';
     old='u=f.replace("-fabric",""),p;'; new='u=f.split("-")[0]        ,p;'; critical=$false },
  @{ name='mod compatibility checks on -feather / -dawn versions (2/3)';
     old='u=o.replace("-fabric",""),p;'; new='u=o.split("-")[0]        ,p;'; critical=$false },
  @{ name='mod compatibility checks on -feather / -dawn versions (3/3)';
     old='l=t.replace("-fabric",""),u;'; new='l=t.split("-")[0]        ,u;'; critical=$false },
  @{ name='cosmetics from Dawn''s CDN (all Feather + Dawn cosmetics)';
     old="https://assets.feathercdn.net/`0"; new="https://assets.dawn.gg/assets/`0"; critical=$false }
)

$bytesA = [System.IO.File]::ReadAllBytes($asar)
$textA  = $enc.GetString($bytesA)

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
            Finish 1
        }
        $plan += @{ e=$e; state='missing' }
    }
}
if (-not $anyMatch) {
    Say "This doesn't look like Feather. Nothing was changed.`n" 'Red'
    Finish 1
}

# Electron asar-integrity fuse (sentinel + 38)
$bytesE = [System.IO.File]::ReadAllBytes($exe)
$sidx   = $enc.GetString($bytesE).IndexOf('dL7pKGdnNz796PbbjQWNKmHXBZaB9tsX')
if ($sidx -lt 0) { throw "Couldn't find the Electron fuse marker in the launcher. Nothing changed." }
$fuseOff = $sidx + 38
$fuseVal = $bytesE[$fuseOff]
if ($fuseVal -ne 48 -and $fuseVal -ne 49) { throw "Unexpected fuse byte ($fuseVal). Nothing changed." }

if (-not (Test-Path "$exe.featherfix.bak"))  { Copy-Item $exe  "$exe.featherfix.bak"  -Force }
if (-not (Test-Path "$asar.featherfix.bak")) { Copy-Item $asar "$asar.featherfix.bak" -Force }
Say "Backups: *.featherfix.bak next to the originals`n" 'DarkGray'

if ($fuseVal -eq 49) {
    $fs=[System.IO.File]::Open($exe,'Open','ReadWrite'); $fs.Seek($fuseOff,'Begin')|Out-Null; $fs.WriteByte(48); $fs.Close()
    Say "  [+] disabled asar-integrity fuse" 'Green'
} else { Say "  [=] asar-integrity fuse (already off)" 'DarkGray' }

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

# Mod lists and launcher files from this repo
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

$mirror = @( @{ old='https://electron-launcher.feathermc.com/';
                new='https://raw.githubusercontent.com/dtesters/FeatherClient-Patch/main/mirror/electron-launcher/' } )
$files = 0
while ($null -ne ($resized = Edit-AsarResize $textA $mirror)) { $textA = $resized; $files++; $applied++ }
if ($files -gt 0) { Say "  [+] launcher files -> repo mirror ($files files)" 'Green' }
elseif ($textA.Contains($mirror[0].new)) { Say "  [=] launcher files -> repo mirror (already done)" 'DarkGray' }
else { Say "  [!] launcher files (not found in this build - skipped)" 'Yellow' }
if ($applied -gt 0) { [System.IO.File]::WriteAllBytes($asar,$enc.GetBytes($textA)) }

# In-game menu fallback (agent/)
$agentSrc = Join-Path $PSScriptRoot 'agent\featherfix-agent.jar'
$agentDst = Join-Path $env:APPDATA '.feather\featherfix-agent.jar'
if (Test-Path $agentSrc) {
    New-Item -ItemType Directory -Force (Split-Path $agentDst) | Out-Null
    Copy-Item $agentSrc $agentDst -Force
    # relative path: the launcher splits JVM args on spaces
    $hookNew = 'n=[...(()=>{try{const P=require("path"),F=require("fs"),s=P.join(process.env.APPDATA,".feather","featherfix-agent.jar");if(!F.existsSync(s))return[];const d=P.join(e.mcPath,"feather");F.mkdirSync(d,{recursive:!0});F.copyFileSync(s,P.join(d,"featherfix-agent.jar"));return["-javaagent:feather/featherfix-agent.jar"]}catch{return[]}})(),`-Xmx${e.ram}M`,'
    $hook = @(
      @{ old='n=[...(()=>{try{const p=require("path").join(process.env.APPDATA,".feather","featherfix-agent.jar");return require("fs").existsSync(p)?["-javaagent:"+p]:[]}catch{return[]}})(),`-Xmx${e.ram}M`,'; new=$hookNew },
      @{ old='n=[`-Xmx${e.ram}M`,'; new=$hookNew } )
    $bytesH = [System.IO.File]::ReadAllBytes($asar); $textH = $enc.GetString($bytesH)
    if ($textH.Contains($hookNew)) { Say "  [=] in-game menu fallback (agent updated)" 'DarkGray' }
    elseif ($null -ne ($hooked = Edit-AsarResize $textH $hook)) { [System.IO.File]::WriteAllBytes($asar,$enc.GetBytes($hooked)); Say "  [+] in-game menu fallback (agent installed)" 'Green' }
    else { Say "  [!] in-game menu fallback (launch code not found - skipped)" 'Yellow' }
} else { Say "  [!] in-game menu fallback (agent\featherfix-agent.jar missing next to this script - skipped)" 'Yellow' }

# Version list, set inside Feather only (Dawn's launcher reads the same variable)
$vi = 'https://raw.githubusercontent.com/dtesters/FeatherClient-Patch/main/index/v2/version_index.json'
$viHook = @( @{ old='"use strict";var gx=Object.create;'; new='"use strict";process.env.VERSION_INDEX="' + $vi + '";var gx=Object.create;' } )
$textV = $enc.GetString([System.IO.File]::ReadAllBytes($asar))
if ($textV.Contains($viHook[0].new)) { Say "  [=] version list (already done)" 'DarkGray' }
elseif ($null -ne ($hooked = Edit-AsarResize $textV $viHook)) { [System.IO.File]::WriteAllBytes($asar,$enc.GetBytes($hooked)); Say "  [+] version list" 'Green' }
else { Say "  [!] version list (not found in this build - skipped)" 'Yellow' }
$oldVi = [Environment]::GetEnvironmentVariable('VERSION_INDEX', 'User')
if ($oldVi -like '*FeatherClient-Patch*') {
    [Environment]::SetEnvironmentVariable('VERSION_INDEX', $null, 'User')
    Say "  [+] removed the old system-wide version list setting" 'Green'
}

# Copy mods to the -feather / -dawn version names
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

# Auto-update
$ffDir   = Join-Path $env:APPDATA '.feather\featherfix'
$wsh     = New-Object -ComObject WScript.Shell
$links   = @((Join-Path ([Environment]::GetFolderPath('Desktop')) 'Feather Launcher.lnk'),
             (Join-Path ([Environment]::GetFolderPath('Programs')) 'Feather Launcher.lnk'))
$autoUpdate = $Auto -or (Ask "`nWould you like this patch to update itself automatically?")
if (-not $autoUpdate) {
    foreach ($l in $links) {
        if (Test-Path $l) { $sc = $wsh.CreateShortcut($l); $sc.TargetPath = $exe; $sc.Arguments = ''; $sc.WorkingDirectory = $prog; $sc.Save() }
    }
    if (Test-Path $ffDir) { Remove-Item $ffDir -Recurse -Force }
    Say "  [=] auto-update off: download and run the patch again to get fixes" 'DarkGray'
} else {
    New-Item -ItemType Directory -Force $ffDir | Out-Null
    $updater = @'
# FeatherClient-Patch updater, started by the Feather shortcut.
param([switch]$Launch)
$dir  = Split-Path -Parent $MyInvocation.MyCommand.Path
$log  = Join-Path $dir 'update.log'
$exe  = Join-Path $env:LOCALAPPDATA 'Programs\feather\Feather Launcher.exe'
$repo = 'https://raw.githubusercontent.com/dtesters/FeatherClient-Patch/main/'
function Log($m) { Add-Content -Path $log -Value ("[{0}] {1}" -f (Get-Date -Format s), $m) }
try {
    if ((Test-Path $log) -and (Get-Item $log).Length -gt 512KB) { Remove-Item $log -Force }
    if (Test-Path (Join-Path $dir 'disabled')) { Log 'auto-update disabled (featherfix\disabled exists)' }
    elseif (Get-Process -Name 'Feather Launcher' -ErrorAction SilentlyContinue) { Log 'Feather is already running - not updating now' }
    else {
        [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
        $remote = (Invoke-WebRequest -UseBasicParsing -TimeoutSec 15 -Uri ($repo + 'patch-feather.ps1')).Content
        if ($remote -notmatch "\`$PatchVersion = '([^']+)'") { throw 'no $PatchVersion in the published patch' }
        $rv = $Matches[1]
        $lv = if (Test-Path (Join-Path $dir 'version.txt')) { (Get-Content (Join-Path $dir 'version.txt') -Raw).Trim() } else { '' }
        $newer = try { [version]$rv -gt [version]$lv } catch { $rv -ne $lv }
        if (-not $newer) { Log "up to date ($lv)" }
        else {
            $tmp = Join-Path $env:TEMP ('featherfix-' + [guid]::NewGuid().ToString('N'))
            New-Item -ItemType Directory -Force (Join-Path $tmp 'agent') | Out-Null
            [IO.File]::WriteAllText((Join-Path $tmp 'patch-feather.ps1'), $remote)
            Invoke-WebRequest -UseBasicParsing -TimeoutSec 30 -Uri ($repo + 'agent/featherfix-agent.jar') -OutFile (Join-Path $tmp 'agent\featherfix-agent.jar')
            $out = & powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $tmp 'patch-feather.ps1') -Auto 2>&1 | Out-String
            Log "update $lv -> $rv (exit $LASTEXITCODE)`r`n$out"
            Remove-Item $tmp -Recurse -Force -ErrorAction SilentlyContinue
        }
    }
} catch { Log "update check failed: $($_.Exception.Message)" }
if ($Launch -and (Test-Path $exe)) { Start-Process -FilePath $exe -WorkingDirectory (Split-Path $exe) }
'@
    [IO.File]::WriteAllText((Join-Path $ffDir 'featherfix-update.ps1'), $updater)
    $vbs = 'Set f = CreateObject("Scripting.FileSystemObject")' + "`r`n" +
           'CreateObject("WScript.Shell").Run "powershell.exe -NoProfile -WindowStyle Hidden -ExecutionPolicy Bypass -File """ & f.GetParentFolderName(WScript.ScriptFullName) & "\featherfix-update.ps1"" -Launch", 0, False' + "`r`n"
    [IO.File]::WriteAllText((Join-Path $ffDir 'launch.vbs'), $vbs)
    foreach ($l in $links) {
        New-Item -ItemType Directory -Force (Split-Path $l) | Out-Null
        $sc = $wsh.CreateShortcut($l)
        $sc.TargetPath = Join-Path $env:WINDIR 'System32\wscript.exe'
        $sc.Arguments = '"' + (Join-Path $ffDir 'launch.vbs') + '"'
        $sc.WorkingDirectory = $prog
        $sc.IconLocation = "$exe,0"
        $sc.Description = 'Feather Launcher (auto-updates FeatherClient-Patch)'
        $sc.Save()
    }
    Say "  [+] auto-update on (open Feather from its Desktop or Start Menu shortcut)" 'Green'
}
if ($autoUpdate) { [IO.File]::WriteAllText((Join-Path $ffDir 'version.txt'), $PatchVersion) }

Say "`nDone. Feather is patched." 'Cyan'
Say "Help and updates: https://discord.gg/RBUwmddb7s`n" 'Cyan'
Finish 0
