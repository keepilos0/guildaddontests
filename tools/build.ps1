param(
    [string]$Version = "0.2.0-alpha.1"
)

$ErrorActionPreference = "Stop"
$ProjectRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot "..")).Path
$AddonSource = (Resolve-Path -LiteralPath (Join-Path $ProjectRoot "GuildHubClassic")).Path
$DistRoot = Join-Path $ProjectRoot "dist"
$StageRoot = Join-Path $DistRoot "stage"
$StageAddon = Join-Path $StageRoot "GuildHubClassic"
$ArchivePath = Join-Path $DistRoot ("GuildHubClassic-" + $Version + ".zip")

if (-not $AddonSource.StartsWith($ProjectRoot, [System.StringComparison]::OrdinalIgnoreCase)) {
    throw "Addon source resolved outside the project root."
}

New-Item -ItemType Directory -Force -Path $DistRoot | Out-Null
if (Test-Path -LiteralPath $StageRoot) {
    $resolvedStage = (Resolve-Path -LiteralPath $StageRoot).Path
    if (-not $resolvedStage.StartsWith($DistRoot, [System.StringComparison]::OrdinalIgnoreCase)) {
        throw "Refusing to clear a staging directory outside dist."
    }
    Remove-Item -LiteralPath $resolvedStage -Recurse -Force
}
if (Test-Path -LiteralPath $ArchivePath) {
    Remove-Item -LiteralPath $ArchivePath -Force
}

New-Item -ItemType Directory -Force -Path $StageAddon | Out-Null
Copy-Item -Path (Join-Path $AddonSource "*") -Destination $StageAddon -Recurse -Force
Compress-Archive -LiteralPath $StageAddon -DestinationPath $ArchivePath -CompressionLevel Optimal
Remove-Item -LiteralPath $StageRoot -Recurse -Force

Add-Type -AssemblyName System.IO.Compression.FileSystem
$Zip = [System.IO.Compression.ZipFile]::OpenRead($ArchivePath)
$Entries = @($Zip.Entries | ForEach-Object { $_.FullName.Replace('\', '/') })
$Zip.Dispose()
if ($Entries -notcontains "GuildHubClassic/GuildHubClassic.toc") {
    throw "Package does not contain GuildHubClassic/GuildHubClassic.toc."
}
if ($Entries -contains "GuildHubClassic/GuildHubClassic/GuildHubClassic.toc") {
    throw "Package contains an extra nested GuildHubClassic folder."
}

Write-Output $ArchivePath
