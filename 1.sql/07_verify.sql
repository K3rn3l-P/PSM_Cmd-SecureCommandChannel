/* ============================================================================
   07_verify.sql  —  Post-install checks (read-only + 1 test notice)
   Run as sysadmin.
   ============================================================================ */
SET NOCOUNT ON;

PRINT '== PS_GameDefs: Command removed? assembly removed? TRUSTWORTHY off? ==';
SELECT 'PS_GameDefs.Command exists = ' + CAST(CASE WHEN OBJECT_ID('PS_GameDefs.dbo.Command') IS NULL THEN 0 ELSE 1 END AS varchar);
SELECT 'PS_GameDefs.PSMagent asm    = ' + CAST((SELECT COUNT(*) FROM PS_GameDefs.sys.assemblies WHERE name='PSMagent') AS varchar);
SELECT 'PS_GameDefs TRUSTWORTHY     = ' + CAST(is_trustworthy_on AS varchar) FROM sys.databases WHERE name='PS_GameDefs';

PRINT '== PSM_Cmd: assembly + proc + TRUSTWORTHY off + allowlist ==';
SELECT 'PSM_Cmd.PSMagent perm       = ' + ISNULL((SELECT TOP 1 permission_set_desc FROM PSM_Cmd.sys.assemblies WHERE name='PSMagent'),'MISSING');
SELECT 'PSM_Cmd TRUSTWORTHY         = ' + CAST(is_trustworthy_on AS varchar) FROM sys.databases WHERE name='PSM_Cmd';
SELECT 'PSM_Cmd allowlist enabled   = ' + CAST((SELECT COUNT(*) FROM PSM_Cmd.dbo.GmCommandAllowlist WHERE Enabled=1) AS varchar);

PRINT '== Grants: dbo.Command must have no grantee; the wrappers should ==';
SELECT 'grantee Command = ' + ISNULL((SELECT STRING_AGG(dp.name, ',') FROM PSM_Cmd.sys.database_permissions p
        JOIN PSM_Cmd.sys.database_principals dp ON p.grantee_principal_id=dp.principal_id
        WHERE p.major_id=OBJECT_ID('PSM_Cmd.dbo.Command')),'(none - correct)');

PRINT '== FUNCTIONAL TEST: test notice (/nt) via wrapper ==';
EXEC [PSM_Cmd].[dbo].[usp_SendNotice] @text = N'PSM_Cmd install test', @service = N'ps_game';

PRINT '== NEGATIVE TEST: a SERVICE command must be REJECTED (expected return -3) ==';
DECLARE @r INT;
EXEC @r = [PSM_Cmd].[dbo].[usp_RunCommand] @service = N'ps_game', @command = N'/shutdown';
SELECT 'usp_RunCommand /shutdown return = ' + CAST(@r AS varchar) + ' (expected -3 = DENIED)';

PRINT '== Latest log entries ==';
SELECT TOP 5 Ts, CallerLogin, Wrapper, Result, Command FROM PSM_Cmd.dbo.GmCommandLog ORDER BY Id DESC;
GO
