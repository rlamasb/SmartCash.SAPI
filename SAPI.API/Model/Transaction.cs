using System;
using System.Collections.Generic;

namespace SAPI.API.Model
{
    public class Transaction
    {
        public Transaction()
        {
            TransactionInput = new List<TransactionInput>();
            TransactionOutput = new List<TransactionOutput>();
        }

        public string Txid { get; set; }
        public string BlockHash { get; set; }
        public int Confirmation { get; set; }
        public DateTime Time { get; set; }

       public List<TransactionInput> TransactionInput { get; set; }

        public List<TransactionOutput> TransactionOutput { get; set; }
    }
}