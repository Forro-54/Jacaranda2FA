param(
    [string]$Version = "00.00.20"
)

$ErrorActionPreference = "Stop"
$repo = Split-Path -Parent $PSScriptRoot
$source = Join-Path $repo "src\Jacaranda2FA"
$dist = Join-Path $repo "dist"
$outFile = Join-Path $dist ("Jacaranda2FA_{0}_Install.zip" -f $Version)

if (-not (Test-Path $source)) {
    throw "Source folder not found: $source"
}

if (Test-Path $dist) {
    Remove-Item $dist -Recurse -Force
}
New-Item -ItemType Directory -Path $dist | Out-Null

$staging = Join-Path ([System.IO.Path]::GetTempPath()) ("Jacaranda2FA-" + [Guid]::NewGuid().ToString("N"))
New-Item -ItemType Directory -Path $staging | Out-Null

try {
    $files = @(
        "Login.ascx",
        "Login.css",
        "Settings.ascx",
        "Jacaranda2FA.dnn",
        "README-TESTING.txt",
        "releasenotes.txt",
        "license.txt",
        "App_LocalResources\Login.ascx.resx",
        "App_LocalResources\Settings.ascx.resx",
        "Providers\DataProviders\SqlDataProvider\00.00.16.SqlDataProvider",
        "Providers\DataProviders\SqlDataProvider\Uninstall.SqlDataProvider"
    )

    foreach ($relative in $files) {
        $src = Join-Path $source $relative
        if (-not (Test-Path $src)) {
            throw "Package file not found: $src"
        }

        $dest = Join-Path $staging $relative
        $destDir = Split-Path -Parent $dest
        if (-not (Test-Path $destDir)) {
            New-Item -ItemType Directory -Path $destDir -Force | Out-Null
        }
        Copy-Item $src $dest
    }

    Compress-Archive -Path (Join-Path $staging "*") -DestinationPath $outFile -CompressionLevel Optimal
    Write-Host "Created $outFile"
}
finally {
    if (Test-Path $staging) {
        Remove-Item $staging -Recurse -Force
    }
}
