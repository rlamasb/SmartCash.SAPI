using System;
using System.Collections.Generic;
using System.Data.SqlClient;
using System.Diagnostics;
using System.IO;
using System.Net;
using System.Text;
using Microsoft.Extensions.Configuration;
using Newtonsoft.Json;
using BitcoinLib.Services.Coins.Bitcoin;
using System.Linq;
using BitcoinLib.Responses;
using BitcoinLib.Responses.SharedComponents;

namespace SAPI.Sync
{
    class Program
    {

        static string serverURL = "http://127.0.0.1:9679";
        static string serverUser = string.Empty;
        static string serverPass = string.Empty;
        static string connString = string.Empty;

        private static bool rescan = false;
        private static int lastBlock = 0;
        private static IConfiguration Configuration { get; set; }


        static void Main(string[] args)
        {
            var builder = new ConfigurationBuilder()
            .SetBasePath((Directory.GetCurrentDirectory()))
            .AddJsonFile("appsettings.json");
            Configuration = builder.Build();


            connString = $"Server=tcp:localhost,1433;Initial Catalog=SAPI;User ID=sa;Password={Configuration["SyncDb"]};Connection Timeout=30;";
            serverUser = Configuration["rpcuser"];
            serverPass = Configuration["rpcpass"];


            var CoinService = new BitcoinService(serverURL,
                                             serverUser,
                                             serverPass,
                                             "",
                                             60);
            CoinService.Parameters.CoinLongName = "SmartCash";
            CoinService.Parameters.CoinShortName = "SMART";
            CoinService.Parameters.IsoCurrencyCode = "XSC";
            CoinService.Parameters.UseTestnet = false;



            //Body
            HashSet<string> tx = new HashSet<string>();


            Sync();

            Console.Write("Done!");


            void Sync()
            {
                #region SyncBlocks


                //Body

                string startBlockHash = string.Empty;

                startBlockHash = GetStartBlockHash();

                if (args.Count() == 1)
                {
                    long blkNumber = Convert.ToInt64(args[0]);

                    if (blkNumber != 999)
                        startBlockHash = CoinService.GetBlockHash(blkNumber);
                    else
                    {
                        blkNumber = CoinService.GetBlockCount() - 30;
                        startBlockHash = CoinService.GetBlockHash(blkNumber);
                    }
                }
                else if (args.Count() == 2)
                {
                    long blkNumber = Convert.ToInt64(args[0]);
                    rescan = Convert.ToBoolean(args[1]);

                    if (blkNumber != 999)
                        startBlockHash = CoinService.GetBlockHash(blkNumber);
                    else
                    {
                        blkNumber = CoinService.GetBlockCount() - 30;
                        startBlockHash = CoinService.GetBlockHash(blkNumber);
                    }

                }

                GetBlockResponse curBlock = new GetBlockResponse();
                if (startBlockHash == null || startBlockHash == "") // Start from scratch
                {
                    startBlockHash = "00000009c4e61bee0e8d6236f847bb1dd23f4c61ca5240b74852184c9bf98c30"; // Block 1
                    curBlock = GetBlock(startBlockHash);
                    InsertBlock(curBlock);
                    foreach (string txid in curBlock.Tx)
                    {
                        GetRawTransactionResponse nextTransaction = GetTransaction(txid);
                        InsertTransaction(nextTransaction);

                        var countInput = 0;
                        // Input
                        foreach (Vin transactionInput in nextTransaction.Vin)
                        {
                            InsertTransactionInput(transactionInput, txid, countInput);
                            countInput++;
                        }

                        // Output
                        foreach (var transactionOutput in nextTransaction.Vout)
                        {
                            if (transactionOutput.ScriptPubKey.Addresses != null)
                            {
                                if (transactionOutput.ScriptPubKey.Addresses.Count > 1)
                                {
                                    Debug.WriteLine("2> Address: " + txid);
                                }
                                InsertTransactionOutput(transactionOutput, txid);
                            }
                            else
                            {
                                Debug.WriteLine("No Address: " + txid);
                            }
                        }

                        tx.Add(txid);

                    }
                }
                else
                {
                    curBlock = GetBlock(startBlockHash);
                }

                //Fix Orphan Blocks
                if (curBlock.Confirmations == -1)
                {
                    DeleteOrphanBlock(curBlock.Hash);
                    startBlockHash = GetStartBlockHash();
                    curBlock = GetBlock(startBlockHash);
                }

                while (curBlock.NextBlockHash != null)
                {
                    // Block
                    curBlock = GetBlock(curBlock.NextBlockHash);

                    Console.WriteLine("Processing Block:" + curBlock.Height.ToString());

                    InsertBlock(curBlock);

                    // Transaction
                    foreach (string txid in curBlock.Tx)
                    {
                        try
                        {

                            GetRawTransactionResponse nextTransaction = GetTransaction(txid);

                            if (!tx.Contains(txid)) //Exclude transactions linked to multiple blocks (Zerocoin Mint/Smartcash Renew)
                            {
                                InsertTransaction(nextTransaction);

                                var countInput = 0;
                                // Input
                                foreach (Vin transactionInput in nextTransaction.Vin)
                                {
                                    InsertTransactionInput(transactionInput, txid, countInput);
                                    countInput++;
                                }

                                // Output
                                foreach (Vout transactionOutput in nextTransaction.Vout)
                                {
                                    if (transactionOutput.ScriptPubKey.Addresses != null)
                                    {
                                        if (transactionOutput.ScriptPubKey.Addresses.Count > 1)
                                        {
                                            Debug.WriteLine("2> Address: " + txid);
                                        }
                                        InsertTransactionOutput(transactionOutput, txid);
                                    }
                                    else
                                    {
                                        Debug.WriteLine("No Address: " + txid);
                                    }
                                }

                                tx.Add(txid);

                            }
                            else
                            {
                                UpdateTransaction(nextTransaction);
                            }
                        }
                        catch
                        {

                        }
                    }

                    //Console.WriteLine(curBlock.height);
                }


                #endregion


                Console.WriteLine("Done");

            }


            string GetStartBlockHash()
            {
                string startBlockHash = "";

                if (rescan)
                    return startBlockHash;
                string selectString = "SELECT TOP 1 [Hash] FROM [Block] ORDER BY [Height] DESC";


                using (SqlConnection conn = new SqlConnection(connString))
                {

                    using (SqlCommand comm = new SqlCommand(selectString, conn))
                    {
                        try
                        {
                            conn.Open();
                            startBlockHash = (string)comm.ExecuteScalar();
                        }
                        catch (Exception ex)
                        {
                            Console.WriteLine("SQL Error" + ex.Message + " : " + "GetStartBlockHash");
                            throw;
                        }
                    }
                }

                return startBlockHash;
            }


            BitcoinLib.Responses.GetBlockResponse GetBlock(string blockHash)
            {

                return CoinService.GetBlock(blockHash, true);

            }

            bool InsertBlock(GetBlockResponse block)
            {
                string cmdString = "INSERT INTO [Block] ([Hash],[Height],[Confirmation],[Size],[Difficulty],[Version],[Time]) VALUES (@Hash, @Height, @Confirmation, @Size, @Difficulty, @Version, @Time)";
                using (SqlConnection conn = new SqlConnection(connString))
                {

                    using (SqlCommand comm = new SqlCommand())
                    {
                        comm.Connection = conn;
                        comm.CommandText = cmdString;
                        comm.Parameters.AddWithValue("@Hash", block.Hash);
                        comm.Parameters.AddWithValue("@Height", block.Height);
                        comm.Parameters.AddWithValue("@Confirmation", block.Confirmations);
                        comm.Parameters.AddWithValue("@Size", block.Size);
                        comm.Parameters.AddWithValue("@Difficulty", block.Difficulty);
                        comm.Parameters.AddWithValue("@Version", block.Version);
                        comm.Parameters.AddWithValue("@Time", UnixTimeStampToDateTime(block.Time));
                        try
                        {
                            conn.Open();
                            comm.ExecuteNonQuery();
                            lastBlock = block.Height;
                        }
                        catch (Exception ex)
                        {
                            if (!rescan)
                                Console.WriteLine("SQL Error" + ex.Message + " : " + JsonConvert.SerializeObject(block));
                            //throw;
                        }
                    }
                }

                return true;
            }

            GetRawTransactionResponse GetTransaction(string txid)
            {

                var raw = CoinService.GetRawTransaction(txid, 1);

                return raw;

            }

            bool InsertTransaction(GetRawTransactionResponse transaction)
            {
                if (!tx.Contains(transaction.TxId)) //Exclude transactions linked to multiple blocks (Zerocoin Mint/Smartcash Renew)
                {
                    string cmdString = "EXEC Transaction_Create @Txid, @BlockHash, @Version, @Time";
                    using (SqlConnection conn = new SqlConnection(connString))
                    {

                        using (SqlCommand comm = new SqlCommand())
                        {
                            comm.Connection = conn;
                            comm.CommandText = cmdString;
                            comm.Parameters.AddWithValue("@Txid", transaction.TxId);
                            comm.Parameters.AddWithValue("@BlockHash", transaction.BlockHash);
                            comm.Parameters.AddWithValue("@Version", transaction.Version);
                            comm.Parameters.AddWithValue("@Time", UnixTimeStampToDateTime(transaction.Time));
                            try
                            {
                                conn.Open();
                                comm.ExecuteNonQuery();
                                tx.Add(transaction.TxId);
                            }
                            catch (Exception ex)
                            {
                                if (!rescan)
                                    Console.WriteLine("SQL Error" + ex.Message + " : " + JsonConvert.SerializeObject(transaction));
                                throw;
                            }
                        }
                    }
                }
                return true;
            }


            bool UpdateTransaction(GetRawTransactionResponse transaction)
            {
                string cmdString = "EXEC Transaction_Create @Txid, @BlockHash, @Version, @Time";

                using (SqlConnection conn = new SqlConnection(connString))
                {

                    using (SqlCommand comm = new SqlCommand())
                    {
                        comm.Connection = conn;
                        comm.CommandText = cmdString;
                        comm.Parameters.AddWithValue("@Txid", transaction.TxId);
                        comm.Parameters.AddWithValue("@BlockHash", transaction.BlockHash);
                        comm.Parameters.AddWithValue("@Version", transaction.Version);
                        comm.Parameters.AddWithValue("@Time", UnixTimeStampToDateTime(transaction.Time));
                        try
                        {
                            conn.Open();
                            comm.ExecuteNonQuery();
                        }
                        catch (Exception ex)
                        {
                            Console.WriteLine("SQL Error" + ex.Message + " : " + JsonConvert.SerializeObject(transaction));
                            throw;
                        }
                    }
                }

                return true;
            }

            bool InsertTransactionInput(Vin transactionInput, string txid, int index)
            {
                string coinbase = transactionInput.CoinBase;
                string txidOut = transactionInput.TxId;
                long indexOut = index;
                string sAddress = "";
                decimal sValue = 0;

                if (coinbase != null)
                {
                    txidOut = "0000000000000000000000000000000000000000000000000000000000000000";
                    sAddress = "0000000000000000000000000000000000";
                }
                else if (txidOut == "0000000000000000000000000000000000000000000000000000000000000000")
                {
                    indexOut = 0;
                    sAddress = "0000000000000000000000000000000001";
                }
                else
                {
                    string selectString = "SELECT [Address], [Value] FROM [TransactionOutput] WHERE [Txid] = '" + txidOut + "' AND [Index] = " + indexOut;
                    using (SqlConnection conn = new SqlConnection(connString))
                    {

                        using (SqlCommand comm = new SqlCommand(selectString, conn))
                        {
                            try
                            {
                                conn.Open();
                                using (SqlDataReader dr = comm.ExecuteReader())
                                {
                                    while (dr.Read())
                                    {
                                        sAddress = dr["Address"].ToString();
                                        sValue = decimal.Parse(dr["Value"].ToString());
                                    }
                                }

                            }
                            catch (Exception ex)
                            {
                                Console.WriteLine("SQL Error" + ex.Message + " : " + JsonConvert.SerializeObject(transactionInput) + " ; " + txid + " ; " + index.ToString());
                                throw;
                            }
                        }
                    }
                }

                string cmdString = "INSERT INTO [TransactionInput] ([TxidIn],[IndexIn],[TxidOut],[IndexOut],[Address],[Value]) VALUES (@TxidIn, @IndexIn, @TxidOut, @IndexOut, @Address, @Value)";
                using (SqlConnection conn = new SqlConnection(connString))
                {

                    using (SqlCommand comm = new SqlCommand())
                    {
                        comm.Connection = conn;
                        comm.CommandText = cmdString;
                        comm.Parameters.AddWithValue("@TxidIn", txid);
                        comm.Parameters.AddWithValue("@IndexIn", index);
                        comm.Parameters.AddWithValue("@TxidOut", txidOut);
                        comm.Parameters.AddWithValue("@IndexOut", indexOut);
                        comm.Parameters.AddWithValue("@Address", sAddress);
                        comm.Parameters.AddWithValue("@Value", sValue);
                        try
                        {
                            conn.Open();
                            comm.ExecuteNonQuery();
                        }
                        catch (Exception ex)
                        {
                            if (!rescan)
                                Console.WriteLine("SQL Error" + ex.Message + " : " + JsonConvert.SerializeObject(transactionInput) + " ; " + txid + " ; " + index.ToString());

                        }
                    }
                }

                return true;
            }

            bool InsertTransactionOutput(Vout transactionOutput, string txid)
            {

                string cmdString = "INSERT INTO [TransactionOutput] ([Txid],[Index],[Address],[Value]) VALUES (@Txid, @Index, @Address, @Value)";
                using (SqlConnection conn = new SqlConnection(connString))
                {

                    using (SqlCommand comm = new SqlCommand())
                    {

                        comm.Connection = conn;
                        comm.CommandText = cmdString;
                        comm.Parameters.AddWithValue("@Txid", txid);
                        comm.Parameters.AddWithValue("@Index", transactionOutput.N);
                        comm.Parameters.AddWithValue("@Address", transactionOutput.ScriptPubKey.Addresses[0]);
                        comm.Parameters.AddWithValue("@Value", transactionOutput.Value);
                        try
                        {
                            conn.Open();
                            comm.ExecuteNonQuery();
                        }
                        catch (Exception ex)
                        {
                            if (!rescan)
                                Console.WriteLine("SQL Error" + ex.Message + " : " + JsonConvert.SerializeObject(transactionOutput) + " ; " + txid);

                        }
                    }
                }

                return true;
            }

            bool DeleteOrphanBlock(string blockHash)
            {

                using (SqlConnection conn = new SqlConnection(connString))
                {
                    try
                    {
                        conn.Open();

                        using (SqlCommand comm = new SqlCommand("SELECT [Txid] FROM [Transaction] WHERE [BlockHash] = '" + blockHash + "'", conn))
                        {
                            HashSet<string> hTxid = new HashSet<string>();

                            using (SqlDataReader dr = comm.ExecuteReader())
                            {
                                while (dr.Read())
                                {
                                    hTxid.Add(dr["Txid"].ToString());
                                }
                            }

                            foreach (string txid in hTxid)
                            {
                                using (SqlCommand commI = new SqlCommand())
                                {
                                    commI.Connection = conn;
                                    commI.CommandText = "DELETE FROM [TransactionInput] WHERE [TxidIn] = '" + txid + "'";
                                    commI.ExecuteNonQuery();
                                }

                                using (SqlCommand commO = new SqlCommand())
                                {
                                    commO.Connection = conn;
                                    commO.CommandText = "DELETE FROM [TransactionOutput] WHERE [Txid] = '" + txid + "'";
                                    commO.ExecuteNonQuery();
                                }
                            }
                        }

                        using (SqlCommand commT = new SqlCommand())
                        {
                            commT.Connection = conn;
                            commT.CommandText = "DELETE FROM [Transaction] WHERE [BlockHash] = '" + blockHash + "'";
                            commT.ExecuteNonQuery();
                        }

                        using (SqlCommand commB = new SqlCommand())
                        {
                            commB.Connection = conn;
                            commB.CommandText = "DELETE FROM [Block] WHERE [Hash] = '" + blockHash + "'";
                            commB.ExecuteNonQuery();
                        }
                    }
                    catch (Exception ex)
                    {
                        if (!rescan)
                            Console.WriteLine("SQL Error" + ex.Message + " : " + "DeleteOrphanBlock" + " : " + blockHash);
                        throw;
                    }

                }

                return true;
            }


            //
            // Helper Functions
            //
            DateTime UnixTimeStampToDateTime(double unixTimeStamp)
            {
                // Unix timestamp is seconds past epoch
                System.DateTime dtDateTime = new DateTime(1970, 1, 1, 0, 0, 0, 0, System.DateTimeKind.Utc);
                dtDateTime = dtDateTime.AddSeconds(unixTimeStamp);
                return dtDateTime;
            }
        }
    }
}