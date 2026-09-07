# Plan / architecture — Secure PSMagent command channel

## Verified state (live SQL, 2026-06)
- SQL Server **2022 Express** (16.0.1180.1). `clr strict security=1`, `cross db ownership chaining=0`.
- **`PSMagent`** assembly = `EXTERNAL_ACCESS`, inside **PS_GameDefs**, `TRUSTWORTHY ON`, DB owner =
  `WIN\Administrator` (sysadmin).
- Proc `[PS_GameDefs].[dbo].[Command]` → CLR → socket `127.0.0.1:40900` → native `ps_game`/`ps_login`
  commands (known set extracted from Ghidra `ps_game.exe FUN_004090c0` + `/help`).
- `EXECUTE` on `Command` **is not granted directly**: a custom `Execute` role (not a SQL Server
  built-in, created for this project) = `GRANT EXECUTE ON SCHEMA::dbo` → execute on the WHOLE
  schema. Members: **`Ernoweb@`** (web+worker) and **`S@o0#$h1908`** (game/log services).
- **3 callers**: web `admin_actions.php` (`/nt`), worker `worker.ps1` (economy, Ernoweb@ account),
  gameplay `PS_GameLog.usp_Insert_Action_Log_E` (enchant notice, S@o0 account).

## Risks
1. **Schema-wide `Execute` role** (`GRANT EXECUTE ON SCHEMA::dbo`) → web/worker/game can run **any**
   procedure in the schema, including the privileged CLR bridge itself (`dbo.Command`): `/shutdown`,
   `/enchant`, anything. A SQLi as `Ernoweb@` anywhere on the site ⇒ DoS + destroys the game server
   economy.

   **General rule, not just a fix for this case**: never grant permissions at the schema or server
   level as a shortcut — and never reach for the real `sysadmin` server role on an application
   account either, a shortcut seen often in practice and far worse than this one. Grant per object,
   only what each caller actually needs: a role, even a narrowly-named custom one, is not
   granularity by itself — the grants inside it are what matter. That's what the rest of this
   project replaces it with (the wrappers + `GmCallerProfile` tiers below), not a better role.
2. `TRUSTWORTHY ON` on PS_GameDefs (test suite finding 03/07).
3. No allowlist/audit at the DB level. Player input (CharName/ItemName) enters the channel via the
   enchant notice.

## Decision
- **Code (B)**: original CLR (`C:\Users\lol\Desktop\Database1`) hardened (serviceName allowlist,
  socket `using`), **SNK-signed**. Discarded `D:\Download\PSM_Agent-main` (Now/UtcNow throttle bug,
  unknown provenance).
- **Dedicated, closed `PSM_Cmd` database**: signed assembly (no TRUSTWORTHY), non-sysadmin owner,
  guest off, db_chaining off.

## Target architecture
- `PSM_Cmd.dbo.Command` (CLR EXTERNAL NAME) **private** (no grants).
- `usp_SendNotice(@text)` — `/nt` only, sanitizes the text. For web + enchant notice.
- `usp_RunCommand(@service,@command)` — allowlist (`GmCommandAllowlist`, destructive = `Enabled=0`) +
  audit (`GmCommandLog`). For the worker.
- Both run `WITH EXECUTE AS OWNER` → callers do NOT have EXECUTE on `Command`.
- Least-privilege accounts + **tier per caller** (`GmCallerProfile`): `Ernoweb@` (web) → usp_RunCommand
  tier PLAYER (/nt + /kick*, no economy/service); `S@o0#$h1908` (gameplay) → usp_SendNotice
  (sanitized /nt); `ShaiyaTaskAgent` (worker, dedicated connection) → usp_RunCommand tier ECONOMY.
- Remove `Command` from PS_GameDefs → `PS_GameDefs TRUSTWORTHY OFF`.

## Benefit
- Web SQLi (Ernoweb@) ⇒ at most a `/nt` broadcast, never destructive commands.
- Economy/service commands only via the isolated worker + allowlist + audit.
- PS_GameDefs and PSM_Cmd both `TRUSTWORTHY OFF` (test suite 03/07 pass).

## Implementation
See `README.md` (steps 1→10) and the scripts in `sql/` + patches in `app/` + build in `clr/`.
To confirm at execution time: new passwords (`PSMCmdOwner`, `ShaiyaTaskAgent`), the signed DLL path,
and end-to-end testing on staging before `06_remove_old.sql`.
