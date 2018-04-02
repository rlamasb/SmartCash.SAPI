using System;

namespace SAPI.API.Model
{
    public class TransactionInput
    {
        public string TxidIn { get; set; }
        public int IndexIn { get; set; }
        public string TxidOut { get; set; }
        public int IndexOut { get; set; }
        public string Address { get; set; }
        public decimal Value { get; set; }

    }
}