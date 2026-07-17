/* ============================================================================
   01_create_db_PSM_Cmd.sql  —  DB dedicato e "chiuso" per il canale comandi
   Esegui come sysadmin. Idempotente.
   Posture: TRUSTWORTHY OFF, db_chaining OFF, owner NON-sysadmin, guest revocato.
   ============================================================================ */
SET NOCOUNT ON;

/* Owner dedicato non-sysadmin (login disabilitato: serve solo a possedere il DB,
   cosi' EXECUTE AS OWNER nei wrapper NON eredita privilegi sysadmin). */
IF NOT EXISTS (SELECT 1 FROM sys.server_principals WHERE name = 'PSMCmdOwner')
BEGIN
    CREATE LOGIN [PSMCmdOwner] WITH PASSWORD = N'La_tua_password',
        CHECK_POLICY = ON;
    ALTER LOGIN [PSMCmdOwner] DISABLE;   -- non serve per login interattivo
    PRINT 'Login PSMCmdOwner creato (disabilitato).';
END
GO

IF DB_ID('PSM_Cmd') IS NULL
BEGIN
    CREATE DATABASE [PSM_Cmd];
    PRINT 'Database PSM_Cmd creato.';
END
GO

ALTER DATABASE [PSM_Cmd] SET TRUSTWORTHY OFF;
ALTER DATABASE [PSM_Cmd] SET DB_CHAINING OFF;
ALTER DATABASE [PSM_Cmd] SET RECOVERY SIMPLE;
ALTER AUTHORIZATION ON DATABASE::[PSM_Cmd] TO [PSMCmdOwner];
GO

USE [PSM_Cmd];
GO
/* Chiudi guest (revoca CONNECT: standard nei DB utente). */
REVOKE CONNECT FROM guest;
GO

PRINT 'PSM_Cmd: TRUSTWORTHY OFF, DB_CHAINING OFF, owner=PSMCmdOwner, guest revocato.';
GO
