/* ============================================================================
   05_repoint_callers.sql  —  Ripuntare i chiamanti al nuovo DB
   Esegui come sysadmin DOPO 01-04 (PSM_Cmd pronto) e PRIMA di 06 (rimozione vecchio).
   ============================================================================ */

/* 1) GAMEPLAY (enchant notice) — applicare la proc modificata:
      ..\app\usp_Insert_Action_Log_E_V2.NEW.sql
   (cambia solo il blocco "Notice message on success enchant": da
      EXEC [PS_GameDefs].[dbo].[Command] @serviceName=N'ps_game', @cmmd=N'/nt ...'
    a
      EXEC [PSM_Cmd].[dbo].[usp_SendNotice] @text=@InputTextEnchantMsg, @service=N'ps_game')   */

/* 2) WEB (send_notice) — applicare la patch PHP:
      ..\app\admin_actions.send_notice.snippet.php
   La riga 500 di htdocs/admin_actions.php passa da EXEC [PS_GameDefs].[dbo].[Command]
   a EXEC [PSM_Cmd].[dbo].[usp_SendNotice] @text=?  (resta account Ernoweb@). */

/* 3) WORKER (economia) — vedi ..\app\worker.notes.md :
      - worker.config.json: User ID = ShaiyaTaskAgent (nuova password)
      - i comandi vanno via EXEC [PSM_Cmd].[dbo].[usp_RunCommand] @service=N'ps_game', @command=? */

PRINT 'Repoint: applicare i 3 file in ..\app\ (gameplay/web/worker). Nessuna SQL automatica qui.';
GO
