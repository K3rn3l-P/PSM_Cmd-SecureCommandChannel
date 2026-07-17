# Repoint WORKER (task-scheduler) — connessione comandi dedicata

File: `htdocs/tools/task-scheduler-worker/worker.ps1` + `worker.config.json`.

Il worker fa DUE tipi di SQL:
- **READ** (lista task dall'API, risoluzione meta dai DB gioco) → connessione principale `sql_connection_string`
  (resta **Ernoweb@**, che ha i permessi di lettura).
- **COMANDO** (invio a ps_game) → connessione **dedicata** `command_connection_string` = **ShaiyaTaskAgent → PSM_Cmd**
  (tier ECONOMY: consente /exp2xenable ecc.).

Motivo: web e worker condividevano Ernoweb@, ma il web e' tier PLAYER e il worker ECONOMY → non possono
condividere l'account per i comandi. ShaiyaTaskAgent resta minimo (solo EXECUTE sui wrapper di PSM_Cmd).

## 1) worker.config.json — aggiungere la connessione comandi
```json
"command_connection_string": "Server=127.0.0.1;Database=PSM_Cmd;User ID=ShaiyaTaskAgent;Password=<password>;TrustServerCertificate=True;Encrypt=False;"
```

## 2) worker.ps1 — blocco SERVICE_COMMAND
PRIMA:
```powershell
$sql = 'EXEC [PS_GameDefs].[dbo].[Command] @serviceName = @ServiceName, @cmmd = @CmdText'
Invoke-SqlNonQuery -ConnectionString ([string]$Config.sql_connection_string) ...
```
DOPO:
```powershell
$sql = 'EXEC [PSM_Cmd].[dbo].[usp_RunCommand] @service = @ServiceName, @command = @CmdText'
Invoke-SqlNonQuery -ConnectionString ([string]$Config.command_connection_string) ...
```
(entrambe le Invoke-SqlNonQuery del comando + second_command usano `command_connection_string`).

## Allowlist
I comandi che il worker invia DEVONO essere `Enabled=1` in `PSM_Cmd.dbo.GmCommandAllowlist`
(es. `/exp2xenable`, `/nt` lo sono). Per abilitarne altri:
```sql
UPDATE PSM_Cmd.dbo.GmCommandAllowlist SET Enabled=1 WHERE Command='/expupmap' AND Service='ps_game';
```
Un comando non abilitato → `usp_RunCommand` ritorna DENIED e logga in `GmCommandLog` (fallback grazioso, il job non crasha).

## Sicurezza credenziali
`worker.config.json` (sotto web root, gia' bloccato da .htaccess) contiene 2 password. Con `ShaiyaTaskAgent`
un leak permette solo comandi allowlist/tier — danno limitato. Consigliato spostare il config fuori dalla web root.
