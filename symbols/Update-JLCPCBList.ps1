<# 
.SYNOPSIS
  Backup existing CSV in the same folder as this script, then download the new one.
#>

$ErrorActionPreference = 'Stop'

# Script directory
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Definition

# File names
$fileName   = "jlcpcb-components-basic-preferred.csv"
$destination = Join-Path $scriptDir $fileName
$timestamp   = Get-Date -Format "yyyyMMdd-HHmmss"
$backupFile  = Join-Path $scriptDir ("{0}.{1}.bak" -f $fileName, $timestamp)

# Source URL
$url = "https://cdfer.github.io/jlcpcb-parts-database/jlcpcb-components-basic-preferred.csv"

try {
    # Backup if file exists
    if (Test-Path $destination) {
        Copy-Item $destination $backupFile -Force
        Write-Host "Backed up $fileName to $backupFile"
    } else {
        Write-Host "No existing $fileName found. Skipping backup."
    }

    # Download new file to temp first
    $tempFile = [System.IO.Path]::GetTempFileName()
    try {
        try { [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12 } catch {}

        Write-Host "Downloading new version..."
        Invoke-WebRequest -Uri $url -OutFile $tempFile -UseBasicParsing

        Move-Item $tempFile $destination -Force
        Write-Host "Updated $fileName in $scriptDir"
    }
    finally {
        if (Test-Path $tempFile) { Remove-Item $tempFile -Force -ErrorAction SilentlyContinue }
    }
}
catch {
    Write-Error "Update failed: $($_.Exception.Message)"
}
