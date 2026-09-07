/* ============================================================================
   01_create_db_PSM_Cmd.sql  —  Dedicated, "closed" database for the command channel
   Run as sysadmin. Idempotent.
   Posture: TRUSTWORTHY OFF, db_chaining OFF, non-sysadmin owner, guest revoked.
   ============================================================================ */
SET NOCOUNT ON;

/* Dedicated non-sysadmin owner (login disabled: it only needs to own the DB, so
   EXECUTE AS OWNER in the wrappers does NOT inherit sysadmin privileges). */
IF NOT EXISTS (SELECT 1 FROM sys.server_principals WHERE name = 'PSMCmdOwner')
BEGIN
    CREATE LOGIN [PSMCmdOwner] WITH PASSWORD = N'La_tua_password',
        CHECK_POLICY = ON;
    ALTER LOGIN [PSMCmdOwner] DISABLE;   -- not needed for interactive login
    PRINT 'PSMCmdOwner login created (disabled).';
END
GO

IF DB_ID('PSM_Cmd') IS NULL
BEGIN
    CREATE DATABASE [PSM_Cmd];
    PRINT 'PSM_Cmd database created.';
END
GO

ALTER DATABASE [PSM_Cmd] SET TRUSTWORTHY OFF;
ALTER DATABASE [PSM_Cmd] SET DB_CHAINING OFF;
ALTER DATABASE [PSM_Cmd] SET RECOVERY SIMPLE;
ALTER AUTHORIZATION ON DATABASE::[PSM_Cmd] TO [PSMCmdOwner];
GO

USE [PSM_Cmd];
GO
/* Close off guest (revoke CONNECT: standard practice on user databases). */
REVOKE CONNECT FROM guest;
GO

PRINT 'PSM_Cmd: TRUSTWORTHY OFF, DB_CHAINING OFF, owner=PSMCmdOwner, guest revoked.';
GO
