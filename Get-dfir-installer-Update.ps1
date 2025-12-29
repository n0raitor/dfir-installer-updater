<# 
    .SYNOPSIS
        Checks whether a newer version of the DFIR installer package is available,
        downloads the zip archive from Backblaze B2, extracts it into a sub‑folder
        called `dfir-installer`, and overwrites only the files that are present
        in the archive.

    .DESCRIPTION
        A local `ver.txt` file (next to this script) now holds **only** the
        semantic version string, e.g.:

            V1.0.3

        The remote repository provides the same format in its `ver.txt`,
        together with:

        • **dfir‑installer.zip** – the installer package (contains a folder
                                   structure that should end up under
                                   `.\dfir-installer\`)  
        • **ChangeLog.txt**    – optional short changelog  

        If the remote version is newer **or** the local `ver.txt` does not exist,
        the zip is downloaded from Backblaze B2, extracted, and the files inside
        the zip are copied into the `dfir-installer` sub‑folder, overwriting
        only those matching files.  The parent folder’s control files
        (`ver.txt`, `ChangeLog.txt`, `Gert‑update.ps1`, …) are left untouched.

    .EXAMPLE
        PS C:\DFIR> .\Get-dfir-installer-Update.ps1

    .NOTES
        Author:  Norman Schmidt  
        Created: 2025‑12‑29
#>

# --------------------------------------------------------------
# Configuration – adjust these URLs if the bucket location ever changes
# --------------------------------------------------------------
$CurrentDirectory   = (Resolve-Path -Path '.').Path
$SubFolderName      = 'dfir-installer'                     # target sub‑folder
$SubFolderPath      = Join-Path $CurrentDirectory $SubFolderName

$LocalVersionFile   = Join-Path $CurrentDirectory 'ver.txt'   # parent‑folder version marker
$ParentChangeLog    = Join-Path $CurrentDirectory 'ChangeLog.txt'   # optional, shown after update
$ParentGertScript   = Join-Path $CurrentDirectory 'Gert-update.ps1' # example extra file

# Backblaze B2 URLs (replace only the bucket/path part if it moves again)
$RemoteVersionUrl   = 'https://f003.backblazeb2.com/file/dfir-installer-bin/ver.txt'
$RemoteZipUrl       = 'https://f003.backblazeb2.com/file/dfir-installer-bin/dfir-installer.zip'
$RemoteChangeLogUrl = 'https://f003.backblazeb2.com/file/dfir-installer-bin/ChangeLog.txt'

# --------------------------------------------------------------
# Helper functions
# --------------------------------------------------------------
function Parse-SemanticVersion {
    <#
        Input:  "V1.0.3"
        Output: [pscustomobject]@{
                    Major      = 1
                    Minor      = 0
                    Patch      = 3
                    Comparable = 10003   # (Major*10000 + Minor*100 + Patch)
                }
    #>
    param([string]$VersionString)

    $pattern = '^V(\d+)\.(\d+)\.(\d+)$'
    if ($VersionString -match $pattern) {
        $major = [int]$Matches[1]
        $minor = [int]$Matches[2]
        $patch = [int]$Matches[3]

        $comparable = ($major * 10000) + ($minor * 100) + $patch
        return [pscustomobject]@{
            Major      = $major
            Minor      = $minor
            Patch      = $patch
            Comparable = $comparable
        }
    } else {
        Write-Host "[!] Unexpected version format: $VersionString" -ForegroundColor Red
        return $null
    }
}

function Get-LocalVersionInfo {
    param([string]$Path)
    if (-not (Test-Path $Path)) { return $null }
    $raw = (Get-Content -Path $Path -Raw -ErrorAction SilentlyContinue).Trim()
    return Parse-SemanticVersion -VersionString $raw
}

function Get-RemoteVersionInfo {
    param([string]$Url)
    try {
        $raw = (Invoke-WebRequest -Uri $Url -UseBasicParsing -ErrorAction Stop).Content.Trim()
        return Parse-SemanticVersion -VersionString $raw
    } catch {
        Write-Host "[!] Failed to retrieve remote version: $_" -ForegroundColor Red
        return $null
    }
}

# --------------------------------------------------------------
# Main execution
# --------------------------------------------------------------

Write-Host "`n=== DFIR Installer Update Utility ===`n" `
           -BackgroundColor DarkCyan -ForegroundColor White

#Read local version info (if any)
$localInfo = Get-LocalVersionInfo -Path $LocalVersionFile
if (-not $localInfo) {
    Write-Host "[*] No local ver.txt found – update will be forced." -ForegroundColor Yellow
    # Dummy very‑old version so the remote version is always newer
    $localInfo = [pscustomobject]@{ Comparable = 0 }
} else {
    Write-Host "[*] Local version: V$($localInfo.Major).$($localInfo.Minor).$($localInfo.Patch)" `
               -ForegroundColor Green
}

# Fetch remote version info
$remoteInfo = Get-RemoteVersionInfo -Url $RemoteVersionUrl
if (-not $remoteInfo) {
    Write-Host "[!] Unable to obtain remote version – aborting." -ForegroundColor Red
    exit 1
}
Write-Host "[*] Remote version: V$($remoteInfo.Major).$($remoteInfo.Minor).$($remoteInfo.Patch)" `
           -ForegroundColor Green

# Compare semantic versions
if ($remoteInfo.Comparable -le $localInfo.Comparable) {
    Write-Host "[*] Your installation is already up‑to‑date. No action required." -ForegroundColor Green
    exit 0
}

# Download the zip archive from Backblaze B2
Write-Host "[*] Newer version detected – downloading zip archive…" -ForegroundColor Yellow
$tempZip = Join-Path $env:TEMP ('dfir-installer_' + [guid]::NewGuid().Guid + '.zip')

try {
    $oldPref = $ProgressPreference
    $ProgressPreference = 'SilentlyContinue'   # suppress progress bar for automation
    Invoke-WebRequest -Uri $RemoteZipUrl -OutFile $tempZip -UseBasicParsing -ErrorAction Stop
    $ProgressPreference = $oldPref
} catch {
    Write-Host "[!] Download failed: $_" -ForegroundColor Red
    exit 1
}

# Extract zip to a temporary location
$tempExtract = Join-Path $env:TEMP ('dfir-installer_extracted_' + [guid]::NewGuid().Guid)
New-Item -ItemType Directory -Path $tempExtract | Out-Null

try {
    Expand-Archive -Path $tempZip -DestinationPath $tempExtract -Force
} catch {
    Write-Host "[!] Extraction failed: $_" -ForegroundColor Red
    Remove-Item -Path $tempZip -Force
    exit 1
}

# Ensure the target sub‑folder exists (create it if missing)
if (-not (Test-Path $SubFolderPath)) {
    New-Item -ItemType Directory -Path $SubFolderPath | Out-Null
    Write-Host "[*] Created missing sub‑folder `.$SubFolderName\`." -ForegroundColor Cyan
}

# Backup existing files **only** inside the sub‑folder
$timestamp = Get-Date -Format 'yyyyMMdd_HHmmss'
$backupRoot = Join-Path $CurrentDirectory ("dfir-installer_backup_$timestamp")
Copy-Item -Path $SubFolderPath -Destination $backupRoot -Recurse -Force
Write-Host "[*] Existing `.$SubFolderName\` folder backed up to:" -ForegroundColor Cyan
Write-Host "    $backupRoot" -ForegroundColor Gray

# Copy only the files that exist in the zip into the sub‑folder
#    (preserve the internal directory structure of the zip)
Get-ChildItem -Path $tempExtract -Recurse -File | ForEach-Object {
    $relativePath = $_.FullName.Substring($tempExtract.Length).TrimStart('\','/')
    $destPath     = Join-Path $SubFolderPath $relativePath

    # Ensure destination directory exists
    $destDir = Split-Path $destPath -Parent
    if (-not (Test-Path $destDir)) {
        New-Item -ItemType Directory -Path $destDir -Force | Out-Null
    }

    # Overwrite the file – this is the only place where files are changed
    Copy-Item -Path $_.FullName -Destination $destPath -Force
}

Write-Host "[*] Files from the zip have been copied into `.$SubFolderName\`." -ForegroundColor Green

# Update the local version file (store the exact string we received from the server)
$remoteRaw = (Invoke-WebRequest -Uri $RemoteVersionUrl -UseBasicParsing -ErrorAction Stop).Content.Trim()
$remoteRaw | Set-Content -Path $LocalVersionFile -Encoding UTF8
Write-Host "[*] Updated local version file:" -ForegroundColor Green
Write-Host "    $LocalVersionFile" -ForegroundColor Gray

# Show a short changelog (first 15 lines) – still from the parent folder
Write-Host "`n[*] Recent changes (first 15 lines):" -ForegroundColor Green
try {
    $changelog = Invoke-WebRequest -Uri $RemoteChangeLogUrl -UseBasicParsing -ErrorAction Stop
    $lines = $changelog.Content -split "`r?`n"
    $max = [Math]::Min(15, $lines.Count)
    for ($i = 0; $i -lt $max; $i++) {
        Write-Host $lines[$i]
    }
} catch {
    Write-Host "[!] Could not retrieve changelog: $_" -ForegroundColor Yellow
}

# Clean up temporary artefacts
Remove-Item -Path $tempZip, $tempExtract -Recurse -Force

# **Delete the backup folder now that the update succeeded**
Remove-Item -Path $backupRoot -Recurse -Force
Write-Host "[*] Backup folder removed (update confirmed successful)." -ForegroundColor Cyan

Write-Host "`n[*] Update successful! Test the installer in the `$SubFolderName\` folder." -ForegroundColor Green

# --------------------------------------------------------------
# OPTIONAL: Authenticode signature placeholder
# --------------------------------------------------------------
# SIG # Begin signature block
# (This block will be replaced automatically by Set‑AuthenticodeSignature)
# SIG # End signature block