param(
    [string]$Godot = $env:GODOT
)

$ErrorActionPreference = "Stop"
$ProjectDir = Split-Path -Parent $PSScriptRoot

function Resolve-GodotExecutable {
    if ($Godot -and (Test-Path -LiteralPath $Godot)) {
        return (Resolve-Path -LiteralPath $Godot).Path
    }

    $command = Get-Command godot, godot4 -ErrorAction SilentlyContinue |
        Select-Object -First 1
    if ($command) {
        return $command.Source
    }

    $downloads = Join-Path $HOME "Downloads"
    if (Test-Path -LiteralPath $downloads) {
        $portable = Get-ChildItem -LiteralPath $downloads -File -Recurse -ErrorAction SilentlyContinue |
            Where-Object { $_.Name -match '^Godot.*_console\.exe$' } |
            Sort-Object LastWriteTime -Descending |
            Select-Object -First 1
        if ($portable) {
            return $portable.FullName
        }
    }

    throw "Godot executable not found. Pass -Godot <path> or set GODOT."
}

function Invoke-GodotCheck {
    param(
        [string]$Name,
        [string[]]$Arguments,
        [string]$SuccessMarker
    )

    $logPath = Join-Path $env:TEMP ("pastoral_tales_{0}_{1}.log" -f $Name, $PID)
    try {
        & $script:GodotExe @Arguments --log-file $logPath
        $exitCode = $LASTEXITCODE
        $log = if (Test-Path -LiteralPath $logPath) {
            Get-Content -LiteralPath $logPath -Raw
        } else {
            ""
        }

        $errorPattern = '(?m)^(SCRIPT ERROR|ERROR:|FATAL)|Compile Error|Parse Error|Nonexistent function|Invalid call|failed to load|Failed to'
        if ($exitCode -ne 0) {
            throw "$Name exited with code $exitCode.`n$log"
        }
        if ($log -match $errorPattern) {
            throw "$Name emitted script/runtime errors.`n$log"
        }
        if ($SuccessMarker -and $log -notmatch [regex]::Escape($SuccessMarker)) {
            throw "$Name did not emit '$SuccessMarker'.`n$log"
        }

        Write-Host ("  OK  {0}" -f $Name) -ForegroundColor Green
    } finally {
        Remove-Item -LiteralPath $logPath -ErrorAction SilentlyContinue
    }
}

$script:GodotExe = Resolve-GodotExecutable
Write-Host "[check] Godot: $script:GodotExe"
Write-Host "[check] Project: $ProjectDir"

$python = Get-Command python, py -ErrorAction SilentlyContinue | Select-Object -First 1
if (-not $python) {
    throw "Python executable not found; resource sitemap cannot be generated."
}
& $python.Source (Join-Path $ProjectDir "tools\generate_resource_sitemap.py") `
    --project-root $ProjectDir `
    --output (Join-Path $ProjectDir "data\resource_sitemap.json")
if ($LASTEXITCODE -ne 0) {
    throw "Resource sitemap generation failed with code $LASTEXITCODE."
}
Write-Host "  OK  Resource sitemap" -ForegroundColor Green

& $python.Source (Join-Path $ProjectDir "tools\verify_delivery_contract.py")
if ($LASTEXITCODE -ne 0) {
    throw "Delivery contract verification failed with code $LASTEXITCODE."
}
Write-Host "  OK  Delivery contract" -ForegroundColor Green

Invoke-GodotCheck `
    -Name "Authored maps" `
    -Arguments @("--headless", "--audio-driver", "Dummy", "--path", $ProjectDir, "--script", "res://tools/map_editor/validate_maps.gd") `
    -SuccessMarker "MAP VALIDATION PASSED"

Invoke-GodotCheck `
    -Name "Agent map API" `
    -Arguments @(
        "--headless", "--audio-driver", "Dummy", "--path", $ProjectDir,
        "--script", "res://tools/map_editor/map_agent.gd", "--", "apply",
        "res://src/world/maps/content/FarmMap.tscn",
        "res://tools/map_editor/examples/farm_orchard_recipe.json", "--dry-run"
    ) `
    -SuccessMarker '"ok":true'

Invoke-GodotCheck `
    -Name "Map editor workflow" `
    -Arguments @("--headless", "--editor", "--audio-driver", "Dummy", "--path", $ProjectDir, "--", "--map-editor-smoke-test") `
    -SuccessMarker "MAP EDITOR SMOKE TEST PASSED"

Invoke-GodotCheck `
    -Name "Startup" `
    -Arguments @("--headless", "--audio-driver", "Dummy", "--quit-after", "30", "--path", $ProjectDir) `
    -SuccessMarker "[MainMenu] Ready"

Invoke-GodotCheck `
    -Name "Unit tests" `
    -Arguments @("--headless", "--audio-driver", "Dummy", "--path", $ProjectDir, "--scene", "tests/unit/test_core.tscn") `
    -SuccessMarker "ALL TESTS PASSED"

Invoke-GodotCheck `
    -Name "Game flow" `
    -Arguments @("--headless", "--audio-driver", "Dummy", "--path", $ProjectDir, "--scene", "tests/integration/test_game_flow.tscn") `
    -SuccessMarker "ALL INTEGRATION TESTS PASSED"

Invoke-GodotCheck `
    -Name "UI system" `
    -Arguments @("--headless", "--audio-driver", "Dummy", "--path", $ProjectDir, "--scene", "tests/integration/test_ui_system.tscn") `
    -SuccessMarker "ALL UI TESTS PASSED"

Write-Host "All checks passed." -ForegroundColor Green
