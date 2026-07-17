# Modifica gameplay: notice enchant -> PSM_Cmd.usp_SendNotice

File: `PS_GameLog.dbo.usp_Insert_Action_Log_E` (sorgente guida: `..\..\Versione PS_GameDefs\7.usp_Insert_Action_Log_E_V2.sql`).
Account runtime: `S@o0#$h1908` (da `ps_gameLog.ini`). Gia' abilitato in PSM_Cmd da `04_principals_grants.sql`.

Cambia **solo** il blocco "Notice message on success enchant (18~20)". Il resto della proc resta invariato.

## PRIMA (attuale)
```sql
DECLARE @InputTextEnchantMsg VARCHAR(MAX) = 'Enhancement Success [' + @EnchantMsgPlayer + '] got ' + @ItemName + ' [+ ' + @UpgradeSuc + ']'
DECLARE @EnchantMsgPlayerNotice VARCHAR(MAX) = N'/nt ' + @InputTextEnchantMsg
EXEC @EnchantMsg = [PS_GameDefs].[dbo].[Command] @serviceName = N'ps_game', @cmmd = @EnchantMsgPlayerNotice
```

## DOPO (nuovo canale sicuro)
```sql
DECLARE @InputTextEnchantMsg VARCHAR(MAX) = 'Enhancement Success [' + @EnchantMsgPlayer + '] got ' + @ItemName + ' [+ ' + @UpgradeSuc + ']'
-- Il wrapper aggiunge '/nt' e sanifica il testo (CharName/ItemName sono dati giocatore).
EXEC @EnchantMsg = [PSM_Cmd].[dbo].[usp_SendNotice] @text = @InputTextEnchantMsg, @service = N'ps_game'
```

Nota: `usp_SendNotice` accetta `@text NVARCHAR(200)` e taglia a 150; il messaggio enchant rientra ampiamente.
Non passare piu' il prefisso `/nt` (lo aggiunge il wrapper).
