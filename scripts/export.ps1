param(
    [string]$Godot = $env:GODOT,
    [ValidateSet("pack", "debug", "release")]
    [string]$Mode = "pack",
    [string]$Preset = "Windows Desktop",
    [string]$Output = ""
)

$ErrorActionPreference = "Stop"
$ProjectDir = Split-Path -Parent $PSScriptRoot

if (-not $Godot) {
    $candidate = Get-Command godot, godot4 -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($candidate) { $Godot = $candidate.Source }
}
if (-not $Godot -or -not (Test-Path -LiteralPath $Godot)) {
    throw "Godot executable not found. Pass -Godot or set GODOT."
}

if (-not $Output) {
    $Output = switch ($Mode) {
        "pack" { "build/validation/PastoralTales.pck" }
        "debug" { "build/windows/PastoralTales.debug.exe" }
        default { "build/windows/PastoralTales.exe" }
    }
}
$OutputPath = [IO.Path]::GetFullPath((Join-Path $ProjectDir $Output))
$BuildRoot = [IO.Path]::GetFullPath((Join-Path $ProjectDir "build"))
if (-not $OutputPath.StartsWith($BuildRoot + [IO.Path]::DirectorySeparatorChar, [StringComparison]::OrdinalIgnoreCase)) {
    throw "Export output must stay under $BuildRoot"
}
[IO.Directory]::CreateDirectory([IO.Path]::GetDirectoryName($OutputPath)) | Out-Null

$flag = switch ($Mode) {
    "pack" { "--export-pack" }
    "debug" { "--export-debug" }
    default { "--export-release" }
}
$previousErrorAction = $ErrorActionPreference
$ErrorActionPreference = "Continue" # Windows PowerShell surfaces native stderr as ErrorRecord.
$log = (& $Godot --headless --path $ProjectDir $flag $Preset $OutputPath 2>&1 | Out-String)
$exitCode = $LASTEXITCODE
$ErrorActionPreference = $previousErrorAction
Write-Host $log
$errorPattern = '(?m)^(SCRIPT ERROR|ERROR:|FATAL)|Compile Error|Parse Error|Nonexistent function|Invalid call|Failed to load script'
if ($exitCode -ne 0 -or $log -match $errorPattern -or -not (Test-Path -LiteralPath $OutputPath)) {
    throw "Godot export failed or emitted script/runtime errors (exit $exitCode)"
}
Write-Host "Export OK: $OutputPath" -ForegroundColor Green
