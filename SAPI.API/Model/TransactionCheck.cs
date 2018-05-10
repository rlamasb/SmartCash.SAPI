using System;
using BitcoinLib.Responses;

namespace SAPI.API.Model
{
    public class TransactionCheck
    {
        public string Txid { get; set; }
        public DateTime BroadcastTime { get; set; }
        public DecodeRawTransactionResponse Transaction { get; set; }
       
    }
}