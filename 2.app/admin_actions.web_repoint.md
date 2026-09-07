# Repoint WEB (htdocs/admin_actions.php)

The web sends 3 commands through the `executeGameSlashCommand($pdoConn, 'ps_game', $cmd)` helper:
- `case 'send_notice'` → `/nt <text>`
- kick user → `/kickuid <userUID>`
- kick character → `/kickuid <targetUID>`

So the web doesn't only use `/nt`: it needs `usp_RunCommand` (handles /nt + /kick*), with the web
account `Ernoweb@` profiled as **tier PLAYER** (allows SAFE+PLAYER, blocks ECONOMY/SERVICE).

## Change (one line, in the helper body ~line 500)
BEFORE:
```php
$stmt = $pdoConn->prepare("EXEC [PS_GameDefs].[dbo].[Command] @serviceName = ?, @cmmd = ?");
```
AFTER:
```php
$stmt = $pdoConn->prepare("EXEC [PSM_Cmd].[dbo].[usp_RunCommand] @service = ?, @command = ?");
```
`$pdoConn` stays the web account `Ernoweb@`, which has EXECUTE on `usp_RunCommand` in PSM_Cmd
(cross-DB, explicit grant). No other change needed: the 3 callers already pass service + command.

Security effect: a SQLi as `Ernoweb@` can at most send tier SAFE/PLAYER commands (notice + kick) —
never `/exp2xenable`, `/shutdown`, etc. (blocked by tier + Enabled=0).
