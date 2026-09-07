# Build & sign PSMagent.dll — from scratch

Goal: produce **`PSMagent.signed.dll`** (a strong-name **signed** CLR assembly), so it can be
registered with `PERMISSION_SET = EXTERNAL_ACCESS` authorized via an **asymmetric key** in `master`
(`..\sql\02_cert_and_assembly.sql`), with `clr strict security=1` and **WITHOUT TRUSTWORTHY**.

## Files in this folder
- `Command.cs` — the **hardened** source to compile (serviceName allowlist + socket `using`).
- `Build-PSMagent.ps1` / `Build-PSMagent.bat` — automated build+sign (Visual Studio NOT required).
- `source-original-Database1\` — copy of the **original project** (`.sln`/`.sqlproj`/`Command.cs` + original DLL), for reference.

---

## Method 1 (recommended): automated script — no Visual Studio
Requirements: `csc.exe` (ships with .NET Framework 4, always on Windows) + `sn.exe` (ships with VS or the Windows SDK).

1. Right-click **`Build-PSMagent.bat` → Run as administrator**
   (the default output is `C:\ShaiyaServer\PSM_Client\Bin\`, which may need elevated permissions).
   - For a different path: `Build-PSMagent.bat -OutDir "D:\tmp"`.
2. The script:
   - finds `csc.exe`;
   - generates `PSMagent.snk` on first run (looks for `sn.exe`; **keep** this file);
   - compiles and signs → `C:\ShaiyaServer\PSM_Client\PSMagent.signed.dll`.
3. If you build on a different machine than the server: **copy** `PSMagent.signed.dll` to the
   server path (`C:\ShaiyaServer\PSM_Client\PSMagent.signed.dll`).

If `sn.exe` is not found: open a "Developer Command Prompt for VS" and run `sn -k PSMagent.snk`
once in this folder, then rerun `Build-PSMagent.bat`.

## Method 2: Visual Studio (manual)
1. New **Class Library (.NET Framework)** project, targeting **.NET Framework 4.7.2** (or 4.8).
   (SQL Server 2022 hosts CLR v4 .NET Framework — NOT .NET Core/5+.)
2. Replace the file with this folder's `Command.cs`. References: `System`, `System.Data`.
3. Project properties → **Signing** → **Sign the assembly** → `<New...>` → `PSMagent.snk` (no password).
4. **Release** build → copy the output to `C:\ShaiyaServer\PSM_Client\PSMagent.signed.dll`.

## Verify the signature
```
sn -T "C:\ShaiyaServer\PSM_Client\PSMagent.signed.dll"   REM should print a public key token
```

## Notes
- Always reuse **the same `PSMagent.snk`**: the public key doesn't change ⇒ the asymmetric key in
  `master` stays valid even after rebuilding (no need to redo step 02). Keep the `.snk` safe
  (outside the web root).
- If you change the `.snk`, you must drop/recreate the asymmetric key in `master` (redo
  `02_cert_and_assembly.sql`).
- The original SSDT project (`source-original-Database1`) built the DLL with `EXTERNAL_ACCESS`
  **+ TRUSTWORTHY**: do NOT use it for a secure deploy — here we use signing, not TRUSTWORTHY.
