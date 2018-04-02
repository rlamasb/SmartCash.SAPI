using System;

namespace SAPI.API.Model
{
    public class AddressBalance
    {
        public string Address { get; set; }

        public System.Nullable<decimal> Received { get; set; }

        public System.Nullable<decimal> Sent { get; set; }

        public System.Nullable<decimal> Balance { get; set; }

    }
}