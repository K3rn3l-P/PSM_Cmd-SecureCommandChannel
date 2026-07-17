//------------------------------------------------------------------------------
// PSMagent - CLR bridge SQL -> socket PSM (ps_game/ps_login) su 127.0.0.1:40900
// Versione HARDENED (progetto B): allowlist serviceName + socket con using/dispose.
// La validazione del COMANDO e l'autorizzazione stanno nei wrapper T-SQL (usp_SendNotice /
// usp_RunCommand) e nei grant: questa CLR resta minima e fidata.
// Firmare con strong name (SNK) e registrare via 02_cert_and_assembly.sql (NO TRUSTWORTHY).
//------------------------------------------------------------------------------
using System;
using System.Data.SqlTypes;
using Microsoft.SqlServer.Server;
using System.Text;
using System.IO;
using System.Net.Sockets;

public partial class StoredProcedures
{
    private const string PsmHost = "127.0.0.1";
    private const int    PsmPort = 40900;
    private const int    HeaderSize = 258;     // 2 (command position) + 256 (service name)
    private const short  HeaderMarker = 1281;  // command position fissa

    [Microsoft.SqlServer.Server.SqlProcedure]
    public static void Command(SqlString serviceName, SqlString cmmd)
    {
        SqlPipe sp = SqlContext.Pipe;
        string retMessage = "0";

        // --- Allowlist servizio (difesa in profondita': i wrapper gia' la impongono) ---
        string svc = serviceName.IsNull ? string.Empty : serviceName.Value.Trim();
        if (svc != "ps_game" && svc != "ps_login")
        {
            sp.Send("ERROR: serviceName non valido.");
            return;
        }
        if (cmmd.IsNull)
        {
            sp.Send("ERROR: comando nullo.");
            return;
        }
        string command = cmmd.Value;

        try
        {
            // header: marker + service name (256 byte, zero-padded)
            byte[] rawCommon = new byte[HeaderSize];
            using (var hms = new MemoryStream(rawCommon))
            using (var hbw = new BinaryWriter(hms))
            {
                hbw.Write(HeaderMarker);
                hbw.Write(Encoding.ASCII.GetBytes(svc));
            }

            byte[] cmdBytes = Encoding.ASCII.GetBytes(command);
            byte[] msg;
            using (var ms = new MemoryStream())
            using (var bw = new BinaryWriter(ms))
            {
                short fileSize = (short)(2 + rawCommon.Length + 2 + cmdBytes.Length);
                bw.Write(fileSize);
                bw.Write(rawCommon);
                bw.Write((short)cmdBytes.Length);
                bw.Write(cmdBytes);
                msg = ms.ToArray();
            }

            using (var sender = new Socket(AddressFamily.InterNetwork, SocketType.Stream, ProtocolType.Tcp))
            {
                sender.Connect(PsmHost, PsmPort);
                sender.Send(msg);
                byte[] resp = new byte[2048];
                sender.Receive(resp);
                sender.Shutdown(SocketShutdown.Both);
            }
        }
        catch (Exception e)
        {
            retMessage = "Exception: " + e.Message;
        }
        finally
        {
            sp.Send(retMessage);
        }
    }
}
