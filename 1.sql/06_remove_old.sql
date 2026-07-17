/* ============================================================================
   06_remove_old.sql  —  Rimuovere la vecchia CLR da PS_GameDefs + TRUSTWORTHY OFF
   Esegui come sysadmin SOLO DOPO che 01-05 sono applicati e TESTATI (i chiamanti
   devono gia' puntare a PSM_Cmd, altrimenti /nt e notice enchant si rompono).
   ============================================================================ */
SET NOCOUNT ON;
USE [PS_GameDefs];
GO

IF OBJECT_ID('dbo.Command') IS NOT NULL
BEGIN
    DROP PROCEDURE dbo.Command;          -- toglie l'esposizione via ruolo MioRuoloExecute (schema-wide)
    PRINT 'PS_GameDefs: dbo.Command rimossa.';
END
GO
IF EXISTS (SELECT 1 FROM sys.assemblies WHERE name = 'PSMagent')
BEGIN
    DROP ASSEMBLY [PSMagent];
    PRINT 'PS_GameDefs: assembly PSMagent rimossa.';
END
GO

/* Ora PS_GameDefs non ospita piu' assembly EXTERNAL_ACCESS -> via TRUSTWORTHY (chiude finding 03). */
ALTER DATABASE [PS_GameDefs] SET TRUSTWORTHY OFF;
PRINT 'PS_GameDefs: TRUSTWORTHY OFF.';
GO
