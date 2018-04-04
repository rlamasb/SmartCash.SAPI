using System;
using System.Collections.Concurrent;
using System.IO;
using Microsoft.Extensions.Logging;

public class CustomLogger : ILogger
    {
        readonly string loggerName;
        readonly CustomLoggerProviderConfiguration loggerConfig;
        public CustomLogger(string name, CustomLoggerProviderConfiguration config)
        {
            this.loggerName = name;
            loggerConfig = config;
        }
        public IDisposable BeginScope<TState>(TState state)
        {
            return null;
        }
        public bool IsEnabled(LogLevel logLevel)
        {
            return true;
            throw new NotImplementedException();
        }
        public void Log<TState>(LogLevel logLevel, EventId eventId, TState state, Exception exception, Func<TState, Exception, string> formatter)
        {
            string message = string.Format("{0}: {1} - {2}", logLevel.ToString(), eventId.Id, formatter(state, exception));
            WriteTextToFile(message);
        }
        private void WriteTextToFile(string message)
        {
            string filePath ="SuperNodeLog.txt";
            using (StreamWriter streamWriter = new StreamWriter(filePath, true))
            {              
                streamWriter.WriteLine(message);
                streamWriter.Close();
            }
        }
    }
public class CustomLoggerProvider : ILoggerProvider
{
    readonly CustomLoggerProviderConfiguration loggerConfig;
    readonly ConcurrentDictionary<string, CustomLogger> loggers =
     new ConcurrentDictionary<string, CustomLogger>();
    public CustomLoggerProvider(CustomLoggerProviderConfiguration config)
    {
        loggerConfig = config;
    }
    public ILogger CreateLogger(string category)
    {
        return loggers.GetOrAdd(category,
         name => new CustomLogger(name, loggerConfig));
    }
    public void Dispose()
    {
        //Write code here to dispose the resources
    }
}
public class CustomLoggerProviderConfiguration
{
    public LogLevel LogLevel { get; set; } = LogLevel.Warning;
    public int EventId { get; set; } = 0;
}