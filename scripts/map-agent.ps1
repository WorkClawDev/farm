$ErrorActionPreference = "Stop"
$ProjectDir = Split-Path -Parent $PSScriptRoot
$Godot = $env:GODOT

if (-not $Godot -or -not (Test-Path -LiteralPath $Godot)) {
    $command = Get-Command godot, godot4 -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($command) {
        $Godot = $command.Source
    } else {
        $downloads = Join-Path $HOME "Downloads"
        $portable = Get-ChildItem -LiteralPath $downloads -File -Recurse -ErrorAction SilentlyContinue |
            Where-Object { $_.Name -match '^Godot.*_console\.exe$' } |
            Sort-Object LastWriteTime -Descending |
            Select-Object -First 1
        if ($portable) {
            $Godot = $portable.FullName
        }
    }
}

if (-not $Godot -or -not (Test-Path -LiteralPath $Godot)) {
    throw "Godot executable not found. Set the GODOT environment variable."
}

& $Godot --headless --audio-driver Dummy --path $ProjectDir `
    --script "res://tools/map_editor/map_agent.gd" -- @args
exit $LASTEXITCODE
