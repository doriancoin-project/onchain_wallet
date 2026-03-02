import 'package:bitcoin_base/bitcoin_base.dart';
import 'package:on_chain_wallet/app/utils/datetime/datetime.dart';
import 'package:on_chain_wallet/wallet/api/client/networks/bitcoin/core/core.dart';
import 'package:on_chain_wallet/wallet/api/provider/networks/bitcoin/bitcoin.dart';
import 'package:on_chain_wallet/wallet/api/services/service.dart';
import 'package:on_chain_wallet/wallet/chain/account.dart';
import 'package:on_chain_wallet/wallet/models/network/network.dart';
import 'package:on_chain_wallet/wallet/models/transaction/core/transaction.dart';
class BitcoinExplorerApiProvider extends BitcoinClient<IBitcoinAddress> {
  BitcoinExplorerApiProvider({required this.provider, required this.network});
  @override
  final WalletBitcoinNetwork network;

  @override
  NetworkServiceProtocol<BaseBitcoinAPIProvider> get service =>
      provider.service as NetworkServiceProtocol<BaseBitcoinAPIProvider>;

  final ApiProvider provider;

  @override
  Future<BigInt> getAccountBalance(BitcoinBaseAddress address) async {
    final utxos =
        await provider.getAccountUtxo(UtxoAddressDetails.watchOnly(address));
    return utxos.sumOfUtxosValue();
  }

  @override
  Future<List<UtxoWithAddress>> readUtxos(UtxoAddressDetails address,
      [bool includeTokens = false]) async {
    assert(
        !includeTokens, "bitcoin explorer api does not support include tokens");
    final utxos = await provider.getAccountUtxo(address);
    return utxos;
  }

  @override
  Future<BitcoinFeeRate> getFeeRate() => provider.getNetworkFeeRate();

  @override
  Future<String> sendTransaction(String digest) async {
    return await provider.sendRawTransaction(digest);
  }

  @override
  Future<BtcTransaction> getTx(String txId) async {
    return await provider.getRawTransaction(txId);
  }

  @override
  Future<ElectrumVerbosTxResponse?> getTransactionData(String txId) async {
    try {
      if (provider.api.apiType == APIType.blockCypher) {
        final tx = await provider.getTransaction<BlockCypherTransaction>(txId);
        return ElectrumVerbosTxResponse(
            txId: txId,
            version: tx.ver,
            size: tx.size,
            vsize: tx.vSize,
            weight: tx.size,
            locktime: 0,
            blockhash: tx.hash,
            blocktime: tx.received == null
                ? null
                : DateTimeUtils.secondsSinceEpoch(tx.received!),
            confirmations: tx.confirmations);
      }

      final tx = await provider.getTransaction<MempoolTransaction>(txId);
      return ElectrumVerbosTxResponse(
          txId: txId,
          version: tx.version,
          size: tx.size,
          vsize: tx.size,
          weight: tx.weight,
          locktime: tx.locktime,
          blockhash: tx.status.blockHash,
          blocktime: tx.status.blockTime,
          confirmations: tx.status.confirmed ? 1 : null);
    } catch (_) {
      return null;
    }
  }

  @override
  Future<String> genesisHash() async {
    return await provider.genesis();
  }

  @override
  Future<BigInt> getBalance(BitcoinBaseAddress address) async {
    final utxos =
        await provider.getAccountUtxo(UtxoAddressDetails.watchOnly(address));
    return utxos.sumOfUtxosValue();
  }

  @override
  Future<WalletTransactionStatus> transactionStatus(
      {required String txId}) async {
    if (provider.api.apiType == APIType.mempool) {
      final tx = await provider.getTransaction<MempoolTransaction>(txId);
      if (tx.status.confirmed) {
        return WalletTransactionStatus.block;
      }
      return WalletTransactionStatus.pending;
    }
    final tx = await provider.getTransaction<BlockCypherTransaction>(txId);
    if (tx.doubleSpend) {
      return WalletTransactionStatus.failed;
    }
    if (tx.confirmations > 0) {
      return WalletTransactionStatus.block;
    }
    return WalletTransactionStatus.pending;
  }

  @override
  Future<BigInt?> getBlockHeight() async {
    return provider.getLatestBlockHeight();
  }

  @override
  BitcoinClient<IBitcoinAddress> clone() {
    return BitcoinExplorerApiProvider(provider: provider, network: network);
  }
}
