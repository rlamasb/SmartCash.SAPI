using System.Collections.Generic;
using Microsoft.AspNetCore.Mvc;
using System.Linq;
using System.Data.SqlClient;
using Microsoft.Extensions.Configuration;
using System.IO;
using SAPI.API.Model;
using System;

namespace SAPI.API.Controllers
{
    [Route("api/[controller]")]
    public class AddressController : BaseController
    {

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

    }
}