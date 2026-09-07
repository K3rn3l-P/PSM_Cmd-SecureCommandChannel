/* ============================================================================
   05_repoint_callers.sql  —  Repoint callers to the new DB
   Run as sysadmin AFTER 01-04 (PSM_Cmd ready) and BEFORE 06 (removing the old channel).
   ============================================================================ */

/* 1) GAMEPLAY (enchant notice) — apply the modified proc:
      ..\app\usp_Insert_Action_Log_E_V2.NEW.sql
   (changes only the "Notice message on success enchant" block: from
      EXEC [PS_GameDefs].[dbo].[Command] @serviceName=N'ps_game', @cmmd=N'/nt ...'
    to
      EXEC [PSM_Cmd].[dbo].[usp_SendNotice] @text=@InputTextEnchantMsg, @service=N'ps_game')   */

/* 2) WEB (send_notice) — apply the PHP patch:
      ..\app\admin_actions.send_notice.snippet.php
   Line 500 of htdocs/admin_actions.php changes from EXEC [PS_GameDefs].[dbo].[Command]
   to EXEC [PSM_Cmd].[dbo].[usp_SendNotice] @text=?  (stays on the Ernoweb@ account). */

/* 3) WORKER (economy) — see ..\app\worker.notes.md :
      - worker.config.json: User ID = ShaiyaTaskAgent (new password)
      - commands go through EXEC [PSM_Cmd].[dbo].[usp_RunCommand] @service=N'ps_game', @command=? */

PRINT 'Repoint: apply the 3 files in ..\app\ (gameplay/web/worker). No automated SQL here.';
GO
