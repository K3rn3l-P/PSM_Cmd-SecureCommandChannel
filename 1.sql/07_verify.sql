/* ============================================================================
   07_verify.sql  —  Verifiche post-installazione (read-only + 1 notice di test)
   Esegui come sysadmin.
   ============================================================================ */
SET NOCOUNT ON;

PRINT '== PS_GameDefs: Command rimossa? assembly rimossa? TRUSTWORTHY off? ==';
SELECT 'PS_GameDefs.Command exists = ' + CAST(CASE WHEN OBJECT_ID('PS_GameDefs.dbo.Command') IS NULL THEN 0 ELSE 1 END AS varchar);
SELECT 'PS_GameDefs.PSMagent asm    = ' + CAST((SELECT COUNT(*) FROM PS_GameDefs.sys.assemblies WHERE name='PSMagent') AS varchar);
SELECT 'PS_GameDefs TRUSTWORTHY     = ' + CAST(is_trustworthy_on AS varchar) FROM sys.databases WHERE name='PS_GameDefs';

PRINT '== PSM_Cmd: assembly + proc + TRUSTWORTHY off + allowlist ==';
SELECT 'PSM_Cmd.PSMagent perm       = ' + ISNULL((SELECT TOP 1 permission_set_desc FROM PSM_Cmd.sys.assemblies WHERE name='PSMagent'),'ASSENTE');
SELECT 'PSM_Cmd TRUSTWORTHY         = ' + CAST(is_trustworthy_on AS varchar) FROM sys.databases WHERE name='PSM_Cmd';
SELECT 'PSM_Cmd allowlist enabled   = ' + CAST((SELECT COUNT(*) FROM PSM_Cmd.dbo.GmCommandAllowlist WHERE Enabled=1) AS varchar);

PRINT '== Grant: dbo.Command non deve avere grantee; i wrapper si ==';
SELECT 'grantee Command = ' + ISNULL((SELECT STRING_AGG(dp.name, ',') FROM PSM_Cmd.sys.database_permissions p
        JOIN PSM_Cmd.sys.database_principals dp ON p.grantee_principal_id=dp.principal_id
        WHERE p.major_id=OBJECT_ID('PSM_Cmd.dbo.Command')),'(nessuno - corretto)');

PRINT '== TEST funzionale: notice di prova (/nt) via wrapper ==';
EXEC [PSM_Cmd].[dbo].[usp_SendNotice] @text = N'Test installazione PSM_Cmd', @service = N'ps_game';

PRINT '== TEST negativo: comando SERVICE deve essere RIFIUTATO (atteso return -3) ==';
DECLARE @r INT;
EXEC @r = [PSM_Cmd].[dbo].[usp_RunCommand] @service = N'ps_game', @command = N'/shutdown';
SELECT 'usp_RunCommand /shutdown return = ' + CAST(@r AS varchar) + ' (atteso -3 = DENIED)';

PRINT '== Ultimi log ==';
SELECT TOP 5 Ts, CallerLogin, Wrapper, Result, Command FROM PSM_Cmd.dbo.GmCommandLog ORDER BY Id DESC;
GO
