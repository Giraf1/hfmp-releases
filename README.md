# HighFleet MP — test builds

Experimental multiplayer test DLL for **HighFleet (Steam 1.163)**. Not affiliated with the developers.
Source and research: private repository (ask the host).

- `bass.dll` — the current test DLL (a proxy for the game's `bass.dll`; installed only into a separate copy of the game).
- `manifest.json` — version, git commit and SHA-256 of `bass.dll`. `run.ps1` downloads a new DLL only when its
  SHA-256 matches this file.
- `setup.ps1`, `run.ps1`, `README_UA.txt` — the friend kit. Instructions (Ukrainian): `README_UA.txt`.

Quick start: Code → Download ZIP, unzip, then in PowerShell in that folder:

```
powershell -ExecutionPolicy Bypass -File setup.ps1 -HostIp <host IP> -Key <session key>
powershell -ExecutionPolicy Bypass -File run.ps1
```

`setup.ps1` makes a separate copy of the game in `%USERPROFILE%\HighFleetMP\HighFleet`; the Steam installation
and saves are not modified. Every build here was run locally by the host before publishing.
