# Shaiya SERVER commands (ps_game / ps_login) — guide and criticality

## Server commands ≠ GM commands (client)
- **SERVER commands** (this document): executed by the **server process** (`ps_game.exe`,
  `ps_login.exe`), via the PSMServer console or via our `PSM_Cmd.usp_RunCommand`/`usp_SendNotice`
  channel. They act at server/world level (broadcast, kick, exp/enchant rates, shutdown, etc.).
- **GM commands** (on the web/in-game, e.g. `/imake`, `/move`, `/summon`): these are **client-side**
  game commands, executed in the GM character's context. **They are a different thing** and do NOT
  go through this channel.

## How the list was obtained (source)
- `/help` in the PSMServer console for `ps_game` and `ps_login`.
- Registration table decompiled with Ghidra: `ps_game.exe FUN_004090c0` → `Reg(id,"/cmd",numArgs,-1,flag)`
  (the number in `/help(N)` = **numArgs**; `flag=1` roughly maps to economy/persistent commands).
- Web confirmation: `/exp2xenable <rate>` = EXP rate (RaGEZONE). Many commands are NOT officially
  documented → descriptions marked **(inferred)** or **to confirm** where uncertain (verify in-game
  on a test server).

## Tier and criticality (mapped in `PSM_Cmd.dbo.GmCommandAllowlist`)
- **SAFE**: harmless info/broadcast (`/nt`, `/si`, `/uc`, `/mem`, `/servertime`, `/viewmap`).
- **PLAYER**: moderation (`/kickun`, `/kickuid`, `/kickcn`, `/kickcid`, `/setmaxuser`, `/nprotect*`).
- **ECONOMY**: rates/events that affect economy/PvP (`/exp2xenable`, `/enchant`, `/gemmix`, `/killcnt`,
  `/expupmap`, ...). **Disabled by default** (`Enabled=0`): enable only if needed.
- **SERVICE**: process control, **CRITICAL** (`/quit`, `/exit`, `/shutdown`, `/allout`, `/cstop`,
  `/cstart`, `/crashdump`; on login `/adminopen`, `/adminclose`). Always `Enabled=0`.

## ps_game — commands (arg = argument count from Ghidra)
| Command | args | Tier | Description | Notes |
|---|---|---|---|---|
| /nt | 1 | SAFE | Broadcast to all players | used by web/enchant notice |
| /si /mem /uc | 0 | SAFE | Server info / memory / users online | diagnostics |
| /servertime | 2 | SAFE | Server time | (inferred) |
| /viewmap | 1 | SAFE | Map info (mapId) | (inferred) |
| /chktimeout /ticktime /inszonecnt | 0 | SAFE | Diagnostics (timeout, tick, instance zone count) | (inferred) |
| /kickun /kickuid /kickcn /kickcid | 1 | PLAYER | Kick by Username / UserUID / CharName / CharID | moderation |
| /setmaxuser | 1 | PLAYER | Max concurrent users | capacity |
| /nprotecton /nprotectoff | 0 | PLAYER | nProtect/GameGuard anti-cheat on/off | off = RISKY (inferred) |
| /initpl | 0 | PLAYER | Reinitializes player list | (inferred, risky) |
| /aiset | 2 | PLAYER | Mob AI parameters | (inferred) |
| /exp2xenable /exp2xdisable | 1/0 | ECONOMY | EXP multiplier (rate, 100=x100) | **CONFIRMED** |
| /enchant /enchantreset | 4/0 | ECONOMY | Enchant success rate / reset | (inferred) |
| /gemmix /gemext /gemreset | 4/4/0 | ECONOMY | Gem/lapis mix/extend rate / reset | (inferred) |
| /killcnt /killcntreset | 4/0 | ECONOMY | Kill-count event/values / reset | (inferred) PvP |
| /expupcamp(reset) | 5/0 | ECONOMY | Faction exp-up campaign | (inferred) |
| /expupmap(reset) | 7/1 | ECONOMY | Per-map exp-up | (inferred) |
| /killupmap(reset) | 7/1 | ECONOMY | Per-map kill-up | (inferred) PvP |
| /resetstatcnt /resetskillcnt | 1 | ECONOMY | Reset stat/skill reroll counts | (inferred) |
| /addsr | 1 | ECONOMY | Adds "SR" | **to confirm** |
| /enableshop /disableshop /disablenshop /disablegift | 0 | ECONOMY | Toggle shop / item mall / gift | (inferred) |
| /enablekill /disablekill | 0 | ECONOMY | Toggle kill system | (inferred) |
| /quit /exit /shutdown | 0 | SERVICE | **Shuts down the game server** | **CRITICAL** |
| /allout | 0 | SERVICE | **Disconnects everyone** | **CRITICAL** |
| /cstop /cstart | 0 | SERVICE | Stop/start accepting connections | **CRITICAL** (inferred) |
| /crashdump | 0 | SERVICE | Process crash dump | **CRITICAL** (diagnostic) |

## ps_login — commands
| Command | args | Tier | Description | Notes |
|---|---|---|---|---|
| /nt | 1 | SAFE | Notice (login) | |
| /si /mem /uc /sl | 0 | SAFE | Info / sessions | /sl (inferred) |
| /vchg | 1 | PLAYER | Required client version | (inferred) |
| /setmaxuser | 1 | PLAYER | Max login users | |
| /vchkon /vchkoff | 0 | SERVICE | Client version check on/off | off = RISKY |
| /adminopen /adminclose | 0 | SERVICE | **Admin-only login (maintenance) / restore** | **CRITICAL** |
| /hide1svr /show1svr /showallsvr | 0 | SERVICE | Server visibility in the list | |
| /cstop /cstart | 0 | SERVICE | Stop/start login connections | **CRITICAL** |
| /shutdown | 0 | SERVICE | **Shuts down the login server** | **CRITICAL** |

## Operational notes
- Descriptions also live in `PSM_Cmd.dbo.GmCommandAllowlist.Description` (added column).
- Destructive/economy commands stay `Enabled=0`: enable only the ones actually needed, e.g.:
  `UPDATE PSM_Cmd.dbo.GmCommandAllowlist SET Enabled=1 WHERE Command='/exp2xenable' AND Service='ps_game';`
- "(inferred)" entries should be verified on a **test server** before use in production.
