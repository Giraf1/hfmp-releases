# HighFleet MP test kit - starts the test copy made by setup.ps1.
# Before the start it checks https://github.com/Giraf1/hfmp-releases for a newer test DLL: the new bass.dll is
# installed only if its SHA-256 matches manifest.json; without internet (or on a mismatch) the current DLL stays.
#   powershell -ExecutionPolicy Bypass -File run.ps1            (-NoUpdate skips the check)
param(
    [string]$Lab = "$env:USERPROFILE\HighFleetMP\HighFleet",
    [switch]$NoUpdate
)
$ErrorActionPreference = 'Stop'
$releases = 'https://raw.githubusercontent.com/Giraf1/hfmp-releases/main'
if (-not (Test-Path (Join-Path $Lab 'steam_appid.txt'))) { throw "Run setup.ps1 first ($Lab)." }
if (Get-Process Highfleet -ErrorAction SilentlyContinue) { throw 'HighFleet is already running.' }

# 1. Update the test DLL (never fatal: any problem -> keep the installed one)
$dll = Join-Path $Lab 'bass.dll'
$verFile = Join-Path $Lab 'hfmp_version.txt'
$local = (Get-FileHash $dll).Hash
if (-not $NoUpdate) {
    try {
        [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
        $m = Invoke-RestMethod -UseBasicParsing -TimeoutSec 15 "$releases/manifest.json?t=$([DateTime]::UtcNow.Ticks)"
        if (-not ($m.sha256 -match '^[0-9a-fA-F]{64}$') -or -not $m.version) { throw 'manifest.json has no version/sha256' }
        if ($m.sha256.ToUpper() -eq $local) {
            Write-Host "DLL is up to date: $($m.version) (git $($m.git))"
        } else {
            Write-Host "Downloading DLL $($m.version) (git $($m.git))..."
            $tmp = "$dll.download"
            Invoke-WebRequest -UseBasicParsing -TimeoutSec 60 "$releases/bass.dll?t=$([DateTime]::UtcNow.Ticks)" -OutFile $tmp
            $got = (Get-FileHash $tmp).Hash
            if ($got -ne $m.sha256.ToUpper()) {
                Remove-Item -Force $tmp
                throw "SHA-256 mismatch (got $got, manifest $($m.sha256))"
            }
            Copy-Item -Force $dll "$dll.previous"   # one step back, by hand: rename bass.dll.previous to bass.dll
            Move-Item -Force $tmp $dll
            Set-Content -Encoding ascii $verFile "$($m.version) git $($m.git)"
            Write-Host "Updated to $($m.version). Notes: $($m.notes)"
        }
    } catch {
        Write-Warning "Update check failed, keeping the installed DLL: $($_.Exception.Message)"
    }
}
if (Test-Path $verFile) { Write-Host "DLL: $(Get-Content $verFile -TotalCount 1), sha256 $((Get-FileHash $dll).Hash)" }
else { Write-Host "DLL sha256 $((Get-FileHash $dll).Hash)" }

# 2. Start the test copy (steam_appid.txt keeps SteamStub from relaunching the Steam copy)
$p = Start-Process -PassThru -WorkingDirectory $Lab (Join-Path $Lab 'Highfleet.exe')
Start-Sleep 8
$bad = Get-Process Highfleet -ErrorAction SilentlyContinue | Where-Object { $_.Path -notlike "$Lab*" }
if ($bad) { $bad | Stop-Process -Force; throw 'The Steam copy started instead of the test copy - stopped it. Is Steam running?' }
if ($p.HasExited) { throw "The game exited early (code $($p.ExitCode))." }
Write-Host "Running (pid $($p.Id)). Log: $(Join-Path $Lab 'hfdiag.log')"
