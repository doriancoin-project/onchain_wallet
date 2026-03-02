import 'package:bitcoin_base/bitcoin_base.dart';
import 'package:on_chain_wallet/app/core.dart';
import 'package:on_chain_wallet/crypto/types/networks.dart';
import 'package:on_chain_wallet/wallet/api/client/core/client.dart';
import 'package:on_chain_wallet/wallet/api/client/networks/bitcoin/types/types.dart';
import 'package:on_chain_wallet/wallet/api/provider/networks/bitcoin/bitcoin.dart';
import 'package:on_chain_wallet/wallet/chain/account.dart';
import 'package:on_chain_wallet/wallet/models/network/core/network/network.dart';
import 'package:on_chain_wallet/wallet/models/token/network/token.dart';
import 'package:on_chain_wallet/wallet/models/transaction/core/transaction.dart';
import 'package:on_chain_wallet/wallet/models/transaction/networks/bitcoin.dart';
abstract class BitcoinClient<T extends IBitcoinAddress> extends NetworkClient<
    BitcoinWalletTransaction,
    BaseBitcoinAPIProvider,
    BaseNetworkToken,
    BitcoinBaseAddress> with HttpImpl {
  @override
  abstract final WalletBitcoinNetwork network;

  Future<BigInt> getAccountBalance(BitcoinBaseAddress address);
  Future<List<UtxoWithAddress>> readUtxos(UtxoAddressDetails address,
      [bool includeTokens = false]);
  @override
  Future<String> sendTransaction(String digest);
  Future<BitcoinFeeRate?> getFeeRate();
  @override
  Future<WalletTransactionStatus> transactionStatus({required String txId});
  @override
  Future<String> genesisHash();
  Future<BtcTransaction> getTx(String txId);
  BitcoinClient clone();
  Future<ElectrumVerbosTxResponse?> getTransactionData(String txId);

  @override
  Future<bool> onInit() async {
    final genesisHash = await this.genesisHash();
    return genesisHash == network.genesisBlock;
  }

  Future<List<BitcoinBlockTransactionInfo>> getTrasactionsBlockInfo(
      List<String> txIds) async {
    txIds = txIds.toSet().toList();
    List<BitcoinBlockTransactionInfo> transactions = [];
    await Future.wait(txIds.map((e) async {
      final result = await getTransactionData(e);
      if (result == null) return;
      final confirmed = (result.confirmations ?? 0) > 0;
      assert(!confirmed || result.blocktime != null);
      if (confirmed && result.blocktime == null) return;
      transactions.add(BitcoinBlockTransactionInfo(
          confirmed: confirmed,
          blockTime: confirmed
              ? DateTimeUtils.detectEpochUnit(result.blocktime!)
              : null,
          txId: e));
    }));
    return transactions;
  }

  @override
  NetworkType get networkType => network.type;
}
