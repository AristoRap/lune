#!/usr/bin/env pwsh
# make.ps1 -- Windows iteration helper, mirrors the Unix Makefile.
#
# Usage:
#   ./make.ps1               # show help
#   ./make.ps1 <target> [args...]
#
# Targets mirror the Makefile: setup, test, build, release, clean, dev, app,
# run, web, docs, patch, minor. Plus `env` to inspect the resolved MSVC paths.

[CmdletBinding()]
param(
    [Parameter(Position = 0)]
    [string]$Target = 'help',

    [Parameter(ValueFromRemainingArguments = $true)]
    [string[]]$Rest
)

$ErrorActionPreference = 'Stop'
$RepoRoot = $PSScriptRoot
$CrystalFlags = @('-Dpreview_mt', '-Dexecution_context')
$LuneExe = Join-Path $RepoRoot 'bin\lune.exe'
$DemoDir = Join-Path $RepoRoot 'demo'
$WebDir  = Join-Path $RepoRoot 'website'

function Show-Help {
    @"
Source:
  ./make.ps1 setup     install Crystal deps (shards install)
  ./make.ps1 test      run specs (mocked native layer)
  ./make.ps1 build     test + build CLI binary (bin/lune.exe)
  ./make.ps1 release   test + build CLI binary (--release)
  ./make.ps1 clean     remove build artifacts
  ./make.ps1 patch     bump patch version (x.y.Z)
  ./make.ps1 minor     bump minor version (x.Y.0)
  ./make.ps1 env       print resolved MSVC env (debug aid)

Example app (auto-builds bin/lune.exe if missing):
  ./make.ps1 dev       lune dev in demo/
  ./make.ps1 app       lune build in demo/
  ./make.ps1 run       lune run in demo/

Docs:
  ./make.ps1 web       run website dev server
  ./make.ps1 docs      build website
"@
}

# --- MSVC env -------------------------------------------------------------
# Loads the MSVC toolchain (cl.exe + LIB/INCLUDE/PATH) into the current
# PowerShell session. Preferred path is Enter-VsDevShell via the official
# DevShell module; fallback is piping `vcvars64.bat && set` through cmd.exe.
# Marker env var keeps us from re-running per command in the same session.

function Find-VSWhere {
    $candidate = Join-Path ${env:ProgramFiles(x86)} 'Microsoft Visual Studio\Installer\vswhere.exe'
    if (Test-Path $candidate) { return $candidate }
    $cmd = Get-Command vswhere.exe -ErrorAction SilentlyContinue
    if ($cmd) { return $cmd.Source }
    throw "vswhere.exe not found. Install Visual Studio 2022 Build Tools (or full VS) with the 'Desktop development with C++' workload."
}

function Get-VSInstallPath {
    $vswhere = Find-VSWhere
    $path = & $vswhere -latest -products * -requires Microsoft.VisualStudio.Component.VC.Tools.x86.x64 -property installationPath
    if (-not $path) {
        throw "No MSVC installation with C++ tools found via vswhere. Install the 'Desktop development with C++' workload."
    }
    return $path.Trim()
}

function Initialize-LuneEnv {
    if ($env:LUNE_MSVC_READY -eq '1') { return }

    $vsPath = Get-VSInstallPath
    # Preserve LIB so user's sqlite3/webview entries survive vcvars'/DevShell prepend.
    $savedLib = $env:LIB

    $devShell = Join-Path $vsPath 'Common7\Tools\Microsoft.VisualStudio.DevShell.dll'
    if (Test-Path $devShell) {
        # Enter-VsDevShell shells out to vswhere internally without an absolute
        # path, so prepend the Installer dir to PATH for the duration of the
        # call to silence "'vswhere.exe' is not recognized" noise on stdout.
        $installerDir = Join-Path ${env:ProgramFiles(x86)} 'Microsoft Visual Studio\Installer'
        if (Test-Path $installerDir) { $env:PATH = "$installerDir;$env:PATH" }
        Import-Module $devShell
        # SkipAutomaticLocation keeps cwd as-is; Arch x64 / HostArch x64 = vcvars64.
        Enter-VsDevShell -VsInstallPath $vsPath -SkipAutomaticLocation -DevCmdArguments '-arch=x64 -host_arch=x64' | Out-Null
    } else {
        # Fallback: vcvars64.bat -> set -> import into PowerShell.
        $vcvars = Join-Path $vsPath 'VC\Auxiliary\Build\vcvars64.bat'
        if (-not (Test-Path $vcvars)) {
            throw "Neither DevShell module nor vcvars64.bat found under $vsPath."
        }
        $dump = & cmd.exe /c "`"$vcvars`" >nul && set"
        foreach ($line in $dump) {
            if ($line -match '^([^=]+)=(.*)$') {
                Set-Item -Path "env:$($Matches[1])" -Value $Matches[2]
            }
        }
    }

    # Re-append the original LIB entries (sqlite3, webview/ext) at the end so
    # the linker still finds sqlite3.lib without losing MSVC's UCRT/CRT libs.
    if ($savedLib) {
        $existing = $env:LIB -split ';' | Where-Object { $_ }
        $extra    = $savedLib -split ';' | Where-Object { $_ -and ($existing -notcontains $_) }
        if ($extra) {
            $env:LIB = ($existing + $extra) -join ';'
        }
    }

    $env:LUNE_MSVC_READY = '1'
}

# --- Prerequisite checks --------------------------------------------------

function Require-Command([string]$Name, [string]$Hint) {
    if (-not (Get-Command $Name -ErrorAction SilentlyContinue)) {
        throw "Missing dependency: $Name. $Hint"
    }
}

function Assert-NativeDeps {
    # sqlite3.lib is required at link time; the dir must be on LIB.
    $hasSqlite = ($env:LIB -split ';') | Where-Object { $_ -and (Test-Path (Join-Path $_ 'sqlite3.lib')) }
    if (-not $hasSqlite) {
        throw "sqlite3.lib not found on LIB. Place sqlite3.dll/.lib in C:\sqlite3 (or set LIB to include it) -- see WINDOWS_SETUP.md."
    }
    $hasWebviewH = ($env:INCLUDE + ';' + $env:LIB -split ';') | Where-Object {
        $_ -and (Test-Path (Join-Path $_ 'webview.h'))
    }
    if (-not $hasWebviewH) {
        $local = Join-Path $RepoRoot 'lib\webview\ext\webview.h'
        if (-not (Test-Path $local)) {
            throw "lib\webview\ext\webview.h not found. Run './make.ps1 setup' first."
        }
    }
}

# --- Targets --------------------------------------------------------------

function Invoke-Setup {
    Require-Command 'shards' 'Install Crystal -- see WINDOWS_SETUP.md'
    Push-Location $RepoRoot
    try { shards install } finally { Pop-Location }
}

function Invoke-Test {
    Require-Command 'crystal' 'Install Crystal -- see WINDOWS_SETUP.md'
    Initialize-LuneEnv
    Assert-NativeDeps
    Push-Location $RepoRoot
    try {
        crystal spec -Dlune_native_test_mock @CrystalFlags
        if ($LASTEXITCODE -ne 0) { throw "specs failed (exit $LASTEXITCODE)" }
    } finally { Pop-Location }
}

function Invoke-Build([switch]$Release) {
    Require-Command 'shards' 'Install Crystal -- see WINDOWS_SETUP.md'
    Invoke-Test
    Initialize-LuneEnv
    Push-Location $RepoRoot
    try {
        $args = @() + $CrystalFlags
        if ($Release) { $args = @('--release') + $args }
        shards build @args
        if ($LASTEXITCODE -ne 0) { throw "shards build failed (exit $LASTEXITCODE)" }
    } finally { Pop-Location }
}

function Invoke-Clean {
    $patterns = @(
        'bin\lune.exe', 'bin\lune.pdb', 'bin\lune.dwarf',
        'demo\build', 'demo\.lune-dev', 'demo\*.dwarf', 'demo\*.pdb'
    )
    foreach ($p in $patterns) {
        $full = Join-Path $RepoRoot $p
        Get-Item -Path $full -ErrorAction SilentlyContinue | ForEach-Object {
            Remove-Item -Recurse -Force $_.FullName
            Write-Host "removed $($_.FullName)"
        }
    }
}

function Ensure-LuneExe {
    if (-not (Test-Path $LuneExe)) {
        Write-Host "bin\lune.exe missing -- building first..." -ForegroundColor Yellow
        Invoke-Build
    }
}

function Invoke-Demo([string]$SubCmd, [string[]]$Extra) {
    Ensure-LuneExe
    Initialize-LuneEnv  # demo's `lune dev` spawns Crystal too
    Push-Location $DemoDir
    try {
        & $LuneExe $SubCmd @Extra
        if ($LASTEXITCODE -ne 0) { throw "lune $SubCmd failed (exit $LASTEXITCODE)" }
    } finally { Pop-Location }
}

function Invoke-Web {
    Require-Command 'npm' 'Install Node.js from https://nodejs.org'
    Push-Location $WebDir
    try { npm run docs:dev } finally { Pop-Location }
}

function Invoke-Docs {
    Require-Command 'npm' 'Install Node.js from https://nodejs.org'
    Push-Location $WebDir
    try {
        npm run docs:build
        if ($LASTEXITCODE -ne 0) { throw "docs build failed (exit $LASTEXITCODE)" }
    } finally { Pop-Location }
}

function Bump-Version([string]$Kind) {
    $shardFile = Join-Path $RepoRoot 'shard.yml'
    $current = (Select-String -Path $shardFile -Pattern '^version:\s*(.+)$' | Select-Object -First 1).Matches[0].Groups[1].Value.Trim()
    $parts = $current.Split('.')
    switch ($Kind) {
        'patch' {
            $bumped = [int]$parts[2] + 1
            $next = "$($parts[0]).$($parts[1]).$bumped"
        }
        'minor' {
            $bumped = [int]$parts[1] + 1
            $next = "$($parts[0]).$bumped.0"
        }
        default { throw "Unknown bump kind: $Kind" }
    }
    $files = @{
        'shard.yml'                       = @{ pattern = '^version:\s*.+$';                 replace = "version: $next" }
        'src\lune.cr'                     = @{ pattern = 'VERSION\s*=\s*"[^"]*"';            replace = "VERSION = `"$next`"" }
        'website\getting-started.md'      = @{ pattern = 'version:\s*~>\s*\S+';              replace = "version: ~> $next" }
        'website\.vitepress\config.ts'    = @{ pattern = "const version = '[^']*'";          replace = "const version = '$next'" }
    }
    foreach ($rel in $files.Keys) {
        $full = Join-Path $RepoRoot $rel
        if (-not (Test-Path $full)) { continue }
        # Preserve original line endings (CRLF on Windows checkouts).
        $text = [System.IO.File]::ReadAllText($full)
        $new  = [regex]::Replace($text, $files[$rel].pattern, $files[$rel].replace)
        [System.IO.File]::WriteAllText($full, $new)
    }
    Write-Host "Bumped $current -> $next"
}

function Show-Env {
    Initialize-LuneEnv
    Write-Host "MSVC ready: $($env:LUNE_MSVC_READY)"
    Write-Host ""
    Write-Host "LIB:"
    ($env:LIB -split ';') | Where-Object { $_ } | ForEach-Object { Write-Host "  $_" }
    Write-Host ""
    Write-Host "INCLUDE:"
    ($env:INCLUDE -split ';') | Where-Object { $_ } | ForEach-Object { Write-Host "  $_" }
    Write-Host ""
    Write-Host "PATH (cl.exe-relevant entries):"
    ($env:PATH -split ';') | Where-Object { $_ -match 'MSVC|VC\\Tools|Windows Kits' } | ForEach-Object { Write-Host "  $_" }
}

# --- Dispatch -------------------------------------------------------------

switch ($Target.ToLower()) {
    'help'    { Show-Help }
    '-h'      { Show-Help }
    '--help'  { Show-Help }
    'setup'   { Invoke-Setup }
    'test'    { Invoke-Test }
    'build'   { Invoke-Build }
    'release' { Invoke-Build -Release }
    'clean'   { Invoke-Clean }
    'dev'     { Invoke-Demo 'dev'   $Rest }
    'app'     { Invoke-Demo 'build' $Rest }
    'run'     { Invoke-Demo 'run'   $Rest }
    'web'     { Invoke-Web }
    'docs'    { Invoke-Docs }
    'patch'   { Bump-Version 'patch' }
    'minor'   { Bump-Version 'minor' }
    'env'     { Show-Env }
    default {
        Write-Host "Unknown target: $Target" -ForegroundColor Red
        Write-Host ""
        Show-Help
        exit 1
    }
}
