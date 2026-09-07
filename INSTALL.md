# Install guide — PSM_Cmd Secure Command Channel

Step-by-step operational guide to install the secure PSMagent command channel **from scratch** on
a Shaiya server (SQL Server 2022 Express). For the architectural "why" see `PLAN.md`; for the
component summary see `README.md`.

> ⚠️ **Secrets**: the SQL scripts use `N'La_tua_password'` as a placeholder. Replace it with real,
> strong passwords BEFORE running the scripts in production. Never commit real passwords to the repo.

## Repository tree

```
PSM_Cmd-SecureCommandChannel/
├── README.md                          Architecture overview + condensed install order
├── PLAN.md                            Plan/rationale: risks, decisions, benefit
├── SERVER-COMMANDS-GUIDE.md           ps_game/ps_login command catalog (SAFE/PLAYER/ECONOMY/SERVICE tiers)
├── INSTALL.md                         This guide
│
├── 1.sql/                             SQL scripts, run IN ORDER (00 → 07)
│   ├── 00_prereqs.sql                 Enables CLR, checks server edition/flags
│   ├── 01_create_db_PSM_Cmd.sql       Creates the closed PSM_Cmd DB (TRUSTWORTHY off, dedicated owner)
│   ├── 02_cert_and_assembly.sql       Registers the signed assembly via an asymmetric key in master
│   ├── 03_wrappers_allowlist.sql      Creates allowlist, audit log, usp_SendNotice, usp_RunCommand
│   ├── 04_principals_grants.sql       Creates the ShaiyaTaskAgent login + users + least-privilege grants on wrappers
│   ├── 05_repoint_callers.sql         Notes: which files in 2.app/ to apply to repoint the callers
│   ├── 06_remove_old.sql              Removes the old channel from PS_GameDefs (ONLY after tests pass)
│   └── 07_verify.sql                  Final checks + positive/negative tests
│
├── 2.app/                             Application patches (the "3 callers" to repoint)
│   ├── usp_Insert_Action_Log_E_change.md      Gameplay patch: enchant notice → usp_SendNotice
│   ├── admin_actions.web_repoint.md           Web patch: admin_actions.php → usp_RunCommand
│   └── worker.notes.md                        Worker patch: new dedicated ShaiyaTaskAgent connection
│
├── clr/                               CLR assembly source and build
│   ├── Command.cs                     Hardened source (serviceName allowlist, socket `using`)
│   ├── Build-PSMagent.ps1             Build+sign script (PowerShell)
│   ├── Build-PSMagent.bat             .bat wrapper: double-click → Run as administrator
│   ├── BUILD-AND-SIGN.md               Detailed build/sign instructions (script or Visual Studio)
│   ├── source-original-Database1/     Original SSDT project (reference only, NOT for secure deploy)
│   └── PSMagent.snk                   Strong-name private key — generated locally, NEVER in the repo
│
└── .gitignore                         Excludes PSMagent.snk, *.dll/*.pdb/*.dacpac, build/IDE junk
```

> `PSMagent.snk` and the compiled `.dll` **are not in the repo** (see `.gitignore`): they're
> generated/rebuilt locally with `clr/Build-PSMagent.bat`. Keep the `.snk` outside the repo and
> outside the web root.

## Prerequisites

- SQL Server **2022 Express** (or later) with `sysadmin` access.
- `clr strict security = 1` (modern default) — handled by `00_prereqs.sql`.
- Windows with **.NET Framework 4** (`csc.exe`, always present) to build the CLR assembly.
- `sn.exe` to sign the assembly (ships with Visual Studio or the Windows SDK) — see
  `clr/BUILD-AND-SIGN.md` for a fallback if missing.
- Access to the server running `ps_game.exe`/`ps_login.exe` listening on `127.0.0.1:40900`.
- The existing "3 callers" to repoint: `htdocs/admin_actions.php` (web), `worker.ps1` +
  `worker.config.json` (task scheduler), `PS_GameLog.dbo.usp_Insert_Action_Log_E` (gameplay).

## Install steps (new server or migration)

### 1. Build & sign the DLL
```
clr/Build-PSMagent.bat  → right-click → Run as administrator
```
Generates `clr/PSMagent.snk` (on first run — **keep it**, don't regenerate it) and produces
`C:\ShaiyaServer\PSM_Client\PSMagent.signed.dll`. If you build on a different machine than the
server, copy the signed DLL to the server path. Details/fallback (Visual Studio): `clr/BUILD-AND-SIGN.md`.

### 2. SQL prerequisites
```sql
-- as sysadmin
:r 1.sql\00_prereqs.sql
```
Enables CLR, checks the server edition and security flags.

### 3. Create the dedicated database
Before running, open `1.sql/01_create_db_PSM_Cmd.sql` and replace `N'La_tua_password'` with a
real, strong password for the `PSMCmdOwner` login.
```sql
:r 1.sql\01_create_db_PSM_Cmd.sql
```
Creates `PSM_Cmd` with `TRUSTWORTHY OFF`, `DB_CHAINING OFF`, a dedicated non-sysadmin owner, guest revoked.

### 4. Register the signed assembly
Check the signed DLL path in the script, then:
```sql
:r 1.sql\02_cert_and_assembly.sql
```
Creates the asymmetric key from `PSMagent.signed.dll` in `master`, registers the `EXTERNAL_ACCESS`
assembly authorized by the signature (no TRUSTWORTHY), creates the private `dbo.Command` (no direct grants).

### 5. Wrappers + allowlist + audit
```sql
:r 1.sql\03_wrappers_allowlist.sql
```
Creates `GmCommandAllowlist` (with a `Description` column), `GmCommandLog` (audit), the
`usp_SendNotice` and `usp_RunCommand` procs (both `EXECUTE AS OWNER`).

### 6. Accounts and least-privilege grants
Before running, open `1.sql/04_principals_grants.sql` and replace `N'La_tua_password'` with a
real, strong password for the `ShaiyaTaskAgent` login.
```sql
:r 1.sql\04_principals_grants.sql
```
Creates the dedicated `ShaiyaTaskAgent` login (worker) and the least-privilege grants on the
wrappers ONLY — never directly on `dbo.Command`:
- `Ernoweb@` (web) → `usp_RunCommand` (tier PLAYER: `/nt` + `/kick*`) + `usp_SendNotice`.
- `S@o0#$h1908` (gameplay) → `usp_SendNotice` only (sanitized enchant notice).
- `ShaiyaTaskAgent` (worker) → `usp_RunCommand` (tier ECONOMY) + `usp_SendNotice`.

### 7. Repoint the 3 callers
See `1.sql/05_repoint_callers.sql` for the list, then apply the patches described in `2.app/`:

| Caller | File to modify | Guide |
|---|---|---|
| Gameplay (enchant notice) | `PS_GameLog.dbo.usp_Insert_Action_Log_E` | `2.app/usp_Insert_Action_Log_E_change.md` |
| Web (send_notice / kick) | `htdocs/admin_actions.php` (~line 500) | `2.app/admin_actions.web_repoint.md` |
| Worker (task scheduler, economy) | `worker.ps1` + `worker.config.json` | `2.app/worker.notes.md` |

For the worker: add the dedicated `command_connection_string` connection to `worker.config.json`
with `User ID=ShaiyaTaskAgent;Password=La_tua_password;...` (use the real password chosen in step
6, don't commit it in plaintext to your config files).

### 8. End-to-end test
With the **new** DB active, verify:
- `/nt` sent from the web (send_notice) works.
- The in-game enchant notice works.
- A worker command (e.g. `/exp2xenable`, already enabled) works.

### 9. Remove the old channel
**Only after** step 8 is green:
```sql
:r 1.sql\06_remove_old.sql
```
Removes `Command` + the assembly from `PS_GameDefs` and sets `TRUSTWORTHY OFF`.

### 10. Final verification
```sql
:r 1.sql\07_verify.sql
```
Expected: `Command` gone from `PS_GameDefs`, assembly present in `PSM_Cmd`, `TRUSTWORTHY=0`
everywhere, `/nt` test OK, `/shutdown` negative test → DENIED (-3).

## Enabling an additional command for the worker

Safe default: economy/service commands = `Enabled=0`. To enable one:
```sql
UPDATE PSM_Cmd.dbo.GmCommandAllowlist SET Enabled=1 WHERE Command='/exp2xenable' AND Service='ps_game';
```
Full command/tier catalog: `SERVER-COMMANDS-GUIDE.md`.

## Rollback

If something goes wrong **before** step 9: the old channel (`PS_GameDefs.dbo.Command`) keeps
working until you run `06_remove_old.sql` — no action needed, callers not yet repointed keep using
the old path.

If you need to roll back **after** step 9: re-register the old proc/assembly on `PS_GameDefs`
(from your original guide scripts) and repoint the callers back to the old channel. Always keep a
DB backup before step 9.

## Security notes

- Destructive commands (`/shutdown`, `/enchant`, SERVICE-tier controls, etc.) stay `Enabled=0` by
  default: only enable them if truly needed, and only for accounts/tiers that genuinely require it.
- If the worker's config file has plaintext credentials, keep it **outside the web root** and
  protected by filesystem permissions (in addition to any `.htaccess`).
- Always reuse the same `PSMagent.snk` to rebuild: the public key doesn't change, so the asymmetric
  key in `master` stays valid. If you regenerate it, redo `02_cert_and_assembly.sql`.
- Never commit `PSMagent.snk`, real passwords, or compiled DLL files to the repo (see `.gitignore`).
