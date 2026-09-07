/* ============================================================================
   00_prereqs.sql  —  Instance prerequisites (SQL Server Express 2022 OK)
   Run as sysadmin (Windows auth). Idempotent.
   ============================================================================ */
SET NOCOUNT ON;

PRINT 'Edition: ' + CAST(SERVERPROPERTY('Edition') AS varchar(128))
    + ' | Version: ' + CAST(SERVERPROPERTY('ProductVersion') AS varchar(64));

/* CLR must be enabled (required by the PSMagent assembly). */
IF (SELECT CAST(value_in_use AS int) FROM sys.configurations WHERE name = 'clr enabled') <> 1
BEGIN
    EXEC sp_configure 'show advanced options', 1; RECONFIGURE;
    EXEC sp_configure 'clr enabled', 1; RECONFIGURE;
    EXEC sp_configure 'show advanced options', 0; RECONFIGURE;
    PRINT 'clr enabled -> 1';
END
ELSE PRINT 'clr enabled already on';

/* clr strict security MUST stay on (default since 2017+): the EXTERNAL_ACCESS assembly will
   work because of its SIGNATURE (asymmetric key + UNSAFE ASSEMBLY on the cert login), NOT via TRUSTWORTHY. */
DECLARE @clrstrict int = (SELECT CAST(value_in_use AS int) FROM sys.configurations WHERE name = 'clr strict security');
PRINT 'clr strict security = ' + CAST(@clrstrict AS varchar(4)) + ' (expected 1)';

/* cross db ownership chaining MUST stay 0 (the wrappers use EXECUTE AS OWNER + explicit grants). */
DECLARE @crossdb int = (SELECT CAST(value_in_use AS int) FROM sys.configurations WHERE name = 'cross db ownership chaining');
PRINT 'cross db ownership chaining = ' + CAST(@crossdb AS varchar(4)) + ' (expected 0)';
GO
