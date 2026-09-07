/* ============================================================================
   02_cert_and_assembly.sql  —  SIGNED assembly (no TRUSTWORTHY) + private proc
   Run as sysadmin.
   PREREQUISITE: PSMagent.dll MUST be strong-name signed (SNK) and copied to
                 C:\ShaiyaServer\PSM_Client\PSMagent.signed.dll
                 (see ..\clr\BUILD-AND-SIGN.md). Change the path below if different.
   ============================================================================ */
SET NOCOUNT ON;
DECLARE @dll NVARCHAR(260) = N'C:\ShaiyaServer\PSM_Client\PSMagent.signed.dll';

/* --- 1) Master: asymmetric key from the signed DLL + login + EXTERNAL ACCESS permission --- */
USE master;
GO
IF NOT EXISTS (SELECT 1 FROM sys.asymmetric_keys WHERE name = 'PSMagentAsymKey')
    EXEC('CREATE ASYMMETRIC KEY PSMagentAsymKey FROM EXECUTABLE FILE = ''C:\ShaiyaServer\PSM_Client\PSMagent.signed.dll''');
GO
IF NOT EXISTS (SELECT 1 FROM sys.server_principals WHERE name = 'PSMagentSigner')
    CREATE LOGIN [PSMagentSigner] FROM ASYMMETRIC KEY PSMagentAsymKey;
GO
GRANT EXTERNAL ACCESS ASSEMBLY TO [PSMagentSigner];
/* With clr strict security = 1, the assembly is only "trusted" if the cert/key login has UNSAFE ASSEMBLY. */
GRANT UNSAFE ASSEMBLY TO [PSMagentSigner];
GO
PRINT 'Master: asym key + signer login + EXTERNAL ACCESS/UNSAFE ASSEMBLY ok.';
GO

/* --- 2) PSM_Cmd: register the EXTERNAL_ACCESS assembly (authorized by signature, NO trustworthy) --- */
USE [PSM_Cmd];
GO
IF EXISTS (SELECT 1 FROM sys.assemblies WHERE name = 'PSMagent')
BEGIN
    IF OBJECT_ID('dbo.Command') IS NOT NULL DROP PROCEDURE dbo.Command;
    DROP ASSEMBLY [PSMagent];
END
GO
CREATE ASSEMBLY [PSMagent]
    AUTHORIZATION dbo
    FROM 'C:\ShaiyaServer\PSM_Client\PSMagent.signed.dll'
    WITH PERMISSION_SET = EXTERNAL_ACCESS;
GO

/* --- 3) PRIVATE CLR proc: no GRANT to anyone. Reachable only through the wrappers (EXECUTE AS OWNER). --- */
CREATE PROCEDURE dbo.Command
    @serviceName NVARCHAR(4000),
    @cmmd        NVARCHAR(4000)
AS EXTERNAL NAME [PSMagent].[StoredProcedures].[Command];
GO

PRINT 'PSM_Cmd: PSMagent assembly (signed EXTERNAL_ACCESS) + private dbo.Command ok.';
GO
