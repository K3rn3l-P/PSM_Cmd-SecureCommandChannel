//------------------------------------------------------------------------------
// <copyright file="CSSqlStoredProcedure.cs" company="Microsoft">
//     Copyright (c) Microsoft Corporation.  All rights reserved.
// </copyright>
//------------------------------------------------------------------------------
using System;
using System.Data;
using System.Data.SqlClient;
using System.Data.SqlTypes;
using Microsoft.SqlServer.Server;
using System.Text;
using System.IO;
using System.Net.Sockets;

public partial class StoredProcedures
{

    [Microsoft.SqlServer.Server.SqlProcedure]
    public static void Command(SqlString serviceName, SqlString cmmd)
    {

        // Data buffer for incoming data.
        byte[] bytes = new byte[2048];
        SqlPipe sp = SqlContext.Pipe;
        Socket sender = null;
        string retMessage = "0";
        // Connect to a remote device.
        try
        {
            // Create a TCP/IP  socket.
            sender = new Socket(AddressFamily.InterNetwork, SocketType.Stream, ProtocolType.Tcp);

            // Connect the socket PSMagent Service endpoint.
            sender.Connect("127.0.0.1", 40900);

            var temp = new BinaryWriter(new MemoryStream(258));
            var binWriter = new BinaryWriter(new MemoryStream());

            /*  File Info
              * short = file size 2 bytes (20 01 -> 01 20)
              * short = command position 2 bytes (01 05 -> 01 05)
              * string = service name (ps_game) 256 bytes
              * short = comando Length 2 bytes
              * string = comando X bytes
             */

            string command = cmmd.ToString();

            //command position + service name (allways the same)
            temp.Write((short)1281);
            temp.Write(Encoding.ASCII.GetBytes(serviceName.ToString()));//write service name eg:ps_game
            byte[] rawCommon = new byte[258];

            var ms = (MemoryStream)temp.BaseStream;
            //Set pointer to the beginning of the stream
            ms.Position = 0;
            ms.Read(rawCommon, 0, (int)ms.Length);

            #region command position + service name (allways the same)
            /*byte[] rawCommon = {
                0x01, 0x05, 0x70, 0x73, 0x5F, 0x67, 0x61, 0x6D, 0x65, 0x00, 0x00, 0x00,
                0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
                0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
                0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
                0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
                0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
                0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
                0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
                0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
                0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
                0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
                0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
                0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
                0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
                0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
                0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
                0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
                0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
                0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
                0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
                0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
                0x00, 0x00, 0x00, 0x00, 0x00, 0x00
            };*/
            #endregion command position + service name (allways the same)

            //Set pointer to the beginning of the stream
            binWriter.BaseStream.Position = 0;

            // 2 bytes(fileSize) + rawCommon.Length + 2 bytes(command Size) + command.Length
            short fileSize = (short)(2 + rawCommon.Length + 2 + command.Length);
            binWriter.Write(fileSize);
            binWriter.Write(rawCommon);
            binWriter.Write((short)command.Length);
            binWriter.Write(Encoding.ASCII.GetBytes(command));

            byte[] msg = ((MemoryStream)binWriter.BaseStream).ToArray();

            // Send the data through the socket.
            int bytesSent = sender.Send(msg);

            // Receive the response from the remote device.
            int bytesRec = sender.Receive(bytes);
            // File.WriteAllBytes("C:\resp", bytes);

            // retMessage = String.Format("{0}", Encoding.ASCII.GetString(bytes, 0, bytesRec));

            // Release the socket. 
            sender.Shutdown(SocketShutdown.Both);

        }
        catch (ArgumentNullException e)
        {
            retMessage = String.Format("ArgumentNullException : {0}", e.ToString());
        }
        catch (SocketException e)
        {
            retMessage = String.Format("SocketException : {0}", e.ToString());
        }
        catch (Exception e)
        {
            retMessage = String.Format("Unexpected exception : {0}", e.ToString());
        }
        finally
        {
            // Release the socket. 
            sender.Close();

            //send retMessage to the client (sql server)
            sp.Send(retMessage);
        }

    }

}
