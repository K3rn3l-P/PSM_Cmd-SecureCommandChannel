# Piano / architettura — Canale comandi PSMagent sicuro

## Stato verificato (SQL live, 2026-06)
- SQL Server **2022 Express** (16.0.1180.1). `clr strict security=1`, `cross db ownership chaining=0`.
- Assembly **`PSMagent`** = `EXTERNAL_ACCESS`, in **PS_GameDefs**, `TRUSTWORTHY ON`, owner DB = `WIN\Administrator` (sysadmin).
- Proc `[PS_GameDefs].[dbo].[Command]` → CLR → socket `127.0.0.1:40900` → comandi nativi `ps_game`/`ps_login`
  (set noto estratto da Ghidra `ps_game.exe FUN_004090c0` + `/help`).
- `EXECUTE` su `Command` **non diretto**: `MioRuoloExecute` = `GRANT EXECUTE ON SCHEMA::dbo` → execute su TUTTA la
  schema. Membri: **`Ernoweb@`** (web+worker) e **`S@o0#$h1908`** (servizi game/log).
- **3 chiamanti**: web `admin_actions.php` (`/nt`), worker `worker.ps1` (economia, account Ernoweb@),
  gameplay `PS_GameLog.usp_Insert_Action_Log_E` (notice enchant, account S@o0).

## Rischi
1. `MioRuoloExecute` schema-wide → web/worker/game possono eseguire **qualsiasi** comando (`/shutdown`, `/enchant`…).
   Una SQLi come `Ernoweb@` ovunque nel sito ⇒ DoS + distruzione economia del game server.
2. `TRUSTWORTHY ON` su PS_GameDefs (finding suite 03/07).
3. Nessun allowlist/audit lato DB. Input giocatore (CharName/ItemName) entra nel canale via notice enchant.

## Decisione
- **Codice (B)**: CLR originale (`C:\Users\lol\Desktop\Database1`) hardened (allowlist serviceName, socket `using`),
  **firmata SNK**. Scartato `D:\Download\PSM_Agent-main` (throttle bug Now/UtcNow, provenienza ignota).
- **DB dedicato chiuso `PSM_Cmd`**: assembly firmata (no TRUSTWORTHY), owner non-sysadmin, guest off, db_chaining off.

## Architettura target
- `PSM_Cmd.dbo.Command` (CLR EXTERNAL NAME) **privata** (nessun grant).
- `usp_SendNotice(@text)` — solo `/nt`, sanifica testo. Per web + notice enchant.
- `usp_RunCommand(@service,@command)` — allowlist (`GmCommandAllowlist`, distruttivi `Enabled=0`) + audit (`GmCommandLog`). Per worker.
- Entrambi `WITH EXECUTE AS OWNER` → i chiamanti NON hanno EXECUTE su `Command`.
- Account/grant minimi + **tier per chiamante** (`GmCallerProfile`): `Ernoweb@` (web)→usp_RunCommand tier PLAYER
  (/nt + /kick*, no economia/service); `S@o0#$h1908` (gameplay)→usp_SendNotice (/nt sanificato);
  `ShaiyaTaskAgent` (worker, connessione dedicata)→usp_RunCommand tier ECONOMY.
- Rimuovere `Command` da PS_GameDefs → `PS_GameDefs TRUSTWORTHY OFF`.

## Beneficio
- SQLi web (Ernoweb@) ⇒ al massimo un broadcast `/nt`, non comandi distruttivi.
- Comandi economia/servizio solo via worker isolato + allowlist + audit.
- PS_GameDefs e PSM_Cmd entrambi `TRUSTWORTHY OFF` (test suite 03/07 verdi).

## Implementazione
Vedi `README.md` (ordine 1→10) e gli script in `sql/` + patch in `app/` + build in `clr/`.
Da confermare in fase esecuzione: password nuove (`PSMCmdOwner`, `ShaiyaTaskAgent`), path DLL firmata,
e test end-to-end su prova prima del `06_remove_old.sql`.
