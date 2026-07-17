/* ============================================================================
   00_prereqs.sql  —  Prerequisiti istanza (SQL Server Express 2022 OK)
   Esegui come sysadmin (Windows auth). Idempotente.
   ============================================================================ */
SET NOCOUNT ON;

PRINT 'Edition: ' + CAST(SERVERPROPERTY('Edition') AS varchar(128))
    + ' | Version: ' + CAST(SERVERPROPERTY('ProductVersion') AS varchar(64));

/* CLR deve essere abilitato (richiesto dall'assembly PSMagent). */
IF (SELECT CAST(value_in_use AS int) FROM sys.configurations WHERE name = 'clr enabled') <> 1
BEGIN
    EXEC sp_configure 'show advanced options', 1; RECONFIGURE;
    EXEC sp_configure 'clr enabled', 1; RECONFIGURE;
    EXEC sp_configure 'show advanced options', 0; RECONFIGURE;
    PRINT 'clr enabled -> 1';
END
ELSE PRINT 'clr enabled gia attivo';

/* clr strict security DEVE restare attivo (default 2017+): l'assembly EXTERNAL_ACCESS
   funzionera' grazie alla FIRMA (asymmetric key + UNSAFE ASSEMBLY al login del cert), NON via TRUSTWORTHY. */
DECLARE @clrstrict int = (SELECT CAST(value_in_use AS int) FROM sys.configurations WHERE name = 'clr strict security');
PRINT 'clr strict security = ' + CAST(@clrstrict AS varchar(4)) + ' (atteso 1)';

/* cross db ownership chaining DEVE restare 0 (i wrapper usano EXECUTE AS OWNER + grant espliciti). */
DECLARE @crossdb int = (SELECT CAST(value_in_use AS int) FROM sys.configurations WHERE name = 'cross db ownership chaining');
PRINT 'cross db ownership chaining = ' + CAST(@crossdb AS varchar(4)) + ' (atteso 0)';
GO
