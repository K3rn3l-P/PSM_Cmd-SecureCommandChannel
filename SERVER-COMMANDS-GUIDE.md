# Comandi SERVER Shaiya (ps_game / ps_login) — guida e criticita'

## Server commands ≠ GM commands (client)
- **Comandi SERVER** (questo documento): eseguiti dal **processo server** (`ps_game.exe`, `ps_login.exe`),
  via la console del PSMServer o via il nostro canale `PSM_Cmd.usp_RunCommand`/`usp_SendNotice`.
  Agiscono a livello di server/mondo (broadcast, kick, rate exp/enchant, shutdown, ecc.).
- **GM commands** (sul web/in gioco, es. `/imake`, `/move`, `/summon`): sono comandi **client-side** del
  gioco, eseguiti nel contesto del personaggio GM. **Sono un'altra cosa** e NON passano da questo canale.

## Come si ottiene la lista (fonte)
- `/help` nella console PSMServer per `ps_game` e `ps_login`.
- Tabella di registrazione decompilata da Ghidra: `ps_game.exe FUN_004090c0` → `Reg(id,"/cmd",numArgs,-1,flag)`
  (il numero in `/help(N)` = **numArgs**; `flag=1` ~ comandi economia/persistenti).
- Conferme web: `/exp2xenable <rate>` = rate EXP (RaGEZONE). Molti comandi NON sono documentati ufficialmente
  → descrizioni marcate **(inferito)** o **da confermare** dove non certo (verificare in-game su server di prova).

## Tier e criticita' (mappato in `PSM_Cmd.dbo.GmCommandAllowlist`)
- **SAFE**: info/broadcast innocui (`/nt`, `/si`, `/uc`, `/mem`, `/servertime`, `/viewmap`).
- **PLAYER**: moderazione (`/kickun`, `/kickuid`, `/kickcn`, `/kickcid`, `/setmaxuser`, `/nprotect*`).
- **ECONOMY**: rate/eventi che impattano economia/PvP (`/exp2xenable`, `/enchant`, `/gemmix`, `/killcnt`,
  `/expupmap`, ...). **Disabilitati di default** (`Enabled=0`): abilitare solo se servono.
- **SERVICE**: controllo processo, **CRITICI** (`/quit`, `/exit`, `/shutdown`, `/allout`, `/cstop`,
  `/cstart`, `/crashdump`; su login `/adminopen`, `/adminclose`). Sempre `Enabled=0`.

## ps_game — comandi (arg = numero argomenti da Ghidra)
| Comando | arg | Tier | Descrizione | Note |
|---|---|---|---|---|
| /nt | 1 | SAFE | Broadcast a tutti i giocatori | usato dal web/notice enchant |
| /si /mem /uc | 0 | SAFE | Info server / memoria / utenti online | diagnostici |
| /servertime | 2 | SAFE | Ora del server | (inferito) |
| /viewmap | 1 | SAFE | Info mappa (mapId) | (inferito) |
| /chktimeout /ticktime /inszonecnt | 0 | SAFE | Diagnostici (timeout, tick, zone istanza) | (inferito) |
| /kickun /kickuid /kickcn /kickcid | 1 | PLAYER | Espelle per Username / UserUID / CharName / CharID | moderazione |
| /setmaxuser | 1 | PLAYER | Max utenti concorrenti | capacita' |
| /nprotecton /nprotectoff | 0 | PLAYER | Anti-cheat nProtect/GameGuard on/off | off = RISCHIOSO (inferito) |
| /initpl | 0 | PLAYER | Reinizializza lista player | (inferito, rischioso) |
| /aiset | 2 | PLAYER | Parametri AI mob | (inferito) |
| /exp2xenable /exp2xdisable | 1/0 | ECONOMY | Moltiplicatore EXP (rate, 100=x100) | **CONFERMATO** |
| /enchant /enchantreset | 4/0 | ECONOMY | Rate successo enchant / reset | (inferito) |
| /gemmix /gemext /gemreset | 4/4/0 | ECONOMY | Rate gem/lapis mix/extend / reset | (inferito) |
| /killcnt /killcntreset | 4/0 | ECONOMY | Evento/valori kill count / reset | (inferito) PvP |
| /expupcamp(reset) | 5/0 | ECONOMY | Campagna exp-up per fazione | (inferito) |
| /expupmap(reset) | 7/1 | ECONOMY | Exp-up per mappa | (inferito) |
| /killupmap(reset) | 7/1 | ECONOMY | Kill-up per mappa | (inferito) PvP |
| /resetstatcnt /resetskillcnt | 1 | ECONOMY | Reset conteggi reroll stat/skill | (inferito) |
| /addsr | 1 | ECONOMY | Aggiunge "SR" | **da confermare** |
| /enableshop /disableshop /disablenshop /disablegift | 0 | ECONOMY | Toggle shop / item mall / gift | (inferito) |
| /enablekill /disablekill | 0 | ECONOMY | Toggle sistema kill | (inferito) |
| /quit /exit /shutdown | 0 | SERVICE | **Spegne il server di gioco** | **CRITICO** |
| /allout | 0 | SERVICE | **Disconnette tutti** | **CRITICO** |
| /cstop /cstart | 0 | SERVICE | Ferma/avvia accettazione connessioni | **CRITICO** (inferito) |
| /crashdump | 0 | SERVICE | Crash dump del processo | **CRITICO** (diagnostico) |

## ps_login — comandi
| Comando | arg | Tier | Descrizione | Note |
|---|---|---|---|---|
| /nt | 1 | SAFE | Notice (login) | |
| /si /mem /uc /sl | 0 | SAFE | Info / sessioni | /sl (inferito) |
| /vchg | 1 | PLAYER | Versione client richiesta | (inferito) |
| /setmaxuser | 1 | PLAYER | Max utenti login | |
| /vchkon /vchkoff | 0 | SERVICE | Controllo versione client on/off | off = RISCHIOSO |
| /adminopen /adminclose | 0 | SERVICE | **Login solo admin (manutenzione) / ripristino** | **CRITICO** |
| /hide1svr /show1svr /showallsvr | 0 | SERVICE | Visibilita' server nella lista | |
| /cstop /cstart | 0 | SERVICE | Ferma/avvia connessioni login | **CRITICO** |
| /shutdown | 0 | SERVICE | **Shutdown login server** | **CRITICO** |

## Note operative
- Le descrizioni vivono anche in `PSM_Cmd.dbo.GmCommandAllowlist.Description` (colonna aggiunta).
- I comandi distruttivi/economia restano `Enabled=0`: abilitare puntualmente solo quelli necessari, es.:
  `UPDATE PSM_Cmd.dbo.GmCommandAllowlist SET Enabled=1 WHERE Command='/exp2xenable' AND Service='ps_game';`
- I "(inferito)" andrebbero verificati su **server di prova** prima di usarli in produzione.
