using System;
using System.Collections.Concurrent;
using System.IO;
using Microsoft.Extensions.Logging;
using SAPI.API.Model;

public static class Extensions
{
    public static ErrorModel ToErrorObject(this Exception ex, string description = null)
    {
        return new ErrorModel()
        {
            Error = ex.Message,
            Description = description

        };
    }
}