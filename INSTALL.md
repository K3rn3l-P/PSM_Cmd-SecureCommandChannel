# Guida installazione — PSM_Cmd Secure Command Channel

Guida operativa passo-passo per installare il canale comandi PSMagent sicuro **da zero** su un
server Shaiya (SQL Server 2022 Express). Per il "perche'" architetturale vedi `PLAN.md`; per il
riepilogo componenti vedi `README.md`.

> ⚠️ **Segreti**: gli script SQL contengono `N'La_tua_password'` come placeholder. Sostituiscili
> con password reali forti PRIMA di eseguire gli script in produzione. Non committare mai password
> reali nel repo.

## Albero del repository

```
PSM_Cmd-SecureCommandChannel/
├── README.md                          Panoramica architettura + ordine installazione sintetico
├── PLAN.md                            Piano/razionale: rischi, decisioni, beneficio
├── SERVER-COMMANDS-GUIDE.md           Catalogo comandi ps_game/ps_login (tier SAFE/PLAYER/ECONOMY/SERVICE)
├── INSTALL.md                         Questa guida
│
├── 1.sql/                             Script SQL, da eseguire IN ORDINE (00 → 07)
│   ├── 00_prereqs.sql                 Abilita CLR, verifica edition/flag server
│   ├── 01_create_db_PSM_Cmd.sql       Crea DB PSM_Cmd chiuso (TRUSTWORTHY off, owner dedicato)
│   ├── 02_cert_and_assembly.sql       Registra assembly firmata via asymmetric key in master
│   ├── 03_wrappers_allowlist.sql      Crea allowlist, log audit, usp_SendNotice, usp_RunCommand
│   ├── 04_principals_grants.sql       Crea login ShaiyaTaskAgent + utenti + grant minimi sui wrapper
│   ├── 05_repoint_callers.sql         Note: quali file applicare in 2.app/ per ripuntare i chiamanti
│   ├── 06_remove_old.sql              Rimuove il vecchio canale da PS_GameDefs (SOLO dopo test OK)
│   └── 07_verify.sql                  Verifiche finali + test positivo/negativo
│
├── 2.app/                             Patch applicative (i "3 chiamanti" da ripuntare)
│   ├── usp_Insert_Action_Log_E_change.md      Patch gameplay: notice enchant → usp_SendNotice
│   ├── admin_actions.web_repoint.md           Patch web: admin_actions.php → usp_RunCommand
│   └── worker.notes.md                        Patch worker: nuova connessione dedicata ShaiyaTaskAgent
│
├── clr/                               Sorgente e build della CLR assembly
│   ├── Command.cs                     Sorgente hardened (allowlist serviceName, socket `using`)
│   ├── Build-PSMagent.ps1             Script di build+firma (PowerShell)
│   ├── Build-PSMagent.bat             Wrapper .bat: doppio click → Esegui come amministratore
│   ├── BUILD-AND-SIGN.md               Istruzioni build/firma dettagliate (script o Visual Studio)
│   ├── source-original-Database1/     Progetto SSDT originale (riferimento, NON per deploy sicuro)
│   └── PSMagent.snk                   Chiave privata strong-name — GENERATA in locale, MAI nel repo
│
└── .gitignore                         Esclude PSMagent.snk, *.dll/*.pdb/*.dacpac, junk build/IDE
```

> `PSMagent.snk` e i `.dll` compilati **non sono nel repo** (vedi `.gitignore`): si generano/ricompilano
> in locale con `clr/Build-PSMagent.bat`. Conserva la `.snk` fuori dal repo e fuori dalla web root.

## Prerequisiti

- SQL Server **2022 Express** (o superiore) con accesso `sysadmin`.
- `clr strict security = 1` (default moderno) — gestito da `00_prereqs.sql`.
- Windows con **.NET Framework 4** (`csc.exe`, sempre presente) per la build della CLR.
- `sn.exe` per firmare l'assembly (incluso con Visual Studio o Windows SDK) — vedi `clr/BUILD-AND-SIGN.md`
  per fallback se manca.
- Accesso al server dove gira `ps_game.exe`/`ps_login.exe` in ascolto su `127.0.0.1:40900`.
- I "3 chiamanti" esistenti da ripuntare: `htdocs/admin_actions.php` (web), `worker.ps1` +
  `worker.config.json` (task-scheduler), `PS_GameLog.dbo.usp_Insert_Action_Log_E` (gameplay).

## Step di installazione (server nuovo o migrazione)

### 1. Build & firma della DLL
```
clr/Build-PSMagent.bat  → tasto destro → Esegui come amministratore
```
Genera `clr/PSMagent.snk` (al primo run — **conservala**, non rigenerarla) e produce
`C:\ShaiyaServer\PSM_Client\PSMagent.signed.dll`. Se buildi su un PC diverso dal server, copia la
DLL firmata nel path del server. Dettagli/fallback (Visual Studio): `clr/BUILD-AND-SIGN.md`.

### 2. Prerequisiti SQL
```sql
-- come sysadmin
:r 1.sql\00_prereqs.sql
```
Abilita CLR, verifica edition e i flag di sicurezza del server.

### 3. Creare il DB dedicato
Prima di eseguire, apri `1.sql/01_create_db_PSM_Cmd.sql` e sostituisci
`N'La_tua_password'` con una password reale forte per il login `PSMCmdOwner`.
```sql
:r 1.sql\01_create_db_PSM_Cmd.sql
```
Crea `PSM_Cmd` con `TRUSTWORTHY OFF`, `DB_CHAINING OFF`, owner dedicato non-sysadmin, guest revocato.

### 4. Registrare assembly firmata
Verifica il path della DLL firmata nello script, poi:
```sql
:r 1.sql\02_cert_and_assembly.sql
```
Crea l'asymmetric key da `PSMagent.signed.dll` in `master`, registra l'assembly `EXTERNAL_ACCESS`
autorizzata dalla firma (no TRUSTWORTHY), crea `dbo.Command` privata (nessun grant diretto).

### 5. Wrapper + allowlist + audit
```sql
:r 1.sql\03_wrappers_allowlist.sql
```
Crea `GmCommandAllowlist` (con colonna `Description`), `GmCommandLog` (audit), le proc
`usp_SendNotice` e `usp_RunCommand` (entrambe `EXECUTE AS OWNER`).

### 6. Account e grant minimi
Prima di eseguire, apri `1.sql/04_principals_grants.sql` e sostituisci `N'La_tua_password'`
con una password reale forte per il login `ShaiyaTaskAgent`.
```sql
:r 1.sql\04_principals_grants.sql
```
Crea il login dedicato `ShaiyaTaskAgent` (worker) e i grant minimi sui SOLI wrapper — mai su
`dbo.Command` direttamente:
- `Ernoweb@` (web) → `usp_RunCommand` (tier PLAYER: `/nt` + `/kick*`) + `usp_SendNotice`.
- `S@o0#$h1908` (gameplay) → solo `usp_SendNotice` (notice enchant sanificato).
- `ShaiyaTaskAgent` (worker) → `usp_RunCommand` (tier ECONOMY) + `usp_SendNotice`.

### 7. Ripuntare i 3 chiamanti
Vedi `1.sql/05_repoint_callers.sql` per l'elenco, poi applica le patch descritte in `2.app/`:

| Chiamante | File da modificare | Guida |
|---|---|---|
| Gameplay (notice enchant) | `PS_GameLog.dbo.usp_Insert_Action_Log_E` | `2.app/usp_Insert_Action_Log_E_change.md` |
| Web (send_notice / kick) | `htdocs/admin_actions.php` (~riga 500) | `2.app/admin_actions.web_repoint.md` |
| Worker (task-scheduler, economia) | `worker.ps1` + `worker.config.json` | `2.app/worker.notes.md` |

Per il worker: aggiungi in `worker.config.json` la connessione dedicata
`command_connection_string` con `User ID=ShaiyaTaskAgent;Password=La_tua_password;...`
(usa la password reale scelta al passo 6, non committarla in chiaro nei tuoi file di config).

### 8. Test end-to-end
Con il **nuovo** DB attivo, verifica:
- `/nt` inviato da web (send_notice) funziona.
- Notice enchant in-game funziona.
- Un comando worker (es. `/exp2xenable`, gia' abilitato) funziona.

### 9. Rimuovere il vecchio canale
**Solo dopo** che lo step 8 e' verde:
```sql
:r 1.sql\06_remove_old.sql
```
Rimuove `Command` + assembly da `PS_GameDefs` e imposta `TRUSTWORTHY OFF`.

### 10. Verifica finale
```sql
:r 1.sql\07_verify.sql
```
Atteso: `Command` assente in `PS_GameDefs`, assembly presente in `PSM_Cmd`, `TRUSTWORTHY=0`
ovunque, test `/nt` OK, test negativo `/shutdown` → DENIED (-3).

## Abilitare un comando aggiuntivo per il worker

Default sicuro: comandi economia/service = `Enabled=0`. Per abilitarne uno:
```sql
UPDATE PSM_Cmd.dbo.GmCommandAllowlist SET Enabled=1 WHERE Command='/exp2xenable' AND Service='ps_game';
```
Catalogo completo comandi/tier: `SERVER-COMMANDS-GUIDE.md`.

## Rollback

Se qualcosa non va **prima** dello step 9: il vecchio canale (`PS_GameDefs.dbo.Command`) resta
funzionante finche' non esegui `06_remove_old.sql` — nessuna azione necessaria, i chiamanti non
ancora ripuntati continuano a usare il vecchio path.

Se devi tornare indietro **dopo** lo step 9: ri-registra la vecchia proc/assembly su `PS_GameDefs`
(dai tuoi script guida originali) e ripunta i chiamanti al vecchio canale. Tieni sempre un backup
del DB prima dello step 9.

## Note sicurezza

- I comandi distruttivi (`/shutdown`, `/enchant`, controlli SERVICE, ecc.) restano `Enabled=0` di
  default: abilitali solo se servono davvero, e solo per account/tier che ne hanno reale bisogno.
- Se il file di config del worker contiene credenziali in chiaro, tienilo **fuori dalla web root**
  e protetto da permessi filesystem (oltre a un eventuale `.htaccess`).
- Riusa sempre la stessa `PSMagent.snk` per ricompilare: la chiave pubblica non cambia, quindi
  l'asymmetric key in `master` resta valida. Se la rigeneri, devi rifare `02_cert_and_assembly.sql`.
- Non committare mai `PSMagent.snk`, password reali, o file DLL compilati nel repo (vedi `.gitignore`).
