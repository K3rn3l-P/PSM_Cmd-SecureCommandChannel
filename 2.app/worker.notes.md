# Repoint WORKER (task scheduler) — dedicated command connection

File: `htdocs/tools/task-scheduler-worker/worker.ps1` + `worker.config.json`.

The worker makes TWO kinds of SQL calls:
- **READ** (task list from the API, metadata lookups on the game DBs) → main connection
  `sql_connection_string` (stays **Ernoweb@**, which has read permissions).
- **COMMAND** (sending to ps_game) → **dedicated** connection `command_connection_string` =
  **ShaiyaTaskAgent → PSM_Cmd** (tier ECONOMY: allows /exp2xenable etc.).

Reason: web and worker used to share Ernoweb@, but the web is tier PLAYER and the worker is
ECONOMY → they can't share the command account. ShaiyaTaskAgent stays minimal (EXECUTE on the
PSM_Cmd wrappers only).

## 1) worker.config.json — add the command connection
```json
"command_connection_string": "Server=127.0.0.1;Database=PSM_Cmd;User ID=ShaiyaTaskAgent;Password=<password>;TrustServerCertificate=True;Encrypt=False;"
```

## 2) worker.ps1 — SERVICE_COMMAND block
BEFORE:
```powershell
$sql = 'EXEC [PS_GameDefs].[dbo].[Command] @serviceName = @ServiceName, @cmmd = @CmdText'
Invoke-SqlNonQuery -ConnectionString ([string]$Config.sql_connection_string) ...
```
AFTER:
```powershell
$sql = 'EXEC [PSM_Cmd].[dbo].[usp_RunCommand] @service = @ServiceName, @command = @CmdText'
Invoke-SqlNonQuery -ConnectionString ([string]$Config.command_connection_string) ...
```
(both Invoke-SqlNonQuery calls for the command + second_command use `command_connection_string`).

## Allowlist
Commands the worker sends MUST be `Enabled=1` in `PSM_Cmd.dbo.GmCommandAllowlist`
(e.g. `/exp2xenable`, `/nt` already are). To enable others:
```sql
UPDATE PSM_Cmd.dbo.GmCommandAllowlist SET Enabled=1 WHERE Command='/expupmap' AND Service='ps_game';
```
A disabled command → `usp_RunCommand` returns DENIED and logs to `GmCommandLog` (graceful fallback,
the job doesn't crash).

## Credential security
`worker.config.json` (under the web root, already blocked by .htaccess) holds 2 passwords. With
`ShaiyaTaskAgent`, a leak only allows allowlist/tier-limited commands — bounded damage. Recommended
to move the config outside the web root.
