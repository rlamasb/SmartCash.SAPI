using System;
using System.Collections.Generic;

namespace SAPI.API.Model
{
    public class Transaction
    {
        public string Txid { get; set; }
        public string BlockHash { get; set; }
        public int Confirmation { get; set; }
        public DateTime Time { get; set; }

    }
}