using System;

namespace SAPI.API.Model
{
    public class DepositHistory
    {
        public string TxId { get; set; }
        public DateTime Timestamp { get; set; }
        public Decimal Amount { get; set; }

    }


}