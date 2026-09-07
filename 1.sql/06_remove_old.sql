/* ============================================================================
   06_remove_old.sql  —  Remove the old CLR from PS_GameDefs + TRUSTWORTHY OFF
   Run as sysadmin ONLY AFTER 01-05 have been applied and TESTED (callers
   must already point to PSM_Cmd, otherwise /nt and the enchant notice break).
   ============================================================================ */
SET NOCOUNT ON;
USE [PS_GameDefs];
GO

IF OBJECT_ID('dbo.Command') IS NOT NULL
BEGIN
    DROP PROCEDURE dbo.Command;          -- removes exposure via the schema-wide Execute role
    PRINT 'PS_GameDefs: dbo.Command removed.';
END
GO
IF EXISTS (SELECT 1 FROM sys.assemblies WHERE name = 'PSMagent')
BEGIN
    DROP ASSEMBLY [PSMagent];
    PRINT 'PS_GameDefs: PSMagent assembly removed.';
END
GO

/* PS_GameDefs no longer hosts an EXTERNAL_ACCESS assembly -> TRUSTWORTHY can go (closes finding 03). */
ALTER DATABASE [PS_GameDefs] SET TRUSTWORTHY OFF;
PRINT 'PS_GameDefs: TRUSTWORTHY OFF.';
GO
