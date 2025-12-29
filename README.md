# dfir-installer-updater
PowerShell Script to update the DFIR-Installer Tool

Run the PowerShell Script / File t oget the latest version of the DFIR-Installer from [my Repository](https://github.com/n0raitor/dfir-installer)
Create the Directory: C:\DFIR\_dfir-installer\" and run the Script inside this folder:

For better integration in the update script of the dfir-installer, place it into this location:
```powershell
New-Item -Path 'C:\DFIR\_dfir-installer' -ItemType Directory -Force
Set-Location 'C:\DFIR\_dfir-installer'
Invoke-WebRequest -Uri 'https://raw.githubusercontent.com/n0raitor/dfir-installer-updater/refs/heads/main/Get-dfir-installer-Update.ps1' -OutFile ./Get-dfir-installer-Update.ps1
```
Follow the dfir-installer tutorial up to point 5.:
https://github.com/n0raitor/dfir-installer/blob/main/README.md

```powershell
& 'C:\Program Files\PowerShell\7\pwsh.exe' -ExecutionPolicy Bypass .\Get-dfir-installer-Update.ps1
```

This Script will only update the Script files of the DFIR-Installer. The Configurations and Presets can get synced using the DFIR-Installer Script (Rely on GitHub Repo "DFIR-Installer-Files".

For more information about the Usage of the DFIR-Installer, feel free to read the [README.md](https://github.com/n0raitor/dfir-installer/blob/main/README.md) 
