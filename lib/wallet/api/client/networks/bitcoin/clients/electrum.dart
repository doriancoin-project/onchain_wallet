import 'dart:async';

import 'package:bitcoin_base/bitcoin_base.dart';
import 'package:blockchain_utils/blockchain_utils.dart';
import 'package:on_chain_wallet/app/core.dart';
import 'package:on_chain_wallet/wallet/api/client/networks/bitcoin/core/core.dart';
import 'package:on_chain_wallet/wallet/api/provider/networks/bitcoin/bitcoin.dart';
import 'package:on_chain_wallet/wallet/api/services/service.dart';
import 'package:on_chain_wallet/wallet/chain/account.dart';
import 'package:on_chain_wallet/wallet/models/network/network.dart';
import 'package:on_chain_wallet/wallet/models/transaction/transaction.dart';
class BitcoinElectrumClient extends BitcoinClient<IBitcoinAddress> {
  BitcoinElectrumClient({required this.provider, required this.network});
  @override
  final WalletBitcoinNetwork network;

  @override
  NetworkServiceProtocol<ElectrumAPIProvider> get service =>
      provider.rpc as NetworkServiceProtocol<ElectrumAPIProvider>;

  final ElectrumProvider provider;

  @override
  Future<List<UtxoWithAddress>> readUtxos(UtxoAddressDetails address,
      [bool includeTokens = false]) async {
    final utxos = await provider.request(ElectrumRequestScriptHashListUnspent(
        scriptHash: address.address.pubKeyHash(),
        includeTokens: includeTokens));
    return utxos
        .where((element) => (!includeTokens) ? element.token == null : true)
        .map((e) {
      final utxo = UtxoWithAddress(
          utxo: e.toUtxo(address.address.type), ownerDetails: address);
      return utxo;
    }).toList();
  }

  @override
  Future<BitcoinFeeRate?> getFeeRate() async {
    final BigInt? high =
        await provider.request(ElectrumRequestEstimateFee(numberOfBlock: 2));
    if (high == null) {
      return null;
    }
    final BigInt? medium =
        await provider.request(ElectrumRequestEstimateFee(numberOfBlock: 5));
    final BigInt? low =
        await provider.request(ElectrumRequestEstimateFee(numberOfBlock: 10));
    return BitcoinFeeRate(high: high, low: low ?? high, medium: medium ?? high);
  }

  @override
  Future<String> sendTransaction(String digest) async {
    return await provider
        .request(ElectrumRequestBroadCastTransaction(transactionRaw: digest));
  }

  @override
  Future<String> genesisHash() async {
    final header = await provider
        .request(ElectrumRequestBlockHeader(startHeight: 0, cpHeight: 0));
    return BytesUtils.toHexString(
        QuickCrypto.sha256DoubleHash(BytesUtils.fromHexString(header))
            .reversed
            .toList());
  }

  @override
  Future<BtcTransaction> getTx(String txId) async {
    return await provider.request(ElectrumRequestGetRawTransaction(txId));
  }

  Future<ElectrumHeaderSubscribeResponse> getBlock() async {
    return await provider.request(ElectrumRequestHeaderSubscribe());
  }

  @override
  Future<WalletTransactionStatus> transactionStatus(
      {required String txId}) async {
    try {
      final r =
          await provider.request(ElectrumRequestGetVerboseTransaction(txId));
      if (r.confirmations == null) {
        return WalletTransactionStatus.pending;
      }
      return WalletTransactionStatus.block;
    } catch (_) {
      return WalletTransactionStatus.unknown;
    }
  }

  @override
  Future<BigInt> getBalance(BitcoinBaseAddress address) async {
    return getAccountBalance(address);
  }

  @override
  Future<BigInt?> getBlockHeight() async {
    final block = await getBlock();
    return BigInt.from(block.block);
  }

  @override
  BitcoinClient<IBitcoinAddress> clone() {
    return BitcoinElectrumClient(provider: provider, network: network);
  }

  @override
  Future<BigInt> getAccountBalance(BitcoinBaseAddress address) async {
    final utxos = await readUtxos(
        UtxoAddressDetails.watchOnly(address), network.coinParam.isBCH);
    return utxos.sumOfUtxosValue();
  }

  @override
  Future<ElectrumVerbosTxResponse?> getTransactionData(String txId) async {
    try {
      final r =
          await provider.request(ElectrumRequestGetVerboseTransaction(txId));
      return r;
    } catch (_) {
      return null;
    }
  }
}
