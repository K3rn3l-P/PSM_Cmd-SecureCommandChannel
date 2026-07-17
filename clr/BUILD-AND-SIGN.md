# Build & firma di PSMagent.dll — da zero

Obiettivo: produrre **`PSMagent.signed.dll`** (assembly CLR **firmata con strong name**), così da registrarla
con `PERMISSION_SET = EXTERNAL_ACCESS` autorizzata via **asymmetric key** in `master`
(`..\sql\02_cert_and_assembly.sql`), con `clr strict security=1` e **SENZA TRUSTWORTHY**.

## File in questa cartella
- `Command.cs` — sorgente **hardened** da compilare (allowlist serviceName + socket `using`).
- `Build-PSMagent.ps1` / `Build-PSMagent.bat` — build+firma automatici (NON serve Visual Studio).
- `source-original-Database1\` — copia del **progetto originale** (`.sln`/`.sqlproj`/`Command.cs` + DLL originale), per riferimento.

---

## Metodo 1 (consigliato): script automatico — niente Visual Studio
Requisiti: `csc.exe` (presente con .NET Framework 4, sempre su Windows) + `sn.exe` (presente con VS o Windows SDK).

1. Tasto destro su **`Build-PSMagent.bat` → Esegui come amministratore**
   (l'output default e' `C:\ShaiyaServer\PSM_Client\Bin\` che potrebbe richiedere permessi).
   - Per un path diverso: `Build-PSMagent.bat -OutDir "D:\tmp"`.
2. Lo script:
   - trova `csc.exe`;
   - genera `PSMagent.snk` al primo run (cerca `sn.exe`; **conserva** questo file);
   - compila e firma → `C:\ShaiyaServer\PSM_Client\PSMagent.signed.dll`.
3. Se buildi su un PC diverso dal server: **copia** `PSMagent.signed.dll` nel path del server
   (`C:\ShaiyaServer\PSM_Client\PSMagent.signed.dll`).

Se `sn.exe` non viene trovato: aprire un "Developer Command Prompt for VS" e lanciare una volta
`sn -k PSMagent.snk` in questa cartella, poi rilanciare `Build-PSMagent.bat`.

## Metodo 2: Visual Studio (manuale)
1. Nuovo progetto **Class Library (.NET Framework)**, target **.NET Framework 4.7.2** (o 4.8).
   (SQL Server 2022 ospita CLR v4 .NET Framework — NON .NET Core/5+.)
2. Sostituisci il file con `Command.cs` di questa cartella. Reference: `System`, `System.Data`.
3. Proprieta' progetto → **Signing** → **Sign the assembly** → `<New...>` → `PSMagent.snk` (senza password).
4. Build **Release** → copia l'output in `C:\ShaiyaServer\PSM_Client\PSMagent.signed.dll`.

## Verifica firma
```
sn -T "C:\ShaiyaServer\PSM_Client\PSMagent.signed.dll"   REM deve stampare un public key token
```

## Note
- Riusa **sempre lo stesso `PSMagent.snk`**: la chiave pubblica non cambia ⇒ l'asymmetric key in `master`
  resta valida anche se ricompili (non serve rifare lo step 02). Conserva `.snk` in modo sicuro (fuori dalla web root).
- Se cambi la `.snk`, devi droppare/ricreare l'asymmetric key in `master` (rifai `02_cert_and_assembly.sql`).
- Il progetto originale SSDT (`source-original-Database1`) creava la DLL con `EXTERNAL_ACCESS` **+ TRUSTWORTHY**:
  NON usarlo per il deploy sicuro — qui usiamo la firma, non TRUSTWORTHY.
