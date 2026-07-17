/* ============================================================================
   02_cert_and_assembly.sql  —  Assembly FIRMATA (no TRUSTWORTHY) + proc privata
   Esegui come sysadmin.
   PREREQUISITO: PSMagent.dll DEVE essere firmata con strong name (SNK) e copiata in
                 C:\ShaiyaServer\PSM_Client\PSMagent.signed.dll
                 (vedi ..\clr\BUILD-AND-SIGN.md). Cambia il path qui sotto se diverso.
   ============================================================================ */
SET NOCOUNT ON;
DECLARE @dll NVARCHAR(260) = N'C:\ShaiyaServer\PSM_Client\PSMagent.signed.dll';

/* --- 1) Master: asymmetric key dalla DLL firmata + login + permesso EXTERNAL ACCESS --- */
USE master;
GO
IF NOT EXISTS (SELECT 1 FROM sys.asymmetric_keys WHERE name = 'PSMagentAsymKey')
    EXEC('CREATE ASYMMETRIC KEY PSMagentAsymKey FROM EXECUTABLE FILE = ''C:\ShaiyaServer\PSM_Client\PSMagent.signed.dll''');
GO
IF NOT EXISTS (SELECT 1 FROM sys.server_principals WHERE name = 'PSMagentSigner')
    CREATE LOGIN [PSMagentSigner] FROM ASYMMETRIC KEY PSMagentAsymKey;
GO
GRANT EXTERNAL ACCESS ASSEMBLY TO [PSMagentSigner];
/* Con clr strict security = 1 l'assembly e' "trusted" solo se il login del cert/key ha UNSAFE ASSEMBLY. */
GRANT UNSAFE ASSEMBLY TO [PSMagentSigner];
GO
PRINT 'Master: asym key + login firmatario + EXTERNAL ACCESS/UNSAFE ASSEMBLY ok.';
GO

/* --- 2) PSM_Cmd: registra l'assembly EXTERNAL_ACCESS (autorizzata dalla firma, NO trustworthy) --- */
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

/* --- 3) Proc CLR PRIVATA: nessun GRANT a nessuno. Raggiungibile solo dai wrapper (EXECUTE AS OWNER). --- */
CREATE PROCEDURE dbo.Command
    @serviceName NVARCHAR(4000),
    @cmmd        NVARCHAR(4000)
AS EXTERNAL NAME [PSMagent].[StoredProcedures].[Command];
GO

PRINT 'PSM_Cmd: assembly PSMagent (EXTERNAL_ACCESS firmata) + dbo.Command privata ok.';
GO
