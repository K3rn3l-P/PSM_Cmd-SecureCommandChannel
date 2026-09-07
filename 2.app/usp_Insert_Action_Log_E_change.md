# Gameplay change: enchant notice -> PSM_Cmd.usp_SendNotice

File: `PS_GameLog.dbo.usp_Insert_Action_Log_E` (source guide: `..\..\Versione PS_GameDefs\7.usp_Insert_Action_Log_E_V2.sql`).
Runtime account: `S@o0#$h1908` (from `ps_gameLog.ini`). Already enabled in PSM_Cmd by `04_principals_grants.sql`.

Change **only** the "Notice message on success enchant (18~20)" block. The rest of the proc stays unchanged.

## BEFORE (current)
```sql
DECLARE @InputTextEnchantMsg VARCHAR(MAX) = 'Enhancement Success [' + @EnchantMsgPlayer + '] got ' + @ItemName + ' [+ ' + @UpgradeSuc + ']'
DECLARE @EnchantMsgPlayerNotice VARCHAR(MAX) = N'/nt ' + @InputTextEnchantMsg
EXEC @EnchantMsg = [PS_GameDefs].[dbo].[Command] @serviceName = N'ps_game', @cmmd = @EnchantMsgPlayerNotice
```

## AFTER (new secure channel)
```sql
DECLARE @InputTextEnchantMsg VARCHAR(MAX) = 'Enhancement Success [' + @EnchantMsgPlayer + '] got ' + @ItemName + ' [+ ' + @UpgradeSuc + ']'
-- The wrapper prepends '/nt' and sanitizes the text (CharName/ItemName are player-controlled data).
EXEC @EnchantMsg = [PSM_Cmd].[dbo].[usp_SendNotice] @text = @InputTextEnchantMsg, @service = N'ps_game'
```

Note: `usp_SendNotice` accepts `@text NVARCHAR(200)` and truncates to 150; the enchant message
fits comfortably. Don't pass the `/nt` prefix anymore — the wrapper adds it.
