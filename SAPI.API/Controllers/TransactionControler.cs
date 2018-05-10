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

                    string selectString = "SELECT * FROM [TransactionInput] WHERE txidin = @txid";
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

                    selectString = "SELECT * FROM [TransactionOutput] WHERE txid = @txid";
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
                string selectString = "SELECT * FROM [TransactionBroadCast] WHERE txid = @txid";
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
                            }

                        }
                        return new ObjectResult(response);
                    }
                    catch (Exception ex)
                    {
                        return StatusCode(400, ex.Message);

                    }
                }



            }
        }

    }
}