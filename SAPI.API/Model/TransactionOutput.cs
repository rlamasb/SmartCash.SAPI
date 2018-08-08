using System;

namespace SAPI.API.Model
{
    public class TransactionOutput
    {
        public string Txid { get; set; }
        public int Index { get; set; }
        public string Address { get; set; }
        public decimal Value { get; set; }
        public string Asm { get; set; }
        public string Hex { get; set; }

    }
}