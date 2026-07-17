/* ============================================================================
   04_principals_grants.sql  —  Account + grant minimi (least-privilege)
   Esegui come sysadmin.
   Mappa accessi:
     - Ernoweb@        (web)      -> SOLO usp_SendNotice  (/nt). Una SQLi web puo' solo broadcastare.
     - S@o0#$h1908     (gameplay) -> SOLO usp_SendNotice  (notice enchant).
     - ShaiyaTaskAgent (worker)   -> usp_RunCommand (comandi economia in allowlist) + usp_SendNotice.
   Nessuno ha EXECUTE diretto su dbo.Command (i wrapper girano EXECUTE AS OWNER).
   ============================================================================ */
SET NOCOUNT ON;

/* Account dedicato per il task-scheduler worker (separa il potere "comandi" dal web Ernoweb@). */
IF NOT EXISTS (SELECT 1 FROM sys.server_principals WHERE name = 'ShaiyaTaskAgent')
    CREATE LOGIN [ShaiyaTaskAgent] WITH PASSWORD = N'La_tua_password', CHECK_POLICY = ON;
GO

USE [PSM_Cmd];
GO
/* Utenti nel DB chiuso (mappati ai login esistenti). */
IF NOT EXISTS (SELECT 1 FROM sys.database_principals WHERE name = 'Ernoweb@')
    CREATE USER [Ernoweb@] FOR LOGIN [Ernoweb@];
IF NOT EXISTS (SELECT 1 FROM sys.database_principals WHERE name = 'S@o0#$h1908')
    CREATE USER [S@o0#$h1908] FOR LOGIN [S@o0#$h1908];
IF NOT EXISTS (SELECT 1 FROM sys.database_principals WHERE name = 'ShaiyaTaskAgent')
    CREATE USER [ShaiyaTaskAgent] FOR LOGIN [ShaiyaTaskAgent];
GO

/* Grant minimi sui SOLI wrapper (mai su dbo.Command). */
-- Web: usp_RunCommand (tier PLAYER -> /nt + kick) e usp_SendNotice (notice sanificato).
GRANT EXECUTE ON OBJECT::dbo.usp_RunCommand TO [Ernoweb@];
GRANT EXECUTE ON OBJECT::dbo.usp_SendNotice TO [Ernoweb@];
-- Gameplay (enchant notice): solo usp_SendNotice (/nt sanificato).
GRANT EXECUTE ON OBJECT::dbo.usp_SendNotice TO [S@o0#$h1908];
-- Worker: usp_RunCommand (tier ECONOMY) + usp_SendNotice.
GRANT EXECUTE ON OBJECT::dbo.usp_RunCommand TO [ShaiyaTaskAgent];
GRANT EXECUTE ON OBJECT::dbo.usp_SendNotice TO [ShaiyaTaskAgent];
GO

/* --- Lettura minima su PS_GameDefs per gli script AUTO (task-scheduler). ---
   Gli script 3.Auto-EXP-Notice / 4.AUTO-Boss girano come ShaiyaTaskAgent e leggono
   queste tabelle prima di inviare i comandi. Solo SELECT sulle 3 tabelle usate. */
USE [PS_GameDefs];
GO
IF NOT EXISTS (SELECT 1 FROM sys.database_principals WHERE name = 'ShaiyaTaskAgent')
    CREATE USER [ShaiyaTaskAgent] FOR LOGIN [ShaiyaTaskAgent];
GO
GRANT SELECT ON OBJECT::dbo.EXPTable TO [ShaiyaTaskAgent];
GRANT SELECT ON OBJECT::dbo.MapNames TO [ShaiyaTaskAgent];
GRANT SELECT ON OBJECT::dbo.Mobs     TO [ShaiyaTaskAgent];
GO

PRINT 'PSM_Cmd: utenti + grant minimi applicati. dbo.Command NON concessa a nessuno.';
GO
