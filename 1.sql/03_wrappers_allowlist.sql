/* ============================================================================
   03_wrappers_allowlist.sql  —  Allowlist + audit + wrappers (EXECUTE AS OWNER)
   Run as sysadmin in the PSM_Cmd context.
   - usp_SendNotice : /nt ONLY (web + enchant notice). Can't do anything else.
   - usp_RunCommand : allowlisted+Enabled commands (worker/GM console), with audit.
   The wrappers use EXECUTE AS OWNER -> callers do NOT need EXECUTE on dbo.Command.
   ============================================================================ */
SET NOCOUNT ON;
USE [PSM_Cmd];
GO

/* --- Command allowlist (known ps_game/ps_login set). Enabled=0 = blocked by default. --- */
IF OBJECT_ID('dbo.GmCommandAllowlist') IS NULL
CREATE TABLE dbo.GmCommandAllowlist (
    Command     NVARCHAR(64)  NOT NULL,
    Service     NVARCHAR(20)  NOT NULL,        -- ps_game | ps_login
    Tier        VARCHAR(10)   NOT NULL,        -- SAFE | PLAYER | ECONOMY | SERVICE
    Enabled     BIT           NOT NULL DEFAULT 0,
    Description NVARCHAR(200)  NULL,           -- what the command does
    CONSTRAINT PK_GmCommandAllowlist PRIMARY KEY (Command, Service)
);
GO
-- ALTER for existing deployments (adds the Description column if missing).
IF COL_LENGTH('dbo.GmCommandAllowlist','Description') IS NULL
    ALTER TABLE dbo.GmCommandAllowlist ADD Description NVARCHAR(200) NULL;
GO

/* --- Audit of every command passed through the wrappers --- */
IF OBJECT_ID('dbo.GmCommandLog') IS NULL
CREATE TABLE dbo.GmCommandLog (
    Id        BIGINT IDENTITY(1,1) PRIMARY KEY,
    Ts        DATETIME2     NOT NULL DEFAULT SYSUTCDATETIME(),
    CallerLogin SYSNAME     NULL,              -- ORIGINAL_LOGIN()
    Wrapper   VARCHAR(20)   NOT NULL,          -- SendNotice | RunCommand
    Service   NVARCHAR(20)  NULL,
    Command   NVARCHAR(4000) NULL,
    Result    VARCHAR(20)   NOT NULL           -- OK | DENIED | ERROR
);
GO

/* --- Caller profile: max tier allowed per login (usp_RunCommand). --- */
/*     SAFE=1, PLAYER=2, ECONOMY=3, SERVICE=4 (SERVICE never through this path). --- */
IF OBJECT_ID('dbo.GmCallerProfile') IS NULL
CREATE TABLE dbo.GmCallerProfile (
    CallerLogin SYSNAME      NOT NULL PRIMARY KEY,
    MaxTierRank TINYINT      NOT NULL    -- 1=SAFE 2=PLAYER 3=ECONOMY
);
GO
MERGE dbo.GmCallerProfile AS t
USING (VALUES
  (N'Ernoweb@', 2),          -- web: notice + kick (SAFE+PLAYER), NO economy/service
  (N'ShaiyaTaskAgent', 3)    -- worker: economy too (SAFE+PLAYER+ECONOMY)
) AS s(CallerLogin, MaxTierRank)
ON t.CallerLogin = s.CallerLogin
WHEN NOT MATCHED THEN INSERT (CallerLogin, MaxTierRank) VALUES (s.CallerLogin, s.MaxTierRank);
GO

/* --- Seed allowlist (idempotent). Used SAFE/ECONOMY = Enabled 1; SERVICE/destructive = 0. --- */
MERGE dbo.GmCommandAllowlist AS t
USING (VALUES
  -- ps_game SAFE
  ('/nt','ps_game','SAFE',1),('/servertime','ps_game','SAFE',1),('/viewmap','ps_game','SAFE',1),
  ('/si','ps_game','SAFE',1),('/mem','ps_game','SAFE',1),('/uc','ps_game','SAFE',1),
  ('/chktimeout','ps_game','SAFE',1),('/ticktime','ps_game','SAFE',1),('/inszonecnt','ps_game','SAFE',1),
  -- ps_game PLAYER
  ('/kickun','ps_game','PLAYER',1),('/kickuid','ps_game','PLAYER',1),('/kickcn','ps_game','PLAYER',1),
  ('/kickcid','ps_game','PLAYER',1),('/setmaxuser','ps_game','PLAYER',0),('/nprotecton','ps_game','PLAYER',1),
  ('/nprotectoff','ps_game','PLAYER',1),('/initpl','ps_game','PLAYER',0),('/aiset','ps_game','PLAYER',0),
  -- ps_game ECONOMY
  ('/exp2xenable','ps_game','ECONOMY',1),('/exp2xdisable','ps_game','ECONOMY',1),
  ('/enchant','ps_game','ECONOMY',0),('/enchantreset','ps_game','ECONOMY',0),
  ('/gemmix','ps_game','ECONOMY',0),('/gemext','ps_game','ECONOMY',0),('/gemreset','ps_game','ECONOMY',0),
  ('/killcnt','ps_game','ECONOMY',0),('/killcntreset','ps_game','ECONOMY',0),
  ('/expupcamp','ps_game','ECONOMY',0),('/expupcampreset','ps_game','ECONOMY',0),
  ('/expupmap','ps_game','ECONOMY',0),('/expupmapreset','ps_game','ECONOMY',0),
  ('/killupmap','ps_game','ECONOMY',0),('/killupmapreset','ps_game','ECONOMY',0),
  ('/resetstatcnt','ps_game','ECONOMY',0),('/resetskillcnt','ps_game','ECONOMY',0),('/addsr','ps_game','ECONOMY',0),
  ('/enableshop','ps_game','ECONOMY',0),('/disableshop','ps_game','ECONOMY',0),('/disablenshop','ps_game','ECONOMY',0),
  ('/disablegift','ps_game','ECONOMY',0),('/enablekill','ps_game','ECONOMY',0),('/disablekill','ps_game','ECONOMY',0),
  -- ps_game CUSTOM (commands added in sdev.dll: command_manager). /mmake used by the auto-boss job.
  ('/mmake','ps_game','ECONOMY',1),('/giveitem','ps_game','ECONOMY',0),('/mera','ps_game','ECONOMY',0),
  -- ps_game SERVICE (destructive: Enabled 0)
  ('/quit','ps_game','SERVICE',0),('/exit','ps_game','SERVICE',0),('/shutdown','ps_game','SERVICE',0),
  ('/crashdump','ps_game','SERVICE',0),('/allout','ps_game','SERVICE',0),('/cstop','ps_game','SERVICE',0),
  ('/cstart','ps_game','SERVICE',0),
  -- ps_login
  ('/nt','ps_login','SAFE',1),('/sl','ps_login','SAFE',1),('/si','ps_login','SAFE',1),('/mem','ps_login','SAFE',1),
  ('/uc','ps_login','SAFE',1),('/vchg','ps_login','PLAYER',0),('/setmaxuser','ps_login','PLAYER',0),
  ('/adminopen','ps_login','SERVICE',0),('/adminclose','ps_login','SERVICE',0),
  ('/vchkon','ps_login','SERVICE',0),('/vchkoff','ps_login','SERVICE',0),
  ('/hide1svr','ps_login','SERVICE',0),('/show1svr','ps_login','SERVICE',0),('/showallsvr','ps_login','SERVICE',0),
  ('/cstop','ps_login','SERVICE',0),('/cstart','ps_login','SERVICE',0),
  ('/shutdown','ps_login','SERVICE',0)
) AS s(Command,Service,Tier,Enabled)
ON t.Command = s.Command AND t.Service = s.Service
WHEN NOT MATCHED THEN INSERT (Command,Service,Tier,Enabled) VALUES (s.Command,s.Service,s.Tier,s.Enabled);
GO

/* --- Descriptions (what each command does). (inferred)=not officially documented. --- */
;WITH d(Command,Service,Descr) AS (
  SELECT * FROM (VALUES
    ('/nt','ps_game','Broadcast: message to all online players'),
    ('/servertime','ps_game','Shows/sets server time (inferred)'),
    ('/viewmap','ps_game','Map info, arg=mapId (inferred)'),
    ('/si','ps_game','Server info / instance status'),
    ('/mem','ps_game','Process memory status (diagnostic)'),
    ('/uc','ps_game','User count: online players'),
    ('/chktimeout','ps_game','Forces cleanup of expired connections (inferred)'),
    ('/ticktime','ps_game','Server tick time info (diagnostic) (inferred)'),
    ('/inszonecnt','ps_game','Number of active instance zones (inferred)'),
    ('/kickun','ps_game','Kicks player by Username'),
    ('/kickuid','ps_game','Kicks player by UserUID'),
    ('/kickcn','ps_game','Kicks by character Name'),
    ('/kickcid','ps_game','Kicks by CharID'),
    ('/setmaxuser','ps_game','Sets max concurrent users'),
    ('/nprotecton','ps_game','Enables nProtect/GameGuard anti-cheat (inferred)'),
    ('/nprotectoff','ps_game','Disables anti-cheat protection (RISKY)'),
    ('/initpl','ps_game','Reinitializes player data/list (inferred, risky)'),
    ('/aiset','ps_game','Sets mob AI parameters (inferred)'),
    ('/exp2xenable','ps_game','Enables EXP multiplier, arg=rate (100=x100) [CONFIRMED] [ECONOMY]'),
    ('/exp2xdisable','ps_game','Disables EXP multiplier [ECONOMY]'),
    ('/enchant','ps_game','Sets enchant success rate (inferred) [ECONOMY]'),
    ('/enchantreset','ps_game','Restores default enchant rate'),
    ('/gemmix','ps_game','Sets gem/lapis mix rate (inferred) [ECONOMY]'),
    ('/gemext','ps_game','Sets gem/lapis extend rate (inferred) [ECONOMY]'),
    ('/gemreset','ps_game','Restores gem rate'),
    ('/killcnt','ps_game','Sets kill-count event/values (inferred) [PvP]'),
    ('/killcntreset','ps_game','Resets kill count'),
    ('/expupcamp','ps_game','Faction exp-up campaign (inferred) [ECONOMY]'),
    ('/expupcampreset','ps_game','Resets exp-up campaign'),
    ('/expupmap','ps_game','Per-map exp-up (inferred) [ECONOMY]'),
    ('/expupmapreset','ps_game','Resets per-map exp-up'),
    ('/killupmap','ps_game','Per-map kill-up (inferred) [PvP]'),
    ('/killupmapreset','ps_game','Resets per-map kill-up'),
    ('/resetstatcnt','ps_game','Resets stat reroll count (inferred)'),
    ('/resetskillcnt','ps_game','Resets skill reroll count (inferred)'),
    ('/addsr','ps_game','Adds SR (meaning to confirm)'),
    ('/enableshop','ps_game','Enables the shop'),
    ('/disableshop','ps_game','Disables the shop'),
    ('/disablenshop','ps_game','Disables n-shop / item mall (inferred)'),
    ('/disablegift','ps_game','Disables gifts'),
    ('/enablekill','ps_game','Enables the kill system (inferred)'),
    ('/disablekill','ps_game','Disables the kill system (inferred)'),
    ('/mmake','ps_game','CUSTOM (sdev.dll): spawns a mob/boss - /mmake mapId mobId count x y z [EVENT]'),
    ('/giveitem','ps_game','CUSTOM (sdev.dll): grants an item to a character [ECONOMY]'),
    ('/mera','ps_game','CUSTOM (sdev.dll): grants money/gold [ECONOMY]'),
    ('/quit','ps_game','Shuts down the ps_game process (CRITICAL)'),
    ('/exit','ps_game','Exits/shuts down the process (CRITICAL)'),
    ('/shutdown','ps_game','Shuts down the game server (CRITICAL)'),
    ('/crashdump','ps_game','Generates a process crash dump (CRITICAL)'),
    ('/allout','ps_game','Disconnects ALL players (CRITICAL)'),
    ('/cstop','ps_game','Stops accepting connections (CRITICAL) (inferred)'),
    ('/cstart','ps_game','Restarts accepting connections (inferred)'),
    ('/nt','ps_login','Notice to all (login)'),
    ('/sl','ps_login','Session list (inferred)'),
    ('/si','ps_login','Server info'),
    ('/mem','ps_login','Memory status'),
    ('/uc','ps_login','User count'),
    ('/vchg','ps_login','Changes the required client version (inferred)'),
    ('/setmaxuser','ps_login','Max login users'),
    ('/adminopen','ps_login','Opens login to admins ONLY (maintenance) (CRITICAL)'),
    ('/adminclose','ps_login','Restores normal login (CRITICAL)'),
    ('/vchkon','ps_login','Enables client version check'),
    ('/vchkoff','ps_login','Disables client version check (RISKY)'),
    ('/hide1svr','ps_login','Hides a server from the list'),
    ('/show1svr','ps_login','Shows a server in the list'),
    ('/showallsvr','ps_login','Shows all servers'),
    ('/cstop','ps_login','Stops login connections (CRITICAL)'),
    ('/cstart','ps_login','Restarts login connections'),
    ('/shutdown','ps_login','Shuts down the login server (CRITICAL)')
  ) x(Command,Service,Descr)
)
UPDATE a SET a.Description = d.Descr
FROM dbo.GmCommandAllowlist a JOIN d ON a.Command = d.Command AND a.Service = d.Service;
GO

/* --- STRICT wrapper: /nt only. Sanitizes the text. --- */
CREATE OR ALTER PROCEDURE dbo.usp_SendNotice
    @text    NVARCHAR(200),
    @service NVARCHAR(20) = N'ps_game'
WITH EXECUTE AS OWNER
AS
BEGIN
    SET NOCOUNT ON;
    IF @service NOT IN (N'ps_game', N'ps_login') SET @service = N'ps_game';
    -- sanitize: no CR/LF, no leading '/' (would allow injecting another command), cap at 150
    SET @text = REPLACE(REPLACE(ISNULL(@text, N''), CHAR(13), N' '), CHAR(10), N' ');
    SET @text = LTRIM(RTRIM(@text));
    WHILE LEFT(@text, 1) = N'/' SET @text = LTRIM(SUBSTRING(@text, 2, LEN(@text)));
    IF LEN(@text) = 0 RETURN;
    IF LEN(@text) > 150 SET @text = LEFT(@text, 150);

    DECLARE @cmd NVARCHAR(4000) = N'/nt ' + @text;
    DECLARE @rc INT;
    BEGIN TRY
        EXEC @rc = dbo.Command @serviceName = @service, @cmmd = @cmd;
        INSERT dbo.GmCommandLog(CallerLogin,Wrapper,Service,Command,Result)
            VALUES (ORIGINAL_LOGIN(),'SendNotice',@service,@cmd,'OK');
        RETURN @rc;
    END TRY
    BEGIN CATCH
        INSERT dbo.GmCommandLog(CallerLogin,Wrapper,Service,Command,Result)
            VALUES (ORIGINAL_LOGIN(),'SendNotice',@service,@cmd,'ERROR');
        RETURN -1;
    END CATCH
END
GO

/* --- TIERED wrapper: allowlisted + Enabled commands. Audited. --- */
CREATE OR ALTER PROCEDURE dbo.usp_RunCommand
    @service NVARCHAR(20),
    @command NVARCHAR(4000)
WITH EXECUTE AS OWNER
AS
BEGIN
    SET NOCOUNT ON;
    IF @service NOT IN (N'ps_game', N'ps_login')
    BEGIN
        INSERT dbo.GmCommandLog(CallerLogin,Wrapper,Service,Command,Result)
            VALUES (ORIGINAL_LOGIN(),'RunCommand',@service,@command,'DENIED');
        RETURN -2;
    END

    DECLARE @token NVARCHAR(64) = LOWER(LTRIM(ISNULL(@command, N'')));
    SET @token = CASE WHEN CHARINDEX(N' ', @token) > 0
                      THEN LEFT(@token, CHARINDEX(N' ', @token) - 1) ELSE @token END;

    -- command must be allowlisted + Enabled
    DECLARE @tier VARCHAR(10) = (SELECT Tier FROM dbo.GmCommandAllowlist
                                 WHERE Command = @token AND Service = @service AND Enabled = 1);
    -- max tier allowed for the actual caller
    DECLARE @maxRank TINYINT = ISNULL((SELECT MaxTierRank FROM dbo.GmCallerProfile
                                       WHERE CallerLogin = ORIGINAL_LOGIN()), 0);
    DECLARE @rank TINYINT = CASE @tier WHEN 'SAFE' THEN 1 WHEN 'PLAYER' THEN 2
                                       WHEN 'ECONOMY' THEN 3 ELSE 4 END;

    IF @tier IS NULL OR @rank > @maxRank
    BEGIN
        INSERT dbo.GmCommandLog(CallerLogin,Wrapper,Service,Command,Result)
            VALUES (ORIGINAL_LOGIN(),'RunCommand',@service,@command,'DENIED');
        RETURN -3;
    END

    DECLARE @rc INT;
    BEGIN TRY
        EXEC @rc = dbo.Command @serviceName = @service, @cmmd = @command;
        INSERT dbo.GmCommandLog(CallerLogin,Wrapper,Service,Command,Result)
            VALUES (ORIGINAL_LOGIN(),'RunCommand',@service,@command,'OK');
        RETURN @rc;
    END TRY
    BEGIN CATCH
        INSERT dbo.GmCommandLog(CallerLogin,Wrapper,Service,Command,Result)
            VALUES (ORIGINAL_LOGIN(),'RunCommand',@service,@command,'ERROR');
        RETURN -1;
    END CATCH
END
GO

PRINT 'PSM_Cmd: allowlist + log + usp_SendNotice + usp_RunCommand ok.';
GO
