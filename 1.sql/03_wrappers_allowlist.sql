/* ============================================================================
   03_wrappers_allowlist.sql  —  Allowlist + audit + wrapper (EXECUTE AS OWNER)
   Esegui come sysadmin nel contesto PSM_Cmd.
   - usp_SendNotice : SOLO /nt (web + notice enchant). Non puo' fare altro.
   - usp_RunCommand : comandi in allowlist+Enabled (worker/console GM), con audit.
   I wrapper usano EXECUTE AS OWNER -> i chiamanti NON hanno bisogno di EXECUTE su dbo.Command.
   ============================================================================ */
SET NOCOUNT ON;
USE [PSM_Cmd];
GO

/* --- Allowlist comandi (set noto ps_game/ps_login). Enabled=0 = bloccato di default. --- */
IF OBJECT_ID('dbo.GmCommandAllowlist') IS NULL
CREATE TABLE dbo.GmCommandAllowlist (
    Command     NVARCHAR(64)  NOT NULL,
    Service     NVARCHAR(20)  NOT NULL,        -- ps_game | ps_login
    Tier        VARCHAR(10)   NOT NULL,        -- SAFE | PLAYER | ECONOMY | SERVICE
    Enabled     BIT           NOT NULL DEFAULT 0,
    Description NVARCHAR(200)  NULL,           -- a cosa serve il comando
    CONSTRAINT PK_GmCommandAllowlist PRIMARY KEY (Command, Service)
);
GO
-- ALTER per deploy gia' esistenti (aggiunge la colonna Description se manca).
IF COL_LENGTH('dbo.GmCommandAllowlist','Description') IS NULL
    ALTER TABLE dbo.GmCommandAllowlist ADD Description NVARCHAR(200) NULL;
GO

/* --- Audit di ogni comando passato dai wrapper --- */
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

/* --- Profilo chiamante: tier massimo consentito per login (usp_RunCommand). --- */
/*     SAFE=1, PLAYER=2, ECONOMY=3, SERVICE=4 (SERVICE mai via questo path). --- */
IF OBJECT_ID('dbo.GmCallerProfile') IS NULL
CREATE TABLE dbo.GmCallerProfile (
    CallerLogin SYSNAME      NOT NULL PRIMARY KEY,
    MaxTierRank TINYINT      NOT NULL    -- 1=SAFE 2=PLAYER 3=ECONOMY
);
GO
MERGE dbo.GmCallerProfile AS t
USING (VALUES
  (N'Ernoweb@', 2),          -- web: notice + kick (SAFE+PLAYER), NO economia/service
  (N'ShaiyaTaskAgent', 3)    -- worker: anche economia (SAFE+PLAYER+ECONOMY)
) AS s(CallerLogin, MaxTierRank)
ON t.CallerLogin = s.CallerLogin
WHEN NOT MATCHED THEN INSERT (CallerLogin, MaxTierRank) VALUES (s.CallerLogin, s.MaxTierRank);
GO

/* --- Seed allowlist (idempotente). SAFE/ECONOMY usati = Enabled 1; SERVICE/distruttivi = 0. --- */
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
  -- ps_game CUSTOM (comandi aggiunti in sdev.dll: command_manager). /mmake usato dall'auto-boss.
  ('/mmake','ps_game','ECONOMY',1),('/giveitem','ps_game','ECONOMY',0),('/mera','ps_game','ECONOMY',0),
  -- ps_game SERVICE (distruttivi: Enabled 0)
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

/* --- Descrizioni (a cosa serve ogni comando). (inferito)=non documentato ufficialmente. --- */
;WITH d(Command,Service,Descr) AS (
  SELECT * FROM (VALUES
    ('/nt','ps_game','Broadcast: messaggio a tutti i giocatori online'),
    ('/servertime','ps_game','Mostra/imposta ora del server (inferito)'),
    ('/viewmap','ps_game','Info su una mappa, arg=mapId (inferito)'),
    ('/si','ps_game','Server info / stato istanza'),
    ('/mem','ps_game','Stato memoria processo (diagnostico)'),
    ('/uc','ps_game','User count: giocatori online'),
    ('/chktimeout','ps_game','Forza pulizia connessioni scadute (inferito)'),
    ('/ticktime','ps_game','Info tick time server (diagnostico) (inferito)'),
    ('/inszonecnt','ps_game','Numero zone istanza attive (inferito)'),
    ('/kickun','ps_game','Espelle giocatore per Username'),
    ('/kickuid','ps_game','Espelle giocatore per UserUID'),
    ('/kickcn','ps_game','Espelle per nome Personaggio'),
    ('/kickcid','ps_game','Espelle per CharID'),
    ('/setmaxuser','ps_game','Imposta numero massimo utenti concorrenti'),
    ('/nprotecton','ps_game','Attiva protezione anti-cheat nProtect/GameGuard (inferito)'),
    ('/nprotectoff','ps_game','Disattiva protezione anti-cheat (RISCHIOSO)'),
    ('/initpl','ps_game','Reinizializza dati/lista player (inferito, rischioso)'),
    ('/aiset','ps_game','Imposta parametri AI dei mob (inferito)'),
    ('/exp2xenable','ps_game','Attiva moltiplicatore EXP, arg=rate (100=x100) [CONFERMATO] [ECONOMIA]'),
    ('/exp2xdisable','ps_game','Disattiva moltiplicatore EXP [ECONOMIA]'),
    ('/enchant','ps_game','Imposta rate di successo enchant (inferito) [ECONOMIA]'),
    ('/enchantreset','ps_game','Ripristina rate enchant default'),
    ('/gemmix','ps_game','Imposta rate gem/lapis mix (inferito) [ECONOMIA]'),
    ('/gemext','ps_game','Imposta rate gem/lapis extend (inferito) [ECONOMIA]'),
    ('/gemreset','ps_game','Ripristina rate gem'),
    ('/killcnt','ps_game','Imposta evento/valori kill count (inferito) [PvP]'),
    ('/killcntreset','ps_game','Reset kill count'),
    ('/expupcamp','ps_game','Campagna exp-up per fazione (inferito) [ECONOMIA]'),
    ('/expupcampreset','ps_game','Reset campagna exp-up'),
    ('/expupmap','ps_game','Exp-up per mappa (inferito) [ECONOMIA]'),
    ('/expupmapreset','ps_game','Reset exp-up mappa'),
    ('/killupmap','ps_game','Kill-up per mappa (inferito) [PvP]'),
    ('/killupmapreset','ps_game','Reset kill-up mappa'),
    ('/resetstatcnt','ps_game','Reset conteggio reroll statistiche (inferito)'),
    ('/resetskillcnt','ps_game','Reset conteggio reroll skill (inferito)'),
    ('/addsr','ps_game','Aggiunge SR (significato da confermare)'),
    ('/enableshop','ps_game','Abilita lo shop'),
    ('/disableshop','ps_game','Disabilita lo shop'),
    ('/disablenshop','ps_game','Disabilita n-shop / item mall (inferito)'),
    ('/disablegift','ps_game','Disabilita i gift'),
    ('/enablekill','ps_game','Abilita sistema kill (inferito)'),
    ('/disablekill','ps_game','Disabilita sistema kill (inferito)'),
    ('/mmake','ps_game','CUSTOM (sdev.dll): spawn mob/boss - /mmake mapId mobId count x y z [EVENTO]'),
    ('/giveitem','ps_game','CUSTOM (sdev.dll): assegna item a personaggio [ECONOMIA]'),
    ('/mera','ps_game','CUSTOM (sdev.dll): assegna denaro/gold [ECONOMIA]'),
    ('/quit','ps_game','Spegne il processo ps_game (CRITICO)'),
    ('/exit','ps_game','Esce/spegne il processo (CRITICO)'),
    ('/shutdown','ps_game','Shutdown server di gioco (CRITICO)'),
    ('/crashdump','ps_game','Genera crash dump del processo (CRITICO)'),
    ('/allout','ps_game','Disconnette TUTTI i giocatori (CRITICO)'),
    ('/cstop','ps_game','Ferma accettazione connessioni (CRITICO) (inferito)'),
    ('/cstart','ps_game','Riavvia accettazione connessioni (inferito)'),
    ('/nt','ps_login','Notice a tutti (login)'),
    ('/sl','ps_login','Lista sessioni (inferito)'),
    ('/si','ps_login','Server info'),
    ('/mem','ps_login','Stato memoria'),
    ('/uc','ps_login','User count'),
    ('/vchg','ps_login','Cambia versione client richiesta (inferito)'),
    ('/setmaxuser','ps_login','Max utenti login'),
    ('/adminopen','ps_login','Apre login SOLO agli admin (manutenzione) (CRITICO)'),
    ('/adminclose','ps_login','Ripristina login normale (CRITICO)'),
    ('/vchkon','ps_login','Attiva controllo versione client'),
    ('/vchkoff','ps_login','Disattiva controllo versione client (RISCHIOSO)'),
    ('/hide1svr','ps_login','Nasconde un server dalla lista'),
    ('/show1svr','ps_login','Mostra un server nella lista'),
    ('/showallsvr','ps_login','Mostra tutti i server'),
    ('/cstop','ps_login','Ferma connessioni login (CRITICO)'),
    ('/cstart','ps_login','Riavvia connessioni login'),
    ('/shutdown','ps_login','Shutdown login server (CRITICO)')
  ) x(Command,Service,Descr)
)
UPDATE a SET a.Description = d.Descr
FROM dbo.GmCommandAllowlist a JOIN d ON a.Command = d.Command AND a.Service = d.Service;
GO

/* --- Wrapper STRETTO: solo /nt. Sanifica il testo. --- */
CREATE OR ALTER PROCEDURE dbo.usp_SendNotice
    @text    NVARCHAR(200),
    @service NVARCHAR(20) = N'ps_game'
WITH EXECUTE AS OWNER
AS
BEGIN
    SET NOCOUNT ON;
    IF @service NOT IN (N'ps_game', N'ps_login') SET @service = N'ps_game';
    -- sanifica: niente CR/LF, niente '/' iniziale (eviterebbe l'iniezione di un altro comando), cap 150
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

/* --- Wrapper TIER: comando in allowlist + Enabled. Audit. --- */
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

    -- comando deve essere in allowlist + Enabled
    DECLARE @tier VARCHAR(10) = (SELECT Tier FROM dbo.GmCommandAllowlist
                                 WHERE Command = @token AND Service = @service AND Enabled = 1);
    -- tier massimo consentito al chiamante reale
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
