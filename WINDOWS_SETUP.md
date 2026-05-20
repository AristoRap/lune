# Windows Setup Guide

This guide documents the manual setup required to develop Lune on Windows.

## Prerequisites

- Visual Studio 2022 or later with C++ build tools
- Crystal 1.20.2+ (MSVC target)
- Git and PowerShell

## Step 1: Install WebView2 SDK Headers

The webview library requires Microsoft's WebView2 SDK headers. They're not included in the repository.

### Download WebView2 NuGet Package

```powershell
# Download nuget.exe
$nugetUrl = "https://dist.nuget.org/win-x86-commandline/latest/nuget.exe"
$nugetPath = "C:\temp\nuget.exe"
New-Item -ItemType Directory -Path "C:\temp" -Force | Out-Null
[System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor [System.Net.SecurityProtocolType]::Tls12
Invoke-WebRequest -Uri $nugetUrl -OutFile $nugetPath

# Download WebView2 package
& $nugetPath install Microsoft.Web.WebView2 -OutputDirectory "C:\temp\webview2"

# Find the include directory
$includeDir = Get-ChildItem "C:\temp\webview2" -Filter "Microsoft.Web.WebView2.*" -Directory | Select-Object -First 1
$cpathValue = Join-Path $includeDir.FullName "build\native\include"
```

### Set Environment Variable

Set `CPATH` to point to the WebView2 headers:

```powershell
# Persistent (User scope)
[Environment]::SetEnvironmentVariable("CPATH", $cpathValue, "User")

# Or session-only (current PowerShell only)
$env:CPATH = $cpathValue
```

## Step 2: Install Crystal Dependencies

```powershell
cd C:\Users\aris\code\lune
shards install --skip-postinstall
```

The `--skip-postinstall` flag skips the Unix-only Makefile-based build step (webview binaries are header-only on Windows).

## Step 3: Build Lune CLI

### Mocked Build (Current Workaround)

Crystal 1.20.2 has a stdlib bug on Windows (`undefined constant LibC::PidT`). Until a newer Crystal is released, use the mocked build mode:

```powershell
crystal build src/lune_cli.cr -o bin/lune.exe --release -Dpreview_mt -Dexecution_context -D lune_native_test_mock
```

This produces a working CLI for development and testing.

### Real Build (Future)

Once Crystal fixes the stdlib bug on Windows MSVC, real builds should work:

```powershell
shards build --release -Dpreview_mt -Dexecution_context
```

## Known Limitations

- **Running Specs**: `crystal spec` fails due to the Crystal stdlib bug. Type-checking with `--no-codegen` works fine.
- **WebView2 Runtime**: Developers and end-users need the WebView2 runtime installed on Windows 10 and earlier (Windows 11+ includes it).
- **Real Hardware Testing**: The Windows port (v0.11.0) has not yet been tested on real hardware. Feedback welcome on GitHub issues.

## Troubleshooting

### `CPATH is not set`

If you get compilation errors about missing `WebView2.h`:

```powershell
# Check CPATH
$env:CPATH

# Set it if missing (replace path as needed)
$env:CPATH = "C:\temp\webview2\Microsoft.Web.WebView2.1.0.3967.48\build\native\include"
```

### Build Fails with `undefined constant LibC::PidT`

This is the known Crystal 1.20.2 bug on Windows MSVC. Use the mocked build mode (add `-D lune_native_test_mock`).

### Build Succeeds But Binary Doesn't Run

The mocked build produces a working CLI for development. For distribution, wait for Crystal to fix the stdlib bug.

## References

- [Lune README](README.md) — Platform support and quick start
- [Webview Library](lib/webview/README.md) — Raw webview bindings
- [Changelog v0.11.0](CHANGELOG.md) — Windows port details
- [Crystal Language](https://crystal-lang.org) — Language docs
