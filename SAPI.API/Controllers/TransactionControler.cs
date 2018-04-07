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