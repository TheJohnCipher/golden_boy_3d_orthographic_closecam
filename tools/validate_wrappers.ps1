Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$repoRoot = Resolve-Path (Join-Path $PSScriptRoot "..")

$wrappers = @(
    @{
        Path = "scripts/world/world_3d.gd"
        Target = "res://scripts/world_3d.gd"
        Expect = "extends"
    },
    @{
        Path = "scripts/world/player_3d.gd"
        Target = "res://scripts/player_3d.gd"
        Expect = "extends"
    },
    @{
        Path = "scripts/world/npc_3d.gd"
        Target = "res://scripts/npc_3d.gd"
        Expect = "extends"
    },
    @{
        Path = "scripts/input_actions.gd"
        Target = "res://scripts/world/input_actions.gd"
        Expect = "impl_preload"
    },
    @{
        Path = "scripts/velvet_strip_builder.gd"
        Target = "res://scripts/world/velvet_strip_builder.gd"
        Expect = "impl_preload"
    }
)

function Convert-ResPathToAbsolute([string]$resPath) {
    $relative = $resPath -replace "^res://", ""
    $relative = $relative -replace "/", [System.IO.Path]::DirectorySeparatorChar
    return Join-Path $repoRoot $relative
}

$failed = $false

foreach ($wrapper in $wrappers) {
    $wrapperAbs = Join-Path $repoRoot $wrapper.Path
    if (-not (Test-Path $wrapperAbs)) {
        Write-Host "[FAIL] Missing wrapper: $($wrapper.Path)" -ForegroundColor Red
        $failed = $true
        continue
    }

    $content = Get-Content $wrapperAbs -Raw
    $expectedSnippet = ""
    if ($wrapper.Expect -eq "extends") {
        $expectedSnippet = "extends `"$($wrapper.Target)`""
    } elseif ($wrapper.Expect -eq "impl_preload") {
        $expectedSnippet = "const IMPL = preload(`"$($wrapper.Target)`")"
    } else {
        Write-Host "[FAIL] Unknown wrapper expectation for $($wrapper.Path): $($wrapper.Expect)" -ForegroundColor Red
        $failed = $true
        continue
    }

    if ($content -notmatch [Regex]::Escape($expectedSnippet)) {
        Write-Host "[FAIL] Wrapper forwarding mismatch: $($wrapper.Path)" -ForegroundColor Red
        Write-Host "       Expected snippet: $expectedSnippet"
        $failed = $true
    } else {
        Write-Host "[OK] Wrapper forwarding: $($wrapper.Path)"
    }

    $targetAbs = Convert-ResPathToAbsolute $wrapper.Target
    if (-not (Test-Path $targetAbs)) {
        Write-Host "[FAIL] Missing wrapper target: $($wrapper.Target)" -ForegroundColor Red
        $failed = $true
        continue
    }

    $wrapperResolved = (Resolve-Path $wrapperAbs).Path
    $targetResolved = (Resolve-Path $targetAbs).Path
    if ($wrapperResolved -eq $targetResolved) {
        Write-Host "[FAIL] Wrapper points to itself: $($wrapper.Path)" -ForegroundColor Red
        $failed = $true
    } else {
        Write-Host "[OK] Wrapper target exists: $($wrapper.Target)"
    }
}

if ($failed) {
    Write-Host "Wrapper validation failed." -ForegroundColor Red
    exit 1
}

Write-Host "Wrapper validation passed." -ForegroundColor Green
exit 0
