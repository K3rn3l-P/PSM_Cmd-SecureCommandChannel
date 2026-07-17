# Repoint WEB (htdocs/admin_actions.php)

Il web invia 3 comandi tramite l'helper `executeGameSlashCommand($pdoConn, 'ps_game', $cmd)`:
- `case 'send_notice'` → `/nt <testo>`
- kick utente → `/kickuid <userUID>`
- kick personaggio → `/kickuid <targetUID>`

Quindi il web NON usa solo `/nt`: serve `usp_RunCommand` (gestisce /nt + /kick*), con l'account web
`Ernoweb@` profilato **tier PLAYER** (consente SAFE+PLAYER, blocca ECONOMY/SERVICE).

## Modifica (una riga, nel corpo dell'helper ~riga 500)
PRIMA:
```php
$stmt = $pdoConn->prepare("EXEC [PS_GameDefs].[dbo].[Command] @serviceName = ?, @cmmd = ?");
```
DOPO:
```php
$stmt = $pdoConn->prepare("EXEC [PSM_Cmd].[dbo].[usp_RunCommand] @service = ?, @command = ?");
```
`$pdoConn` resta l'account web `Ernoweb@`, che ha EXECUTE su `usp_RunCommand` in PSM_Cmd (cross-DB, grant esplicito).
Nessun'altra modifica: i 3 chiamanti passano gia' service + comando.

Effetto sicurezza: una SQLi come `Ernoweb@` puo' al massimo inviare comandi tier SAFE/PLAYER
(notice + kick) — mai `/exp2xenable`, `/shutdown`, ecc. (bloccati dal tier + Enabled=0).
