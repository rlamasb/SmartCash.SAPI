using System;

namespace SAPI.API.Model
{
    public class DepositHistoryRequestModel
    {
        public string Address { get; set; }
        public DateTime? DateFrom { get; set; }
        public DateTime? DateTo { get; set; }
        public int? PageNumber { get; set; }
        public int? PageSize { get; set; }

    }


}