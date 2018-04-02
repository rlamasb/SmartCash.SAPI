using System.Collections.Generic;
using Microsoft.AspNetCore.Mvc;
using System.Linq;
using System.Data.SqlClient;
using Microsoft.Extensions.Configuration;
using System.IO;
using System.Data;
using System;
using System.Reflection;
using BitcoinLib.Services.Coins.Bitcoin;
using BitcoinLib.Responses;
using BitcoinLib.Responses.SharedComponents;

namespace SAPI.API.Controllers
{
    public class BaseController : Controller
    {
        private static IConfiguration Configuration { get; set; }

        internal static BitcoinService CoinService;
        internal static string connString = string.Empty;
        static string serverURL = "http://127.0.0.1:9679";
        static string serverUser = string.Empty;
        static string serverPass = string.Empty;
        public BaseController()
        {

            var builder = new ConfigurationBuilder()
                        .SetBasePath((Directory.GetCurrentDirectory()))
                        .AddJsonFile("appsettings.json");
            Configuration = builder.Build();


            connString = $"Server=tcp:localhost,1433;Initial Catalog=SAPI;User ID=sa;Password={Configuration["SyncDb"]};Connection Timeout=30;";
            serverUser = Configuration["rpcuser"];
            serverPass = Configuration["rpcpass"];

            CoinService = new BitcoinService(serverURL,
                                             serverUser,
                                             serverPass,
                                             "",
                                             60);
            CoinService.Parameters.CoinLongName = "SmartCash";
            CoinService.Parameters.CoinShortName = "SMART";
            CoinService.Parameters.IsoCurrencyCode = "XSC";
            CoinService.Parameters.UseTestnet = false;


        }

        internal static List<T> DataReaderMapToList<T>(IDataReader dr)
        {
            List<T> list = new List<T>();
            T obj = default(T);
            while (dr.Read())
            {
                obj = Activator.CreateInstance<T>();
                foreach (PropertyInfo prop in obj.GetType().GetProperties())
                {
                    if (!object.Equals(dr[prop.Name], DBNull.Value))
                    {
                        prop.SetValue(obj, dr[prop.Name], null);
                    }
                }
                list.Add(obj);
            }
            return list;
        }
    }
}