<#
.SYNOPSIS
  Compiles and SIGNS (strong name) PSMagent.dll from the hardened Command.cs source.
  No Visual Studio required: uses csc.exe (.NET Framework 4) + sn.exe (for the SNK key).
.DESCRIPTION
  Output: <OutDir>\PSMagent.signed.dll  (signed) — ready for ..\sql\02_cert_and_assembly.sql
  The PSMagent.snk key is generated on first run and REUSED (don't change it, or redo step 02).
.NOTES
  Run on the machine that has VS/Windows SDK (for sn.exe). Then copy the DLL to the server at OutDir.
#>
[CmdletBinding()]
param(
    [string]$SourceCs = (Join-Path $PSScriptRoot 'Command.cs'),
    [string]$Snk      = (Join-Path $PSScriptRoot 'PSMagent.snk'),
    [string]$OutDir   = 'C:\ShaiyaServer\PSM_Client',
    [string]$OutName  = 'PSMagent.signed.dll'
)
$ErrorActionPreference = 'Stop'
function Info($m){ Write-Host $m -ForegroundColor Cyan }

if (-not (Test-Path $SourceCs)) { throw "Source not found: $SourceCs" }

# --- 1) csc.exe (.NET Framework 4) ---
$csc = Join-Path $env:WINDIR 'Microsoft.NET\Framework64\v4.0.30319\csc.exe'
if (-not (Test-Path $csc)) { $csc = Join-Path $env:WINDIR 'Microsoft.NET\Framework\v4.0.30319\csc.exe' }
if (-not (Test-Path $csc)) { throw 'csc.exe (.NET Framework 4) not found under C:\Windows\Microsoft.NET\Framework(64)\v4.0.30319.' }
Info "csc: $csc"

# --- 2) SNK key (generate if missing, searching for sn.exe) ---
if (-not (Test-Path $Snk)) {
    $sn = (Get-Command sn.exe -ErrorAction SilentlyContinue).Source
    if (-not $sn) {
        $roots = @(
            "${env:ProgramFiles(x86)}\Windows Kits",
            "${env:ProgramFiles(x86)}\Microsoft SDKs\Windows",
            "${env:ProgramFiles}\Microsoft Visual Studio",
            "${env:ProgramFiles(x86)}\Microsoft Visual Studio"
        )
        foreach ($r in $roots) {
            if (Test-Path $r) {
                $sn = Get-ChildItem -Path $r -Recurse -Filter 'sn.exe' -ErrorAction SilentlyContinue |
                      Select-Object -First 1 -ExpandProperty FullName
                if ($sn) { break }
            }
        }
    }
    if (-not $sn) { throw "sn.exe not found. Install the Windows SDK/VS, or generate the key manually: sn -k `"$Snk`"" }
    Info "sn: $sn  -> generating $Snk"
    & $sn -k $Snk | Out-Null
} else { Info "Existing SNK: $Snk (reusing)" }

# --- 3) compile + sign ---
New-Item -ItemType Directory -Force $OutDir | Out-Null
$out = Join-Path $OutDir $OutName
Info "Compiling -> $out"
& $csc /nologo /target:library /platform:anycpu "/keyfile:$Snk" "/out:$out" `
       /reference:System.dll /reference:System.Data.dll "$SourceCs"
if ($LASTEXITCODE -ne 0) { throw "csc failed (exit $LASTEXITCODE)" }

Write-Host ""
Write-Host "OK: $out" -ForegroundColor Green
Write-Host "Next step: copy the DLL to the server at $OutDir (if building elsewhere) and run ..\sql\02_cert_and_assembly.sql" -ForegroundColor Yellow
