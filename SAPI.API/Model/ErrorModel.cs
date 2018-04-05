using System;
using Newtonsoft.Json;

namespace SAPI.API.Model
{
    public partial class ErrorModel
    {
        [JsonProperty(NullValueHandling = NullValueHandling.Ignore)]
        public string Error { get; set; }
        
        [JsonProperty(NullValueHandling = NullValueHandling.Ignore)]
        public string Description { get; set; }

    }
}