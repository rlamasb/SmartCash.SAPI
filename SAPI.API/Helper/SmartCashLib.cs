using BitcoinLib.Requests.CreateRawTransaction;
using BitcoinLib.RPC.Specifications;
using BitcoinLib.Services;
using BitcoinLib.Services.Coins.Bitcoin;

namespace SAPI.API
{
    public class SmartCashLib : BitcoinService
    {
        public SmartCashLib(string daemonUrl, string rpcUsername, string rpcPassword, string walletPassword, short rpcRequestTimeoutInSeconds)
            : base(daemonUrl, rpcUsername, rpcPassword, walletPassword, rpcRequestTimeoutInSeconds)
        {
            
        }
        public string CreateRawTransaction(CreateRawTransactionRequest rawTransaction, uint lockTime)
        {
            return _rpcConnector.MakeRequest<string>(RpcMethods.createrawtransaction, rawTransaction.Inputs, rawTransaction.Outputs, lockTime);
        }

        public string SendRawTransaction(string rawTransactionHexString, bool allowHighFees, bool instantPay)
        {
            return _rpcConnector.MakeRequest<string>(RpcMethods.sendrawtransaction, rawTransactionHexString, allowHighFees, instantPay);
        }

    }
}