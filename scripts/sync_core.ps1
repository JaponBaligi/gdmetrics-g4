# Sync shared core modules FROM gdmetrics-g4 (canonical) TO gdmetrics-g3.
# Usage:
#   .\scripts\sync_core.ps1
#   .\scripts\sync_core.ps1 -SourceRoot "D:\gdmetrics-g4" -DestRoot "D:\gdmetrics-g3"
#   .\scripts\sync_core.ps1 -WhatIf

param(
	[string]$SourceRoot = "D:\gdmetrics-g4",
	[string]$DestRoot = "D:\gdmetrics-g3",
	[switch]$WhatIf
)

$ErrorActionPreference = "Stop"

$CoreFiles = @(
	"cc_calculator.gd",
	"cog_complexity_calculator.gd",
	"confidence_calculator.gd",
	"control_flow_detector.gd",
	"function_detector.gd",
	"class_detector.gd",
	"threshold_gate.gd",
	"history_store.gd",
	"error_codes.gd",
	"error_summary.gd",
	"logger.gd"
)

$relCore = "addons\gdscript_complexity\src\core"
$srcDir = Join-Path $SourceRoot $relCore
$dstDir = Join-Path $DestRoot $relCore

if (-not (Test-Path $srcDir)) {
	throw "Canonical core directory not found: $srcDir"
}

Write-Host "Canonical source (g4): $srcDir"
Write-Host "Destination (g3):      $dstDir"

if (-not $WhatIf) {
	New-Item -ItemType Directory -Force -Path $dstDir | Out-Null
}

$copied = 0
foreach ($name in $CoreFiles) {
	$from = Join-Path $srcDir $name
	$to = Join-Path $dstDir $name
	if (-not (Test-Path $from)) {
		Write-Warning "Missing in source: $from"
		continue
	}
	if ($WhatIf) {
		Write-Host "[WhatIf] Copy $name"
	} else {
		Copy-Item -Force $from $to
		Write-Host "Copied $name"
	}
	$copied++
}

# Remove stale copies left at src/ root in g3 (pre-core layout)
$staleRoot = Join-Path $DestRoot "addons\gdscript_complexity\src"
foreach ($name in $CoreFiles) {
	$stale = Join-Path $staleRoot $name
	if (Test-Path $stale) {
		if ($WhatIf) {
			Write-Host "[WhatIf] Remove stale $stale"
		} else {
			Remove-Item -Force $stale
			Write-Host "Removed stale src/$name"
		}
	}
}

Write-Host ""
Write-Host "Done. Synced $copied core file(s). g4 is canonical; re-run after editing core/ in g4."
Write-Host "After sync, update g3 load() paths if they still point at src/<module>.gd (not src/core/)."
