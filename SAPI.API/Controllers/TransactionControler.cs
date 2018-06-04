using System.Collections.Generic;
using Microsoft.AspNetCore.Mvc;
using System.Linq;
using System.Data.SqlClient;
using Microsoft.Extensions.Configuration;
using System.IO;
using SAPI.API.Model;
using System;
using Microsoft.AspNetCore.Hosting;
using Microsoft.Extensions.Logging;
using BitcoinLib.Responses;
using BitcoinLib.Responses.SharedComponents;

namespace SAPI.API.Controllers
{
    [Route("api/[controller]")]

    public class TransactionController : BaseController
    {
        public TransactionController(IHostingEnvironment hostingEnvironment, ILogger<AddressController> log) : base(hostingEnvironment, log)
        {

        }

        [HttpPost("send", Name = "SendTransaction")]
        public IActionResult SendTransaction([FromBody] GenericRequestModel<string> txHex)
        {
            string txid = string.Empty;
            string errMessage = string.Empty;
            try
            {
                txid = CoinService.SendRawTransaction(txHex.Data, false);
                var raw = Newtonsoft.Json.JsonConvert.SerializeObject(CoinService.DecodeRawTransaction(txHex.Data));

                string cmdString = "INSERT INTO [TransactionBroadcast] ([TxId],[BroadcastTime],[RawTransaction]) VALUES (@TxId, @BroadcastTime, @RawTransaction)";
                using (SqlConnection conn = new SqlConnection(connString))
                {

                    using (SqlCommand comm = new SqlCommand())
                    {
                        comm.Connection = conn;
                        comm.CommandText = cmdString;
                        comm.Parameters.AddWithValue("@TxId", txid);
                        comm.Parameters.AddWithValue("@BroadcastTime", DateTime.UtcNow);
                        comm.Parameters.AddWithValue("@RawTransaction", raw);
                        try
                        {
                            conn.Open();
                            comm.ExecuteNonQuery();
                        }
                        catch (Exception ex)
                        {
                            Console.WriteLine("SQL Error" + ex.Message);

                        }
                    }
                }

            }
            catch (Exception ex)
            {
                return BadRequest(ex.ToErrorObject());
            }

            return new ObjectResult(new { tx = txid });
        }

        [HttpGet("{txid}", Name = "Transaction")]
        public IActionResult GetTransaction(string txid)
        {
            BitcoinLib.Responses.GetRawTransactionResponse tx = new BitcoinLib.Responses.GetRawTransactionResponse();
            Transaction transaction = new Transaction();

            try
            {
                tx = CoinService.GetRawTransaction(txid, 1);
                transaction.Confirmation = tx.Confirmations;

                using (SqlConnection conn = new SqlConnection(connString))
                {
                    conn.Open();

                    string selectString = @" SELECT TxidIn,
                                                    IndexIn,
                                                    TxidOut,
                                                    IndexOut,
                                                    Address,
                                                    Value 
                                               FROM [TransactionInput] 
                                              WHERE txidin = @txid";

                    using (SqlCommand comm = new SqlCommand(selectString, conn))
                    {
                        comm.Parameters.AddWithValue("@txid", txid);

                        try
                        {
                            using (SqlDataReader dr = comm.ExecuteReader())
                            {
                                transaction.TransactionInput = DataReaderMapToList<TransactionInput>(dr);
                            }

                        }
                        catch (Exception ex)
                        {
                            return StatusCode(400, ex.Message);

                        }
                    }

                    selectString = @"SELECT Txid,
                                            [Index],
                                            Address,
                                            Value 
                                       FROM [TransactionOutput] 
                                      WHERE txid = @txid";

                    using (SqlCommand comm = new SqlCommand(selectString, conn))
                    {
                        comm.Parameters.AddWithValue("@txid", txid);

                        try
                        {
                            using (SqlDataReader dr = comm.ExecuteReader())
                            {
                                transaction.TransactionOutput = DataReaderMapToList<TransactionOutput>(dr);
                            }

                        }
                        catch (Exception ex)
                        {
                            return StatusCode(400, ex.Message);

                        }
                    }

                }



                transaction.BlockHash = tx.BlockHash;
                transaction.Time = Common.UnixTimeStampToDateTime(tx.Time);
                transaction.Txid = tx.TxId;


            }
            catch (Exception ex)
            {
                return BadRequest(ex.ToErrorObject());
            }
            return new ObjectResult(transaction);

        }

        [HttpGet("check/{txid}", Name = "CheckTransaction")]
        public IActionResult CheckTransaction(string txid)
        {
            using (SqlConnection conn = new SqlConnection(connString))
            {
                conn.Open();

                TransactionCheck response = new TransactionCheck();
                Transaction transaction = new Transaction();
                string selectString = @" SELECT TxId,
                                                BroadcastTime,
                                                RawTransaction 
                                           FROM [TransactionBroadCast] 
                                          WHERE txid = @txid";
                                          
                using (SqlCommand comm = new SqlCommand(selectString, conn))
                {
                    comm.Parameters.AddWithValue("@txid", txid);

                    try
                    {
                        using (SqlDataReader dr = comm.ExecuteReader())
                        {

                            if (dr.Read())
                            {
                                response.Txid = dr["Txid"].ToString();
                                response.BroadcastTime = Convert.ToDateTime(dr["BroadcastTime"]);
                                response.Transaction = Newtonsoft.Json.JsonConvert.DeserializeObject<DecodeRawTransactionResponse>(dr["RawTransaction"].ToString());
                                transaction.Time = response.BroadcastTime;
                                transaction.Txid = response.Txid;
                            }
                            else
                            {
                                try
                                {
                                    response.Transaction = new DecodeRawTransactionResponse();
                                    var raw = CoinService.GetRawTransaction(txid, 1);
                                    transaction.BlockHash = raw.BlockHash;
                                    transaction.Confirmation = raw.Confirmations;
                                    transaction.Txid = raw.TxId;
                                    transaction.Time = Common.UnixTimeStampToDateTime(raw.BlockTime);
                                    response.Txid = raw.TxId;
                                    response.Transaction.TxId = raw.TxId;
                                    response.Transaction.Vin = raw.Vin;
                                    response.Transaction.Vout = raw.Vout;

                                    if (string.IsNullOrEmpty(response.Txid))
                                    {
                                        var memPool = CoinService.GetRawMemPool(false);

                                        foreach (var item in memPool.TxIds)
                                        {
                                            if (item == txid)
                                            {

                                                raw = CoinService.GetRawTransaction(txid, 1);
                                                response.Transaction.TxId = raw.TxId;
                                                response.Transaction.Vin = raw.Vin;
                                                response.Transaction.Vout = raw.Vout;
                                                break;

                                            }
                                        }

                                    }
                                }
                                catch
                                {
                                    return StatusCode(400, "Transaction not found!");
                                }


                            }

                            if (string.IsNullOrEmpty(response.Txid))
                            {
                                return StatusCode(400, "Transaction not found!");
                            }

                        }



                        var countInput = 0;
                        foreach (var transactionInput in response.Transaction.Vin)
                        {
                            transaction.TransactionInput.Add(GetTransactionInput(transactionInput, txid, countInput));
                            countInput++;
                        }

                        foreach (var TransactionOutput in response.Transaction.Vout)
                        {
                            transaction.TransactionOutput.Add(
                                    new TransactionOutput()
                                    {
                                        Txid = response.Txid,
                                        Index = TransactionOutput.N,
                                        Address = TransactionOutput.ScriptPubKey.Addresses.FirstOrDefault(),
                                        Value = TransactionOutput.Value
                                    }
                            );
                        }





                        return new ObjectResult(transaction);
                    }
                    catch (Exception ex)
                    {
                        return StatusCode(400, ex.Message);

                    }
                }



            }
        }

        TransactionInput GetTransactionInput(Vin transactionInput, string txid, int index)
        {
            string coinbase = transactionInput.CoinBase;
            string txidOut = transactionInput.TxId;
            long indexOut = Convert.ToInt32(transactionInput.Vout);
            string sAddress = "";
            decimal sValue = 0;
            TransactionInput result = new TransactionInput();

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
                            Console.WriteLine("SQL Error" + ex.Message);
                            throw;
                        }
                    }
                }
            }
            result.TxidIn = txid;
            result.IndexIn = index;
            result.TxidOut = txidOut;
            result.IndexOut = Convert.ToInt32(indexOut);
            result.Address = sAddress;
            result.Value = sValue;
            return result;

        }

    }
}