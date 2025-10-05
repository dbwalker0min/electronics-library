param(
  [string]$KiCadVersion = "9.0",             # 7.0 / 8.0 / 9.0
  [string]$VarName = "KILIB_DIR",            # what we set for your repo root
  [string]$VarValue = ""                     # leave blank to auto = repo root
)

$ErrorActionPreference = "Stop"

# Resolve repo root (script's parent -> repo root)
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$RepoRoot  = (Resolve-Path (Join-Path $ScriptDir "..")).Path
if ([string]::IsNullOrWhiteSpace($VarValue)) { $VarValue = $RepoRoot }

# KiCad config dir
$AppData = [Environment]::GetFolderPath("ApplicationData")  # %APPDATA%
$CfgDir  = Join-Path $AppData "kicad\$KiCadVersion"
New-Item -ItemType Directory -Force -Path $CfgDir | Out-Null
$CommonFile = Join-Path $CfgDir "kicad_common.json"

# Read or init JSON
if (Test-Path $CommonFile) {
  $backup = "$CommonFile.bak.$(Get-Date -Format 'yyyyMMdd-HHmmss')"
  Copy-Item $CommonFile $backup -Force
  $json = Get-Content $CommonFile -Raw | ConvertFrom-Json
} else {
  $json = [pscustomobject]@{}
}

function Ensure-EnvVar {
  param([object]$Root, [string]$Key, [string]$Value)

  # Helper: set $obj[$Key] or add NoteProperty if it's a PSCustomObject
  function Set-Dynamic {
    param([object]$obj, [string]$k, [string]$v)
    if ($obj -is [hashtable]) {
      $obj[$k] = $v
    } elseif ($obj -is [System.Collections.IDictionary]) {
      $obj[$k] = $v
    } elseif ($obj -is [pscustomobject]) {
      if ($obj.PSObject.Properties.Name -contains $k) {
        $obj.$k = $v
      } else {
        $obj | Add-Member -NotePropertyName $k -NotePropertyValue $v -Force
      }
    } else {
      # fallback: turn it into a hashtable
      $ht = @{}
      $obj | Get-Member -MemberType NoteProperty | ForEach-Object { $ht[$_.Name] = $obj.$($_.Name) }
      $ht[$k] = $v
      return $ht
    }
    return $obj
  }

  # Case 1: old style "environment": { "vars": { ... } }
  if ($Root.PSObject.Properties.Name -contains "environment") {
    if (-not ($Root.environment.PSObject.Properties.Name -contains "vars")) {
      $Root.environment | Add-Member -NotePropertyName vars -NotePropertyValue (@{}) -Force
    }
    $Root.environment.vars = Set-Dynamic $Root.environment.vars $Key $Value
    return
  }

  # Case 2: new style "env": { ... }
  if ($Root.PSObject.Properties.Name -contains "env") {
    if ($Root.env -eq $null) { $Root.env = @{} }
    $Root.env = Set-Dynamic $Root.env $Key $Value
    return
  }

  # Neither exists -> prefer new style "env"
  $Root | Add-Member -NotePropertyName env -NotePropertyValue (@{}) -Force
  $Root.env = Set-Dynamic $Root.env $Key $Value
}

# Set or update the variable
[void](Ensure-EnvVar -Root $json -Key $VarName -Value $VarValue)

# Write JSON (preserve depth)
($json | ConvertTo-Json -Depth 20) | Set-Content -Encoding UTF8 $CommonFile

# Optional: wire tables from repo to global (symlink if possible; else copy)
$RepoSym = Join-Path $RepoRoot "tables\sym-lib-table"
$RepoFp  = Join-Path $RepoRoot "tables\fp-lib-table"
$UserSym = Join-Path $CfgDir "sym-lib-table"
$UserFp  = Join-Path $CfgDir "fp-lib-table"

function New-OrReplace-LinkOrCopy {
  param([string]$Source, [string]$Dest)
  if (Test-Path $Dest) { Remove-Item $Dest -Force }
  try { New-Item -ItemType SymbolicLink -Path $Dest -Target $Source | Out-Null }
  catch { Copy-Item $Source $Dest -Force }
}

if (Test-Path $RepoSym) { New-OrReplace-LinkOrCopy -Source $RepoSym -Dest $UserSym }
if (Test-Path $RepoFp)  { New-OrReplace-LinkOrCopy -Source $RepoFp  -Dest $UserFp  }

Write-Host "Updated $CommonFile"
Write-Host "  $VarName = $VarValue"
if (Test-Path $UserSym) { Write-Host "  sym-lib-table => $UserSym" }
if (Test-Path $UserFp)  { Write-Host "  fp-lib-table  => $UserFp" }
