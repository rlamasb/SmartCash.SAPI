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
            }
            catch (Exception ex)
            {
                return BadRequest(ex.ToErrorObject());
            }

            return new ObjectResult(txid);
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

    }
}