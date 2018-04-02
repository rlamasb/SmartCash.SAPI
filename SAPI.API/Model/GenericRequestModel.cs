using System;

namespace SAPI.API.Model
{
    public class GenericRequestModel<T>
    {
        public T Data { get; set; }

        public GenericRequestModel()
        {

        }

        /// <summary>
        /// Constructor
        /// </summary>
        /// <param name="data"></param>
        public GenericRequestModel(T data)
        {
            this.Data = data;
        }
    }
}