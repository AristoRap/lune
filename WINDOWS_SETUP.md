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

Set both `CPATH` (used by Crystal-side compile hooks) and `WEBVIEW2_SDK_DIR` (used when building `webview.lib` manually in step 4b) to point at the WebView2 SDK:

```powershell
# Persistent (User scope)
[Environment]::SetEnvironmentVariable("CPATH", $cpathValue, "User")
[Environment]::SetEnvironmentVariable("WEBVIEW2_SDK_DIR", $includeDir.FullName + "\build\native", "User")

# Or session-only (current PowerShell only)
$env:CPATH = $cpathValue
$env:WEBVIEW2_SDK_DIR = "$($includeDir.FullName)\build\native"
```

`WEBVIEW2_SDK_DIR` should point at the directory **containing** `include\` and `x64\` (i.e. `Microsoft.Web.WebView2.<version>\build\native`), not the include dir itself.

## Step 2: Install Crystal Dependencies

```powershell
cd C:\Users\aris\code\lune
shards install --skip-postinstall
```

The `--skip-postinstall` flag skips the Unix-only Makefile-based build step (webview binaries are header-only on Windows).

## Step 3: Apply Crystal 1.20.2 Stdlib Fix

Crystal 1.20.2 (and all earlier released versions) have a compilation blocker: `Process.initialize` references `LibC::PidT`, which doesn't exist on Windows. The fix is documented in [crystal-lang/crystal#16933](https://github.com/crystal-lang/crystal/pull/16933) and is targeted for Crystal 1.21.0.

To work around this on Crystal 1.20.2, apply the fix manually to your Crystal installation:

1. Locate your Crystal stdlib `process.cr`:
   - MSVC build: `C:\Users\<username>\AppData\Local\Programs\Crystal\src\process.cr`
   - MinGW build: `C:\crystal-mingw\share\crystal\src\process.cr`

2. Open the file and find the section around line 599-604:

   ```crystal
   {% unless flag?(:interpreted) %}
     # :nodoc:
     def initialize(pid : LibC::PidT)
       @process_info = Crystal::System::Process.new(pid)
     end
   {% end %}
   ```

3. Remove the type annotation `LibC::PidT` from the parameter:
   ```crystal
   {% unless flag?(:interpreted) %}
     # :nodoc:
     def initialize(pid)
       @process_info = Crystal::System::Process.new(pid)
     end
   {% end %}
   ```

This allows the compiler to infer the type, which works correctly on Windows where `LibC::PidT` doesn't exist.

## Step 4: Build Native Libraries

Lune depends on two C libraries for Windows: sqlite3 and webview. Both must be built and placed where the linker can find them.

### sqlite3.lib

1. Download pre-compiled sqlite3 binaries from [sqlite.org](https://www.sqlite.org/download.html):

   ```powershell
   $url = "https://www.sqlite.org/2024/sqlite-dll-win-x64-3450000.zip"
   Invoke-WebRequest -Uri $url -OutFile "C:\temp\sqlite3.zip"
   Expand-Archive -Path "C:\temp\sqlite3.zip" -DestinationPath "C:\sqlite3"
   ```

2. Create the import library from the x64 Native Tools Command Prompt:
   ```cmd
   cd C:\sqlite3
   lib /def:sqlite3.def /machine:x64 /out:sqlite3.lib
   ```

### webview.lib

Lune ships against a fork of the webview shard (`AristoRap/lune-webview`) that adds Win32-specific extensions (HACCEL hook for menu accelerators, first-class `bind_deferred` / `resolve`). The `.lib` is built directly from the vendored source after `shards install`.

1. Compile `webview.cc` and archive into `webview.lib` from the x64 Native Tools Command Prompt (or PowerShell with `Initialize-LuneEnv` loaded via `./make.ps1 env`):

   ```cmd
   cd C:\Users\aris\code\lune\lib\webview\ext
   cl.exe /nologo /c /EHsc /MD /std:c++17 /DWEBVIEW_STATIC /I"%WEBVIEW2_SDK_DIR%\include" webview.cc /Fo:webview.obj
   lib /nologo /OUT:webview.lib webview.obj
   ```

   `/DWEBVIEW_STATIC` is critical — without it, `WEBVIEW_API` defaults to `inline` in C++ and the resulting `.lib` contains no usable function symbols. The link will then fail with `unresolved external symbol webview_create` (and others).

2. Place the lib where Crystal's linker can find it. Crystal prepends `/LIBPATH:%CRYSTAL_HOME%\lib` to the link command **before** walking the `LIB` env, so a stale copy there wins regardless of what's on `LIB`. Always overwrite both:

   ```cmd
   copy /Y webview.lib "C:\Users\aris\AppData\Local\Programs\Crystal\lib\"
   copy /Y webview.lib C:\sqlite3\
   ```

   Re-run both steps whenever the forked shard updates (typically right after `shards update webview`).

## Step 5: Build Lune CLI

From a normal PowerShell session:

```powershell
cd C:\Users\aris\code\lune
./make.ps1 build
```

`make.ps1` loads the MSVC environment via `Enter-VsDevShell` (or `vcvars64.bat` fallback), preserves any `LIB` extras you've set, and runs `shards build` with the right flags. The output is `bin\lune.exe`.

For ad-hoc invocations without `make.ps1`, run from the x64 Native Tools Command Prompt with the extra paths appended:

```cmd
set LIB=%LIB%;C:\sqlite3;C:\Users\aris\code\lune\lib\webview\ext
set PATH=%PATH%;C:\sqlite3
cd C:\Users\aris\code\lune
"C:\Users\aris\AppData\Local\Programs\Crystal\crystal.exe" build bin/lune.cr -o bin/lune.exe -Dpreview_mt -Dexecution_context
```

## Step 6: Run a Lune App (`lune dev`)

When the CLI spawns `crystal build` for your app, the child process inherits the parent shell's `LIB`. From a vanilla PowerShell or cmd, `LIB` is missing the MSVC base paths (CRT, kernel32, ucrt), so the link step fails with:

```
Cannot locate the .lib files for the following libraries: sqlite3
```

(misleading — it's the missing MSVC base libs that prevent the linker from even getting to sqlite3.)

The easiest workaround is to run `lune dev` from the **x64 Native Tools Command Prompt**, which has `LIB` already populated. If you must run from regular PowerShell, set `LIB` explicitly first:

```powershell
$msvcLib = "C:\Program Files (x86)\Microsoft Visual Studio\2022\BuildTools\VC\Tools\MSVC\14.44.35207\lib\x64;C:\Program Files (x86)\Windows Kits\10\lib\10.0.26100.0\ucrt\x64;C:\Program Files (x86)\Windows Kits\10\lib\10.0.26100.0\um\x64"
$env:LIB = "$msvcLib;C:\sqlite3;C:\Users\aris\code\lune\lib\webview\ext"
$env:PATH = "$env:PATH;C:\sqlite3"
cd <your-lune-app>
C:\Users\aris\code\lune\bin\lune.exe dev
```

Replace the MSVC and Windows Kits version numbers with whatever's installed on your machine (check `C:\Program Files (x86)\Microsoft Visual Studio\2022\BuildTools\VC\Tools\MSVC\` and `C:\Program Files (x86)\Windows Kits\10\lib\`).

### Plugin exclusions

Some plugins are unimplemented or partial on Windows — see each [plugin page](website/plugins/) for status.

## Known setup limitations

- **WebView2 Runtime**: end-users on Windows 10 and earlier need it installed (Windows 11+ ships it).
- **Crystal 1.21.0**: Step 3's stdlib patch becomes unnecessary once Crystal 1.21 ships ([crystal#16933](https://github.com/crystal-lang/crystal/pull/16933)). Drop the patch and re-upgrade Crystal at that point.
- **Running Specs**: `crystal spec` hits the same `LibC::PidT` error. Until Crystal 1.21+, CI type-checks with `--no-codegen`.

For per-plugin status (what's verified, what's broken, what's not yet implemented) see the **Platform notes** section on each [plugin page](website/plugins/). For the path to parity see [`ROADMAP.md`](ROADMAP.md).

## Troubleshooting

### `CPATH is not set`

If you get compilation errors about missing `WebView2.h`:

```cmd
REM Check CPATH
echo %CPATH%

REM Set it if missing (from x64 Native Tools Command Prompt)
set CPATH=C:\temp\webview2\Microsoft.Web.WebView2.1.0.3967.48\build\native\include
```

### Build Fails: `Cannot locate the .lib files for the following libraries: sqlite3, webview`

Ensure both Step 4a (sqlite3.lib creation) and Step 4b (webview build) are complete, and the `LIB` environment variable includes both paths:

```cmd
echo %LIB%
REM Should contain: C:\sqlite3;C:\Users\aris\code\lune\lib\webview\ext
```

If missing, re-run the `set LIB=...` command in Step 5 before building.

### Build Fails: `Cannot open include file: 'WebView2.h'`

The CPATH environment variable is not set correctly. See the `CPATH is not set` section above, or verify the WebView2 NuGet package was downloaded in Step 1.

## References

- [Lune README](README.md) — Platform support and quick start
- [Webview Library](lib/webview/README.md) — Raw webview bindings
- [Changelog v0.11.0](CHANGELOG.md) — Windows port details
- [Crystal Language](https://crystal-lang.org) — Language docs
