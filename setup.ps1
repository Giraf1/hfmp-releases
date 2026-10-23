# HighFleet MP test kit - client (friend's PC) setup.
# Makes a SEPARATE copy of your Steam HighFleet, installs the test DLL into that copy only.
# Your Steam installation and saves are not modified.
#   powershell -ExecutionPolicy Bypass -File setup.ps1 -HostIp 100.64.0.1 -Key <session word from the host>
param(
    [Parameter(Mandatory = $true)][string]$HostIp,
    [string]$Key = '',   # shared session key (same as key= in the host's hfdiag_net.txt); packets without it are dropped
    [string]$Lab = "$env:USERPROFILE\HighFleetMP\HighFleet"
)
$ErrorActionPreference = 'Stop'
$kit = $PSScriptRoot
$exeSha = '15BD7600581E6018088CDD57C9DE61453AB14F935295237516E34EE4D2689432'   # Steam 1.163
$bassSha = '4BBB323F48FA7EA549ABD59ECFC30E71B574D20F52E295B7E3EBF19F07F53EFE'  # original bass.dll

# 1. Find HighFleet in the Steam libraries
$steam = (Get-ItemProperty 'HKCU:\Software\Valve\Steam' -ErrorAction SilentlyContinue).SteamPath
if (-not $steam) { throw 'Steam not found (HKCU\Software\Valve\Steam).' }
$libs = @($steam.Replace('/', '\'))
$vdf = Join-Path $steam 'steamapps\libraryfolders.vdf'
if (Test-Path $vdf) {
    $libs += Select-String -Path $vdf -Pattern '"path"\s+"([^"]+)"' | ForEach-Object { $_.Matches[0].Groups[1].Value.Replace('\\', '\') }
}
$game = $libs | ForEach-Object { Join-Path $_ 'steamapps\common\HighFleet' } | Where-Object { Test-Path (Join-Path $_ 'Highfleet.exe') } | Select-Object -First 1
if (-not $game) { throw "HighFleet not found in Steam libraries: $($libs -join ', ')" }
Write-Host "HighFleet: $game"

# 2. Version check - the DLL only works with Steam 1.163
$sha = (Get-FileHash (Join-Path $game 'Highfleet.exe')).Hash
if ($sha -ne $exeSha) { throw "Unsupported Highfleet.exe ($sha). Need Steam version 1.163." }
if ((Get-FileHash (Join-Path $game 'bass.dll')).Hash -ne $bassSha) { throw 'bass.dll in the Steam folder is not the original (mod loader installed?).' }

# 3. Separate copy (no Steam Cloud markers, no logs)
if (Get-Process Highfleet -ErrorAction SilentlyContinue) { throw 'Close HighFleet first.' }
New-Item -ItemType Directory -Force $Lab | Out-Null
robocopy $game $Lab /E /R:1 /W:1 /NFL /NDL /NP /NJH /NJS /XF steam_autocloud.vdf *.log | Out-Null
if ($LASTEXITCODE -ge 8) { throw "robocopy failed ($LASTEXITCODE)" }

# 4. DLL: original bass.dll -> bass_hf.dll, test DLL -> bass.dll
if (-not (Test-Path (Join-Path $Lab 'bass_hf.dll'))) { Move-Item (Join-Path $Lab 'bass.dll') (Join-Path $Lab 'bass_hf.dll') }
Copy-Item -Force (Join-Path $kit 'bass.dll') (Join-Path $Lab 'bass.dll')
$man = Join-Path $kit 'manifest.json'   # present in the hfmp-releases download; run.ps1 shows it and updates from it
if (Test-Path $man) { $m = Get-Content -Raw $man | ConvertFrom-Json; Set-Content -Encoding ascii (Join-Path $Lab 'hfmp_version.txt') "$($m.version) git $($m.git)" }

# 5. Settings: run from this folder (not via Steam), client role, host address, label, test aids
Set-Content -NoNewline -Encoding ascii (Join-Path $Lab 'steam_appid.txt') '1434950'
foreach ($f in 'hfdiag_unlock_skirmish', 'hfdiag_ship_probe', 'hfdiag_mirror_client', 'hfdiag_client_invuln', 'hfdiag_unlock_fleet', 'hfdiag_part_sync', 'hfdiag_log_stream', 'hfdiag_terrain_sync') {
    Set-Content -Encoding ascii (Join-Path $Lab "$f.txt") 'on'
}
Set-Content -Encoding ascii (Join-Path $Lab 'hfdiag_ship_net.txt') 'client'   # ship exchange before the battle (UDP, host port 47801)
Set-Content -Encoding ascii (Join-Path $Lab 'hfdiag_client_keys.txt') 'wasd'   # WASD moves, mouse aims/fires
Remove-Item -ErrorAction SilentlyContinue (Join-Path $Lab 'hfdiag_label.txt')   # no overlay label
Remove-Item -ErrorAction SilentlyContinue (Join-Path $Lab 'hfdiag_godmode.txt')   # test aid, not for PvP (audit stop-list)
$netText = "bind=0.0.0.0`r`npeer=$HostIp"
if ($Key) { $netText += "`r`nkey=$Key" } else { Write-Warning 'No -Key: the connection works only if the host has no key either.' }
Set-Content -Encoding ascii (Join-Path $Lab 'hfdiag_net.txt') $netText
Write-Host "Ready: $Lab"
Write-Host "Start with: powershell -ExecutionPolicy Bypass -File `"$kit\run.ps1`""
