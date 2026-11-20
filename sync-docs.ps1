# Copies the plugin user guides from the Unreal project into this site.
# The plugins' Docs folders are the source of truth: edit there, then run this and commit.
# Only the user guides are public. The C++ references (*-CPP.md) ship with the plugins and are never copied here.
param(
    [string]$Project = "C:\Users\sride\Documents\Unreal Projects\VehicleExperiment"
)

$site = $PSScriptRoot
$sources = @(
    "$Project\Plugins\VehicleAmphibious\Docs\VehicleAmphibious.md"
    # not published yet: "$Project\Plugins\VehicleMechanicsPack\Docs\VehicleMechanicsPack.md"
)

foreach ($file in $sources) {
    if (-not (Test-Path $file)) {
        Write-Error "Missing: $file"
        exit 1
    }
    Copy-Item $file -Destination $site -Force
    Write-Output "Copied $(Split-Path $file -Leaf)"
}
