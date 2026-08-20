param(
    [string]$Version = "00.00.15"
)

$ErrorActionPreference = "Stop"

$RepoRoot = Split-Path -Parent $PSScriptRoot
$SourceDir = Join-Path $RepoRoot "src\Jacaranda2FA"
$DistDir = Join-Path $RepoRoot "dist"
$StageDir = Join-Path $env:TEMP ("Jacaranda2FA-build-" + [Guid]::NewGuid().ToString("N"))
$OutputZip = Join-Path $DistDir ("Jacaranda2FA_{0}_Install.zip" -f $Version)

if (-not (Test-Path $SourceDir)) {
    throw "Source directory not found: $SourceDir"
}

New-Item -ItemType Directory -Force -Path $DistDir | Out-Null
New-Item -ItemType Directory -Force -Path $StageDir | Out-Null

try {
    Copy-Item -Path (Join-Path $SourceDir "*") -Destination $StageDir -Recurse -Force

    $Manifest = Join-Path $StageDir "Jacaranda2FA.dnn"
    if (-not (Test-Path $Manifest)) {
        throw "Jacaranda2FA.dnn was not found in the source directory."
    }

    # Keep the package version in the manifest aligned with the requested build version.
    $ManifestText = Get-Content -Raw -Path $Manifest
    $ManifestText = [regex]::Replace(
        $ManifestText,
        '(package name="ForrestITServices\.Jacaranda2FA" type="Auth_System" version=")[^"]+("\s*>)',
        ('$1' + $Version + '$2'),
        1
    )
    Set-Content -Path $Manifest -Value $ManifestText -Encoding UTF8

    if (Test-Path $OutputZip) {
        Remove-Item $OutputZip -Force
    }

    Compress-Archive -Path (Join-Path $StageDir "*") -DestinationPath $OutputZip -CompressionLevel Optimal
    Write-Host "Created: $OutputZip"
}
finally {
    if (Test-Path $StageDir) {
        Remove-Item $StageDir -Recurse -Force
    }
}
