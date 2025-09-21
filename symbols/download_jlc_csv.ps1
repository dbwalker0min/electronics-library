$ErrorActionPreference = "Stop"

$url      = "https://cdfer.github.io/jlcpcb-parts-database/jlcpcb-components-basic-preferred.csv"
$dest     = Join-Path $PSScriptRoot "jlcpcb-components-basic-preferred.csv"
$etagFile = "$dest.etag"

Write-Host "URL: $url"
Write-Host "Destination: $dest"

# Build conditional headers (prefer ETag; fall back to If-Modified-Since)
$headers = @{}
if (Test-Path $etagFile) {
  $headers["If-None-Match"] = (Get-Content $etagFile -Raw)
} elseif (Test-Path $dest) {
  $headers["If-Modified-Since"] = (Get-Item $dest).LastWriteTimeUtc.ToString("R")
}

try {
  # PS 5.1: non-2xx can throw; PS 7: usually too, unless -SkipHttpErrorCheck
  $resp = Invoke-WebRequest -Uri $url -Headers $headers -OutFile $dest -MaximumRedirection 5 -TimeoutSec 30 -ErrorAction Stop

  # Got a fresh 200 OK
  Write-Host "Downloaded."
  if ($resp.Headers.ETag) {
    Set-Content -Path $etagFile -Value $resp.Headers.ETag -NoNewline
  }
  if ($resp.Headers.'Last-Modified') {
    # Preserve server timestamp on the file
    (Get-Item $dest).LastWriteTime = [DateTime]::Parse($resp.Headers.'Last-Modified')
  }
}
catch [System.Net.WebException] {
  # PS 5.1: 304 bubbles up as a WebException with a Response
  $r = $_.Exception.Response
  if ($r -and $r.StatusCode -eq 304) {
    Write-Host "(not modified)"
  } else {
    throw
  }
}
