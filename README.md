# PSM_Cmd — Canale comandi PSMagent sicuro (DB dedicato, firmato, allowlist+audit)

Guida di installazione **da zero** del canale comandi admin (`/nt`, comandi `ps_game`/`ps_login`) in modo
sicuro: assembly CLR **firmata** in un **DB dedicato chiuso** (`PSM_Cmd`), **senza TRUSTWORTHY**, con
**wrapper + allowlist + audit** e **account a privilegio minimo**.

Sostituisce il vecchio schema (assembly `PSMagent` EXTERNAL_ACCESS dentro `PS_GameDefs` con `TRUSTWORTHY ON`
ed EXECUTE concesso a tutta la schema via `MioRuoloExecute`).

> Ambiente verificato (2026-06): SQL Server **2022 Express** (16.0.1180.1), `clr strict security=1`,
> `cross db ownership chaining=0`. CLR + asymmetric key supportati su Express.

## Perche' (sintesi)
- **Isolamento**: la CLR privilegiata (apre socket → `:40900` → ps_game) esce dal DB dati gioco.
- **Niente TRUSTWORTHY**: l'assembly e' autorizzata dalla **firma** (asymmetric key in `master`), non da TRUSTWORTHY.
  → `PS_GameDefs` torna `TRUSTWORTHY OFF` (chiude i finding 03/07 della test suite).
- **Least privilege**: web (`Ernoweb@`) puo' solo `/nt`; worker (account dedicato `ShaiyaTaskAgent`) solo comandi
  in allowlist `Enabled=1`; gameplay (`S@o0#$h1908`) solo `/nt`. Nessuno tocca `Command` direttamente
  (wrapper `EXECUTE AS OWNER`). I comandi distruttivi (`/shutdown`, `/enchant`, …) sono `Enabled=0` di default.
- **Audit**: ogni comando in `PSM_Cmd.dbo.GmCommandLog`.

## Componenti
```
clr/Command.cs              CLR hardened (allowlist serviceName + socket using). Da firmare (SNK).
clr/Build-PSMagent.ps1/.bat Build+firma AUTOMATICI (csc+sn, niente VS). Output PSMagent.signed.dll.
clr/BUILD-AND-SIGN.md       Istruzioni build/firma da zero (script o VS).
clr/source-original-Database1/  Copia del progetto ORIGINALE (sln/sqlproj/Command.cs + dll) per riferimento.
sql/00_prereqs.sql          CLR on, verifica edition/flag.
sql/01_create_db_PSM_Cmd.sql  Crea PSM_Cmd chiuso (TRUSTWORTHY off, owner non-sysadmin, guest off).
sql/02_cert_and_assembly.sql  Asymmetric key da DLL firmata + assembly EXTERNAL_ACCESS + dbo.Command privata.
sql/03_wrappers_allowlist.sql Allowlist + log + usp_SendNotice + usp_RunCommand (EXECUTE AS OWNER).
sql/04_principals_grants.sql  Login ShaiyaTaskAgent + utenti + grant minimi sui soli wrapper.
sql/05_repoint_callers.sql    Istruzioni per ripuntare i 3 chiamanti (vedi app/).
sql/06_remove_old.sql         Rimuove Command+assembly da PS_GameDefs + TRUSTWORTHY OFF.
sql/07_verify.sql             Verifiche + test /nt + test negativo /shutdown.
app/usp_Insert_Action_Log_E_change.md   Patch gameplay (notice enchant).
app/admin_actions.send_notice.snippet.php  Patch web (send_notice).
app/worker.notes.md          Patch worker (account dedicato + usp_RunCommand).
PLAN.md                      Piano/architettura e razionale completo.
SERVER-COMMANDS-GUIDE.md     Comandi server ps_game/ps_login: cosa fanno, tier, criticita' (vs GM commands client).
```

> `GmCommandAllowlist` include una colonna **`Description`** (a cosa serve ogni comando) — vedi SERVER-COMMANDS-GUIDE.md.
> NB: i comandi SERVER (qui) sono diversi dai **GM commands client** (es. /imake /summon) che girano nel client.

## Ordine di installazione (server NUOVO o migrazione)
1. **Build & firma** la DLL: tasto destro su `clr/Build-PSMagent.bat` → **Esegui come amministratore**
   (genera `PSMagent.snk` e produce `C:\ShaiyaServer\PSM_Client\PSMagent.signed.dll`). Dettagli/fallback VS: `clr/BUILD-AND-SIGN.md`.
   Se buildi su un PC diverso dal server, copia la DLL firmata nel path del server.
2. `sql/00_prereqs.sql`  (sysadmin)
3. `sql/01_create_db_PSM_Cmd.sql`  → **cambia la password di `PSMCmdOwner`**.
4. `sql/02_cert_and_assembly.sql`  (verifica il path della DLL).
5. `sql/03_wrappers_allowlist.sql`
6. `sql/04_principals_grants.sql`  → **cambia la password di `ShaiyaTaskAgent`**.
7. **Repoint chiamanti** (`sql/05` + file in `app/`):
   - gameplay: modifica `PS_GameLog.usp_Insert_Action_Log_E` (blocco enchant).
   - web: patch `htdocs/admin_actions.php` (send_notice).
   - worker: `worker.config.json` → `ShaiyaTaskAgent`; comandi via `usp_RunCommand`.
8. **Test** `/nt` da web, notice enchant in-game, comando worker. Confermare che funzionano col NUOVO DB.
9. `sql/06_remove_old.sql`  (solo dopo che 1-8 funzionano: rimuove il vecchio + `PS_GameDefs TRUSTWORTHY OFF`).
10. `sql/07_verify.sql`  → atteso: Command assente in PS_GameDefs, assembly in PSM_Cmd, TRUSTWORTHY=0 ovunque,
    `/nt` di test OK, `/shutdown` DENIED (-3). Poi rilancia la test suite `3.0.SERVER-TEST-SUITE` → 03/07 verdi.

## Abilitare un comando per il worker
Default sicuro: economia/service = `Enabled=0`. Per abilitare quel che serve:
```sql
UPDATE PSM_Cmd.dbo.GmCommandAllowlist SET Enabled=1 WHERE Command='/exp2xenable' AND Service='ps_game';
```

## Rollback (se qualcosa non va PRIMA del passo 9)
Il vecchio canale (`PS_GameDefs.dbo.Command`) resta funzionante finche' non esegui `06_remove_old.sql`.
Per tornare indietro dopo il 9: ri-registra la vecchia proc/assembly su PS_GameDefs (script guida originali
`Versione PS_GameDefs\5-.sql`) e ripunta i chiamanti. Tieni un backup prima del passo 9.

## Note sicurezza
- I comandi distruttivi restano `Enabled=0`: abilitali solo se davvero servono e solo per il worker/console GM.
- `worker.config.json` ha credenziali in chiaro sotto la web root (gia' bloccato da `.htaccess`): con
  `ShaiyaTaskAgent` un leak permette solo comandi allowlist. Meglio comunque spostarlo fuori dalla web root.
