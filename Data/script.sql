USE [master]
GO
USE master

IF EXISTS(select * from sys.databases where name='SAPI')
BEGIN
    DROP DATABASE SAPI
END

/****** Object:  Database [SAPI]    Script Date: 30/03/2018 8:19:53 PM ******/
CREATE DATABASE [SAPI]
 CONTAINMENT = NONE
 ON  PRIMARY 
( NAME = N'SAPI', FILENAME = N'/var/opt/mssql/data/SAPI.mdf' , SIZE = 204800KB , MAXSIZE = UNLIMITED, FILEGROWTH = 65536KB )
 LOG ON 
( NAME = N'SAPI_log', FILENAME = N'/var/opt/mssql/data/SAPI_log.ldf' , SIZE = 401408KB , MAXSIZE = 2048GB , FILEGROWTH = 65536KB )
GO
ALTER DATABASE [SAPI] SET COMPATIBILITY_LEVEL = 140
GO
IF (1 = FULLTEXTSERVICEPROPERTY('IsFullTextInstalled'))
begin
EXEC [SAPI].[dbo].[sp_fulltext_database] @action = 'enable'
end
GO
ALTER DATABASE [SAPI] SET ANSI_NULL_DEFAULT OFF 
GO
ALTER DATABASE [SAPI] SET ANSI_NULLS OFF 
GO
ALTER DATABASE [SAPI] SET ANSI_PADDING OFF 
GO
ALTER DATABASE [SAPI] SET ANSI_WARNINGS OFF 
GO
ALTER DATABASE [SAPI] SET ARITHABORT OFF 
GO
ALTER DATABASE [SAPI] SET AUTO_CLOSE OFF 
GO
ALTER DATABASE [SAPI] SET AUTO_SHRINK OFF 
GO
ALTER DATABASE [SAPI] SET AUTO_UPDATE_STATISTICS ON 
GO
ALTER DATABASE [SAPI] SET CURSOR_CLOSE_ON_COMMIT OFF 
GO
ALTER DATABASE [SAPI] SET CURSOR_DEFAULT  GLOBAL 
GO
ALTER DATABASE [SAPI] SET CONCAT_NULL_YIELDS_NULL OFF 
GO
ALTER DATABASE [SAPI] SET NUMERIC_ROUNDABORT OFF 
GO
ALTER DATABASE [SAPI] SET QUOTED_IDENTIFIER OFF 
GO
ALTER DATABASE [SAPI] SET RECURSIVE_TRIGGERS OFF 
GO
ALTER DATABASE [SAPI] SET  DISABLE_BROKER 
GO
ALTER DATABASE [SAPI] SET AUTO_UPDATE_STATISTICS_ASYNC OFF 
GO
ALTER DATABASE [SAPI] SET DATE_CORRELATION_OPTIMIZATION OFF 
GO
ALTER DATABASE [SAPI] SET TRUSTWORTHY OFF 
GO
ALTER DATABASE [SAPI] SET ALLOW_SNAPSHOT_ISOLATION OFF 
GO
ALTER DATABASE [SAPI] SET PARAMETERIZATION SIMPLE 
GO
ALTER DATABASE [SAPI] SET READ_COMMITTED_SNAPSHOT OFF 
GO
ALTER DATABASE [SAPI] SET HONOR_BROKER_PRIORITY OFF 
GO
ALTER DATABASE [SAPI] SET RECOVERY FULL 
GO
ALTER DATABASE [SAPI] SET  MULTI_USER 
GO
ALTER DATABASE [SAPI] SET PAGE_VERIFY CHECKSUM  
GO
ALTER DATABASE [SAPI] SET DB_CHAINING OFF 
GO
ALTER DATABASE [SAPI] SET FILESTREAM( NON_TRANSACTED_ACCESS = OFF ) 
GO
ALTER DATABASE [SAPI] SET TARGET_RECOVERY_TIME = 60 SECONDS 
GO
ALTER DATABASE [SAPI] SET DELAYED_DURABILITY = DISABLED 
GO
ALTER DATABASE [SAPI] SET QUERY_STORE = OFF
GO
USE [SAPI]
GO
ALTER DATABASE SCOPED CONFIGURATION SET IDENTITY_CACHE = ON;
GO
ALTER DATABASE SCOPED CONFIGURATION SET LEGACY_CARDINALITY_ESTIMATION = OFF;
GO
ALTER DATABASE SCOPED CONFIGURATION FOR SECONDARY SET LEGACY_CARDINALITY_ESTIMATION = PRIMARY;
GO
ALTER DATABASE SCOPED CONFIGURATION SET MAXDOP = 0;
GO
ALTER DATABASE SCOPED CONFIGURATION FOR SECONDARY SET MAXDOP = PRIMARY;
GO
ALTER DATABASE SCOPED CONFIGURATION SET PARAMETER_SNIFFING = ON;
GO
ALTER DATABASE SCOPED CONFIGURATION FOR SECONDARY SET PARAMETER_SNIFFING = PRIMARY;
GO
ALTER DATABASE SCOPED CONFIGURATION SET QUERY_OPTIMIZER_HOTFIXES = OFF;
GO
ALTER DATABASE SCOPED CONFIGURATION FOR SECONDARY SET QUERY_OPTIMIZER_HOTFIXES = PRIMARY;
GO
USE [SAPI]
GO
/****** Object:  Table [dbo].[TransactionInput]    Script Date: 30/03/2018 8:19:53 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[TransactionInput](
	[TxidIn] [char](64) NOT NULL,
	[IndexIn] [smallint] NOT NULL,
	[TxidOut] [char](64) NOT NULL,
	[IndexOut] [smallint] NOT NULL,
	[Address] [char](34) MASKED WITH (FUNCTION = 'default()') NOT NULL,
	[Value] [decimal](16, 8) NOT NULL,
PRIMARY KEY CLUSTERED 
(
	[TxidIn] ASC,
	[IndexIn] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
) ON [PRIMARY]
GO
/****** Object:  Table [dbo].[TransactionOutput]    Script Date: 30/03/2018 8:19:53 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[TransactionOutput](
	[Txid] [char](64) NOT NULL,
	[Index] [smallint] NOT NULL,
	[Address] [char](34) NOT NULL,
	[Value] [decimal](16, 8) NOT NULL,
PRIMARY KEY CLUSTERED 
(
	[Txid] ASC,
	[Index] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
) ON [PRIMARY]
GO
/****** Object:  View [dbo].[vAddressSpent]    Script Date: 30/03/2018 8:19:53 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE VIEW [dbo].[vAddressSpent]
AS
SELECT tou.*
FROM [dbo].[TransactionOutput] tou
    LEFT JOIN [dbo].[TransactionInput] tin
        ON tou.Txid = tin.TxidOut
           AND tou.[Index] = tin.IndexOut
WHERE tin.TxidOut IS NOT NULL;
GO
/****** Object:  View [dbo].[vAddressUnspent]    Script Date: 30/03/2018 8:19:53 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE VIEW [dbo].[vAddressUnspent] WITH SCHEMABINDING
AS
SELECT tou.Txid, tou.[Index], tou.Address, tou.Value
FROM [dbo].[TransactionOutput] tou
    LEFT JOIN [dbo].[TransactionInput] tin
        ON tou.Txid = tin.TxidOut
           AND tou.[Index] = tin.IndexOut
WHERE tin.TxidOut IS NULL;
GO
/****** Object:  Table [dbo].[Transaction]    Script Date: 30/03/2018 8:19:53 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[Transaction](
	[Txid] [char](64) NOT NULL,
	[BlockHash] [char](64) NOT NULL,
	[Version] [tinyint] NOT NULL,
	[Time] [datetime] NOT NULL,
	[IsRemoved] [bit] NULL,
	[IsWebWallet] [bit] NULL,
	[RawTransaction] [varchar](max) NULL,
PRIMARY KEY NONCLUSTERED 
(
	[Txid] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
) ON [PRIMARY] TEXTIMAGE_ON [PRIMARY]
GO
/****** Object:  View [dbo].[vAddressBalance]    Script Date: 30/03/2018 8:19:53 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO


CREATE VIEW [dbo].[vAddressBalance]
AS


SELECT a.[Address],
       SUM(o.[Value]) AS 'Received',
       SUM(o.[Value] - ISNULL(i.[Value], 0)) AS 'Sent',
	   ISNULL(SUM(i.[Value]), 0) AS 'Balance'

FROM
(SELECT DISTINCT [Address] FROM [dbo].[TransactionOutput] AS tou) a
    LEFT JOIN
    (
        SELECT t.[Address],
               SUM(t.[Value]) AS 'Value'
        FROM [dbo].[vAddressUnspent] AS t
        GROUP BY t.[Address]
    ) i
        ON i.[Address] = a.[Address]
    LEFT JOIN
    (
        SELECT [tou].[Address],
               SUM([tou].[Value]) AS 'Value'
        FROM [dbo].[Transaction] AS t
            LEFT JOIN [dbo].[TransactionOutput] AS tou
                ON tou.[Txid] = t.[Txid]
        WHERE tou.[Txid] IS NOT NULL
        GROUP BY [tou].[Address]
    ) o
        ON o.[Address] = a.[Address]
GROUP BY a.[Address];
GO
/****** Object:  Table [dbo].[Block]    Script Date: 30/03/2018 8:19:53 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[Block](
	[Hash] [char](64) NOT NULL,
	[Height] [int] NOT NULL,
	[Confirmation] [int] NOT NULL,
	[Size] [int] NOT NULL,
	[Difficulty] [decimal](16, 8) NOT NULL,
	[Version] [tinyint] NOT NULL,
	[Time] [datetime] NOT NULL,
PRIMARY KEY NONCLUSTERED 
(
	[Hash] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
) ON [PRIMARY]
GO
SET ANSI_PADDING ON
GO
/****** Object:  Index [IX_Address]    Script Date: 30/03/2018 8:19:54 PM ******/
CREATE NONCLUSTERED INDEX [IX_Address] ON [dbo].[TransactionOutput]
(
	[Address] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
GO
SET ANSI_PADDING ON
GO
/****** Object:  Index [IX_TransactionInput]    Script Date: 30/03/2018 8:19:54 PM ******/
CREATE NONCLUSTERED COLUMNSTORE INDEX [IX_TransactionInput] ON [dbo].[TransactionInput]
(
	[Address]
)WITH (DROP_EXISTING = OFF, COMPRESSION_DELAY = 0) ON [PRIMARY]
GO
SET ANSI_PADDING ON
GO
/****** Object:  Index [IX_TransactionOutput]    Script Date: 30/03/2018 8:19:54 PM ******/
CREATE NONCLUSTERED COLUMNSTORE INDEX [IX_TransactionOutput] ON [dbo].[TransactionOutput]
(
	[Address]
)WITH (DROP_EXISTING = OFF, COMPRESSION_DELAY = 0) ON [PRIMARY]
GO

/****** Object:  Index [IX_Address_Value]    Script Date: 31/03/2018 1:18:13 AM ******/
CREATE NONCLUSTERED INDEX [IX_Address_Value] ON [dbo].[TransactionOutput]
(
	[Address] ASC
)
INCLUDE ( 	[Value]) WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
GO

/****** Object:  Index [IX_TxId_Index]    Script Date: 31/03/2018 1:19:45 AM ******/
CREATE NONCLUSTERED INDEX [IX_TxId_Index] ON [dbo].[TransactionInput]
(
	[TxidOut] ASC,
	[IndexOut] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
GO




USE [master]
GO
ALTER DATABASE [SAPI] SET  READ_WRITE 
GO

USE [SAPI]
GO

-- =============================================  
-- Author:      Ricardo Lamas  
-- Create Date: 22/09/2017  
-- Description: Create New Transaction  
-- =============================================  
CREATE PROCEDURE [Transaction_Create]  
(  
    -- Add the parameters for the stored procedure here  
 @Txid char(64),  
 @BlockHash char(64),  
 @Version tinyint,  
 @Time datetime,  
 @IsWebWallet bit = null,  
 @RawTransaction varchar(max) = null  
)  
AS  
BEGIN  
    -- SET NOCOUNT ON added to prevent extra result sets from  
    -- interfering with SELECT statements.  
    SET NOCOUNT ON  
  
IF(SELECT COUNT(*) FROM [SAPI].[dbo].[Transaction] WHERE txId =@Txid) = 0  
BEGIN  
  
 INSERT INTO [SAPI].[dbo].[Transaction]  
      ([Txid]  
      ,[BlockHash]  
      ,[Version]  
      ,[Time]  
      ,[IsWebWallet]  
      ,[RawTransaction])  
   VALUES  
      (@Txid,  
      @BlockHash,  
      @Version,  
      @Time,  
      @IsWebWallet,  
      @RawTransaction)  
END  
ELSE  
BEGIN  
 UPDATE [SAPI].[dbo].[Transaction] SET [BlockHash] = @BlockHash, [Version] = @Version, [Time] = @Time, IsRemoved = NULL WHERE[Txid] = @Txid AND BlockHash = ''  
END  
  
END
GO













BULK INSERT SAPI.dbo.Block FROM '/smartdata/blocks.txt' WITH (FIRSTROW = 2,FIELDTERMINATOR = ',',ROWTERMINATOR = '\n') 
GO

BULK INSERT SAPI.dbo.[transaction] FROM '/smartdata/transaction.txt' WITH (FIRSTROW = 2,FIELDTERMINATOR = ',',ROWTERMINATOR = '\n') 
GO

BULK INSERT SAPI.dbo.[transactioninput] FROM '/smartdata/transactioninput.txt' WITH (FIRSTROW = 2,FIELDTERMINATOR = ',',ROWTERMINATOR = '\n') 
GO

BULK INSERT SAPI.dbo.[transactionoutput] FROM '/smartdata/transactionoutput.txt' WITH (FIRSTROW = 2,FIELDTERMINATOR = ',',ROWTERMINATOR = '\n') 
GO

SELECT * FROM SAPI.dbo.[vAddressBalance] WHERE Address = 'SXun9XDHLdBhG4Yd1ueZfLfRpC9kZgwT1b'


GO
