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
    public class AddressController : BaseController
    {
        public AddressController(IHostingEnvironment hostingEnvironment, ILogger<AddressController> log) : base(hostingEnvironment, log)
        {

        }

        /// <summary>
        ///     Returns address balance
        /// </summary>
        [HttpGet("balance/{address}", Name = "Balance")]
        public IActionResult GetBalance(string address)
        {
            List<AddressBalance> balance = new List<AddressBalance>();

            string selectString = @" SELECT TOP 1 Address,
                                            Received,
                                            Sent,
                                            Balance 
                                       FROM [vAddressBalance] 
                                      WHERE Address = @Address";


            using (SqlConnection conn = new SqlConnection(connString))
            {

                using (SqlCommand comm = new SqlCommand(selectString, conn))
                {
                    comm.Parameters.AddWithValue("@Address", address);

                    try
                    {
                        conn.Open();
                        using (SqlDataReader dr = comm.ExecuteReader())
                        {
                            balance = DataReaderMapToList<AddressBalance>(dr);
                        }

                    }
                    catch (Exception ex)
                    {
                        return BadRequest(ex.ToErrorObject());

                    }
                }
                return new ObjectResult(balance);
            }
        }


        /// <summary>
        ///     Returns address balance
        /// </summary>
        [HttpPost("deposits", Name = "DepositHistory")]
        public IActionResult GetDepositHistory([FromBody] DepositHistoryRequestModel data)
        {
            if (data.PageSize > 100)
                data.PageSize = 100;

            if (data.PageNumber < 1)
                data.PageNumber = 1;

            List<DepositHistory> history = new List<DepositHistory>();
            string cmdString = "EXEC Address_Deposit_History @address, @dateFrom, @dateTo, @PageNumber,	@PageSize";

            using (SqlConnection conn = new SqlConnection(connString))
            {

                using (SqlCommand comm = new SqlCommand())
                {
                    comm.Connection = conn;
                    comm.CommandText = cmdString;
                    comm.Parameters.AddWithValue("@address", data.Address);
                    comm.Parameters.AddWithValue("@dateFrom", (object)data.DateFrom ?? DBNull.Value);
                    comm.Parameters.AddWithValue("@dateTo", (object)data.DateTo ?? DBNull.Value);
                    comm.Parameters.AddWithValue("@PageNumber", (object)data.PageNumber ?? 1);
                    comm.Parameters.AddWithValue("@PageSize", (object)data.PageSize ?? 10);
                    try
                    {
                        conn.Open();
                        using (SqlDataReader dr = comm.ExecuteReader())
                        {
                            history = DataReaderMapToList<DepositHistory>(dr);
                        }
                    }
                    catch (Exception ex)
                    {
                        return BadRequest(ex.ToErrorObject());
                    }
                }
            }
            return new ObjectResult(history);


        }

        [HttpPost("balances/", Name = "Balances")]
        public IActionResult GetBalances([FromBody] List<string> addresses)
        {

            List<AddressBalance> balance = new List<AddressBalance>();
            List<string> query = new List<string>();

            foreach (var item in addresses)
            {
                query.Add("'" + item + "'");
            }


            string selectString = @"
                     SELECT a.Address,
                            a.Received,
                            a.Sent,
                            a.Balance
                       FROM vAddressBalance a 
                      WHERE a.Address in (" + string.Join(",", query) + ")";


            using (SqlConnection conn = new SqlConnection(connString))
            {

                using (SqlCommand comm = new SqlCommand(selectString, conn))
                {
                    try
                    {
                        conn.Open();
                        using (SqlDataReader dr = comm.ExecuteReader())
                        {
                            balance = DataReaderMapToList<AddressBalance>(dr);
                        }

                    }
                    catch (Exception ex)
                    {
                        return BadRequest(ex.ToErrorObject());

                    }
                }
                return new ObjectResult(balance);
            }

        }



        [HttpGet("unspent/{address}", Name = "Unspent")]
        public IActionResult GetUnspent(string address)
        {
            List<AddressUnspent> unspent = new List<AddressUnspent>();

            string selectString = @" SELECT Txid,
                                            [Index],
                                            Address,
                                            Value 
                                       FROM [vAddressUnspent] 
                                      WHERE Address = @Address";


            using (SqlConnection conn = new SqlConnection(connString))
            {

                using (SqlCommand comm = new SqlCommand(selectString, conn))
                {
                    comm.Parameters.AddWithValue("@Address", address);

                    try
                    {
                        conn.Open();
                        using (SqlDataReader dr = comm.ExecuteReader())
                        {
                            unspent = DataReaderMapToList<AddressUnspent>(dr);
                        }

                    }
                    catch (Exception ex)
                    {
                        return BadRequest(ex.ToErrorObject());
                    }
                }
                return new ObjectResult(unspent);
            }
        }

        [HttpPost("unspent/AvailableInputs", Name = "GetAvailableInputs")]
        public IActionResult GetAvailableInputs([FromBody] AvailableInputsRequest request)
        {
            List<AddressUnspent> unspent = new List<AddressUnspent>();

            string selectString = @" SELECT Txid,
                                            [Index],
                                            Address,
                                            Value, 
                                            '' as ScriptPubKey 
                                       FROM [vAddressUnspent] 
                                      WHERE Address = @Address";


            using (SqlConnection conn = new SqlConnection(connString))
            {

                using (SqlCommand comm = new SqlCommand(selectString, conn))
                {
                    comm.Parameters.AddWithValue("@Address", request.Address);

                    try
                    {
                        conn.Open();
                        using (SqlDataReader dr = comm.ExecuteReader())
                        {
                            unspent = DataReaderMapToList<AddressUnspent>(dr);
                        }

                    }
                    catch (Exception ex)
                    {
                        return BadRequest(ex.ToErrorObject());

                    }
                }

            }

            decimal fee = 0.001m;
            var newFee = (((unspent.Count * 148) + (2 * 34) + 10 + 9) / 1024m) * fee;
            if (newFee > fee)
                fee = newFee;

            fee = (decimal)RoundUp((double)fee, 3);

            if (unspent.Sum(u => u.Value) < (request.Amount + fee))
                return BadRequest(new Exception("Amount exceeds the balance of [" + unspent.Sum(u => u.Value).ToString() + "]").ToErrorObject());

            List<AddressUnspent> data = new List<AddressUnspent>();

            foreach (var item in unspent.OrderByDescending(t => t.Value))
            {
                data.Add(item);
                if (data.Sum(d => d.Value) >= request.Amount)
                    break;
            }

            fee = 0.001m;
            newFee = (((data.Count * 148) + (2 * 34) + 10 + 9) / 1024m) * fee;
            if (newFee > fee)
                fee = newFee;


            fee = (decimal)RoundUp((double)fee, 3);

            string scriptPubKey = string.Empty;

            foreach (var item in data)
            {

                var raw = CoinService.GetRawTransaction(item.Txid, 1);

                foreach (var v in raw.Vout)
                {
                    if (Convert.ToDecimal(v.Value) == item.Value && v.ScriptPubKey.Addresses.ToList().Contains(item.Address))
                    {
                        scriptPubKey = v.ScriptPubKey.Hex;
                        break;
                    }
                }
                if (!string.IsNullOrEmpty(scriptPubKey))
                    break;
            }

            return new ObjectResult(new
            {
                Fee = fee,
                ScriptPubKey = scriptPubKey,
                Inputs = data
            });

        }
        public static double RoundUp(double input, int places)
        {
            double multiplier = Math.Pow(10, Convert.ToDouble(places));
            return Math.Ceiling(input * multiplier) / multiplier;
        }
    }
}