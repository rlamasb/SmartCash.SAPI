using System;

namespace SAPI.API.Model
{
    public partial class AddressUnspent
    {
        public string Txid { get; set; }
        public short Index { get; set; }
        public string Address { get; set; }
        public decimal Value { get; set; }

    }
}