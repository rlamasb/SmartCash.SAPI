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

            string selectString = "SELECT TOP 1 * FROM [vAddressBalance] WHERE Address = @Address";


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
                        return StatusCode(400, ex.Message);

                    }
                }
                return new ObjectResult(balance);
            }
        }
        [HttpGet("unspent/{address}", Name = "Unspent")]
        public IActionResult GetUnspent(string address)
        {
            List<AddressUnspent> unspent = new List<AddressUnspent>();

            string selectString = "SELECT * FROM [vAddressUnspent] WHERE Address = @Address";


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
                        return StatusCode(400, ex.Message);

                    }
                }
                return new ObjectResult(unspent);
            }
        }

        [HttpPost("unspent/AvailableInputs", Name = "GetAvailableInputs")]
        public IActionResult GetAvailableInputs([FromBody] AvailableInputsRequest request)
        {
            List<AddressUnspent> unspent = new List<AddressUnspent>();

            string selectString = "SELECT * FROM [vAddressUnspent] WHERE Address = @Address";


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
                        return StatusCode(400, ex.Message);

                    }
                }

            }

            if (unspent.Sum(u => u.Value) < request.Amount)
                return StatusCode(400, "Amount exceeds the balance.");
                
            List<AddressUnspent> data = new List<AddressUnspent>();

            foreach (var item in unspent.OrderByDescending(t => t.Value))
            {
                data.Add(item);
                if (data.Sum(d => d.Value) >= request.Amount)
                    break;
            }

            decimal fee = 0.001m;
            var newFee = (((data.Count * 148) + (2 * 34) + 10 + 9) / 1024m) * fee;
            if (newFee > fee)
                fee = newFee;


            fee = (decimal)RoundUp((double)fee, 3);

            return new ObjectResult(new
            {
                Fee = fee,
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