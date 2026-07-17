<#
.SYNOPSIS
  Compila e FIRMA (strong name) PSMagent.dll dalla sorgente hardened Command.cs.
  Non richiede Visual Studio: usa csc.exe (.NET Framework 4) + sn.exe (per la chiave SNK).
.DESCRIPTION
  Output: <OutDir>\PSMagent.signed.dll  (firmata) — pronta per ..\sql\02_cert_and_assembly.sql
  La chiave PSMagent.snk viene generata al primo run e RIUSATA (non cambiarla, o rifai lo step 02).
.NOTES
  Eseguire sul PC che ha VS/Windows SDK (per sn.exe). Poi copiare la DLL sul server nel path OutDir.
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

if (-not (Test-Path $SourceCs)) { throw "Sorgente non trovata: $SourceCs" }

# --- 1) csc.exe (.NET Framework 4) ---
$csc = Join-Path $env:WINDIR 'Microsoft.NET\Framework64\v4.0.30319\csc.exe'
if (-not (Test-Path $csc)) { $csc = Join-Path $env:WINDIR 'Microsoft.NET\Framework\v4.0.30319\csc.exe' }
if (-not (Test-Path $csc)) { throw 'csc.exe (.NET Framework 4) non trovato in C:\Windows\Microsoft.NET\Framework(64)\v4.0.30319.' }
Info "csc: $csc"

# --- 2) chiave SNK (genera se manca, cercando sn.exe) ---
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
    if (-not $sn) { throw "sn.exe non trovato. Installa Windows SDK/VS, oppure genera la chiave a mano: sn -k `"$Snk`"" }
    Info "sn: $sn  -> genero $Snk"
    & $sn -k $Snk | Out-Null
} else { Info "SNK esistente: $Snk (riuso)" }

# --- 3) compila + firma ---
New-Item -ItemType Directory -Force $OutDir | Out-Null
$out = Join-Path $OutDir $OutName
Info "Compilo -> $out"
& $csc /nologo /target:library /platform:anycpu "/keyfile:$Snk" "/out:$out" `
       /reference:System.dll /reference:System.Data.dll "$SourceCs"
if ($LASTEXITCODE -ne 0) { throw "csc fallito (exit $LASTEXITCODE)" }

Write-Host ""
Write-Host "OK: $out" -ForegroundColor Green
Write-Host "Prossimo passo: copia la DLL sul server in $OutDir (se buildi altrove) e lancia ..\sql\02_cert_and_assembly.sql" -ForegroundColor Yellow
