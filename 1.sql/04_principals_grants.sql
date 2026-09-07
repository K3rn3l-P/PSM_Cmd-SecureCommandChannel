/* ============================================================================
   04_principals_grants.sql  —  Least-privilege accounts + grants
   Run as sysadmin.
   Access map:
     - Ernoweb@        (web)      -> usp_SendNotice ONLY (/nt). A web SQLi can only broadcast.
     - S@o0#$h1908     (gameplay) -> usp_SendNotice ONLY (enchant notice).
     - ShaiyaTaskAgent (worker)   -> usp_RunCommand (allowlisted economy commands) + usp_SendNotice.
   Nobody has direct EXECUTE on dbo.Command (the wrappers run EXECUTE AS OWNER).
   ============================================================================ */
SET NOCOUNT ON;

/* Dedicated account for the task-scheduler worker (separates "command" power from the web Ernoweb@). */
IF NOT EXISTS (SELECT 1 FROM sys.server_principals WHERE name = 'ShaiyaTaskAgent')
    CREATE LOGIN [ShaiyaTaskAgent] WITH PASSWORD = N'YourStrongPassword', CHECK_POLICY = ON;
GO

USE [PSM_Cmd];
GO
/* Users in the closed DB (mapped to existing logins). */
IF NOT EXISTS (SELECT 1 FROM sys.database_principals WHERE name = 'Ernoweb@')
    CREATE USER [Ernoweb@] FOR LOGIN [Ernoweb@];
IF NOT EXISTS (SELECT 1 FROM sys.database_principals WHERE name = 'S@o0#$h1908')
    CREATE USER [S@o0#$h1908] FOR LOGIN [S@o0#$h1908];
IF NOT EXISTS (SELECT 1 FROM sys.database_principals WHERE name = 'ShaiyaTaskAgent')
    CREATE USER [ShaiyaTaskAgent] FOR LOGIN [ShaiyaTaskAgent];
GO

/* Least-privilege grants on the wrappers ONLY (never on dbo.Command). */
-- Web: usp_RunCommand (tier PLAYER -> /nt + kick) and usp_SendNotice (sanitized notice).
GRANT EXECUTE ON OBJECT::dbo.usp_RunCommand TO [Ernoweb@];
GRANT EXECUTE ON OBJECT::dbo.usp_SendNotice TO [Ernoweb@];
-- Gameplay (enchant notice): usp_SendNotice only (sanitized /nt).
GRANT EXECUTE ON OBJECT::dbo.usp_SendNotice TO [S@o0#$h1908];
-- Worker: usp_RunCommand (tier ECONOMY) + usp_SendNotice.
GRANT EXECUTE ON OBJECT::dbo.usp_RunCommand TO [ShaiyaTaskAgent];
GRANT EXECUTE ON OBJECT::dbo.usp_SendNotice TO [ShaiyaTaskAgent];
GO

/* --- Minimal read access on PS_GameDefs for the AUTO scripts (task scheduler). ---
   The 3.Auto-EXP-Notice / 4.AUTO-Boss scripts run as ShaiyaTaskAgent and read
   these tables before sending commands. SELECT only on the 3 tables used. */
USE [PS_GameDefs];
GO
IF NOT EXISTS (SELECT 1 FROM sys.database_principals WHERE name = 'ShaiyaTaskAgent')
    CREATE USER [ShaiyaTaskAgent] FOR LOGIN [ShaiyaTaskAgent];
GO
GRANT SELECT ON OBJECT::dbo.EXPTable TO [ShaiyaTaskAgent];
GRANT SELECT ON OBJECT::dbo.MapNames TO [ShaiyaTaskAgent];
GRANT SELECT ON OBJECT::dbo.Mobs     TO [ShaiyaTaskAgent];
GO

PRINT 'PSM_Cmd: least-privilege users + grants applied. dbo.Command granted to nobody.';
GO
