# PSM_Cmd — Secure PSMagent Command Channel (dedicated, signed DB, allowlist + audit)

Step-by-step guide to install the admin command channel (`/nt`, `ps_game`/`ps_login` commands)
securely, **from scratch**: a **signed** CLR assembly in a **dedicated, closed database**
(`PSM_Cmd`), **without TRUSTWORTHY**, with **wrapper procedures + allowlist + audit** and
**least-privilege accounts**.

Replaces the old scheme (the `PSMagent` assembly, `EXTERNAL_ACCESS`, living inside `PS_GameDefs`
with `TRUSTWORTHY ON` and EXECUTE granted schema-wide via `MioRuoloExecute`).

> Verified environment (2026-06): SQL Server **2022 Express** (16.0.1180.1), `clr strict security=1`,
> `cross db ownership chaining=0`. CLR + asymmetric key signing both supported on Express.

## Context

Targets a legacy MMO private-server stack (Shaiya-based). `ps_game` and
`ps_login` are the game server processes; PSMagent is a CLR bridge that lets
SQL Server send them admin commands (`/nt` broadcast notices, moderation,
economy actions). The original bridge ran fully trusted inside the game
database — this repo moves it into an isolated, signed, audited channel.

## Why (summary)
- **Isolation**: the privileged CLR (opens a socket → `:40900` → ps_game) leaves the game data DB.
- **No TRUSTWORTHY**: the assembly is authorized by its **signature** (asymmetric key in `master`),
  not by TRUSTWORTHY. → `PS_GameDefs` goes back to `TRUSTWORTHY OFF` (closes findings 03/07 of the
  test suite).
- **Least privilege**: web (`Ernoweb@`) can only send `/nt`; the worker (dedicated account
  `ShaiyaTaskAgent`) can only run commands enabled in the allowlist; gameplay (`S@o0#$h1908`) can
  only send `/nt`. Nobody touches `Command` directly (wrapper procs run `EXECUTE AS OWNER`).
  Destructive commands (`/shutdown`, `/enchant`, …) are `Enabled=0` by default.
- **Audit**: every command is logged in `PSM_Cmd.dbo.GmCommandLog`.

## Components
```
clr/Command.cs              Hardened CLR (serviceName allowlist + socket using). Needs signing (SNK).
clr/Build-PSMagent.ps1/.bat Automated build+sign (csc+sn, no VS needed). Outputs PSMagent.signed.dll.
clr/BUILD-AND-SIGN.md       Build/sign instructions from scratch (script or VS).
clr/source-original-Database1/  Copy of the ORIGINAL project (sln/sqlproj/Command.cs + dll), for reference.
sql/00_prereqs.sql          Enables CLR, checks edition/flags.
sql/01_create_db_PSM_Cmd.sql  Creates the closed PSM_Cmd database (TRUSTWORTHY off, non-sysadmin owner, guest off).
sql/02_cert_and_assembly.sql  Asymmetric key from the signed DLL + EXTERNAL_ACCESS assembly + private dbo.Command.
sql/03_wrappers_allowlist.sql Allowlist + log + usp_SendNotice + usp_RunCommand (EXECUTE AS OWNER).
sql/04_principals_grants.sql  ShaiyaTaskAgent login + users + least-privilege grants on wrappers only.
sql/05_repoint_callers.sql    Instructions to repoint the 3 callers (see app/).
sql/06_remove_old.sql         Removes Command+assembly from PS_GameDefs + TRUSTWORTHY OFF.
sql/07_verify.sql             Checks + /nt test + negative /shutdown test.
app/usp_Insert_Action_Log_E_change.md   Gameplay patch (enchant notice).
app/admin_actions.send_notice.snippet.php  Web patch (send_notice).
app/worker.notes.md          Worker patch (dedicated account + usp_RunCommand).
PLAN.md                      Full plan/architecture and rationale.
SERVER-COMMANDS-GUIDE.md     ps_game/ps_login server commands: what they do, tier, criticality (vs client GM commands).
```

> `GmCommandAllowlist` has a **`Description`** column (what each command does) — see SERVER-COMMANDS-GUIDE.md.
> NB: the SERVER commands (here) are different from client-side **GM commands** (e.g. /imake /summon).

## Install order (new server or migration)
1. **Build & sign** the DLL: right-click `clr/Build-PSMagent.bat` → **Run as administrator**
   (generates `PSMagent.snk` and produces `C:\ShaiyaServer\PSM_Client\PSMagent.signed.dll`). Details/VS fallback: `clr/BUILD-AND-SIGN.md`.
   If you build on a different machine than the server, copy the signed DLL to the server path.
2. `sql/00_prereqs.sql`  (sysadmin)
3. `sql/01_create_db_PSM_Cmd.sql`  → **change the `PSMCmdOwner` password**.
4. `sql/02_cert_and_assembly.sql`  (check the DLL path).
5. `sql/03_wrappers_allowlist.sql`
6. `sql/04_principals_grants.sql`  → **change the `ShaiyaTaskAgent` password**.
7. **Repoint callers** (`sql/05` + files in `app/`):
   - gameplay: patch `PS_GameLog.usp_Insert_Action_Log_E` (enchant notice block).
   - web: patch `htdocs/admin_actions.php` (send_notice).
   - worker: `worker.config.json` → `ShaiyaTaskAgent`; commands via `usp_RunCommand`.
8. **Test** `/nt` from the web, the in-game enchant notice, a worker command. Confirm they work against the NEW DB.
9. `sql/06_remove_old.sql`  (only after 1-8 work: removes the old channel + `PS_GameDefs TRUSTWORTHY OFF`).
10. `sql/07_verify.sql`  → expected: Command gone from PS_GameDefs, assembly present in PSM_Cmd, TRUSTWORTHY=0
    everywhere, `/nt` test OK, `/shutdown` DENIED (-3). Then rerun the `3.0.SERVER-TEST-SUITE` — 03/07 should pass.

## Enabling a command for the worker
Safe default: economy/service commands = `Enabled=0`. To enable one:
```sql
UPDATE PSM_Cmd.dbo.GmCommandAllowlist SET Enabled=1 WHERE Command='/exp2xenable' AND Service='ps_game';
```

## Rollback (if something goes wrong BEFORE step 9)
The old channel (`PS_GameDefs.dbo.Command`) keeps working until you run `06_remove_old.sql`.
To go back after step 9: re-register the old proc/assembly on PS_GameDefs (original guide scripts
`Versione PS_GameDefs\5-.sql`) and repoint the callers. Keep a backup before step 9.

## Security notes
- Destructive commands stay `Enabled=0`: only enable them if truly needed, and only for the worker/GM console.
- `worker.config.json` has plaintext credentials under the web root (already blocked by `.htaccess`):
  with `ShaiyaTaskAgent`, a leak only allows allowlisted commands. Still better to move it outside the web root.
