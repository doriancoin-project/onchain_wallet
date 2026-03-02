import 'package:bitcoin_base/bitcoin_base.dart';
import 'package:blockchain_utils/bip/bip.dart';
import 'package:blockchain_utils/cbor/cbor.dart';
import 'package:on_chain_wallet/app/serialization/serialization.dart';
import 'package:on_chain_wallet/crypto/doriancoin/doriancoin.dart';
import 'package:on_chain_wallet/wallet/constant/tags/constant.dart';
import 'package:on_chain_wallet/wallet/models/network/core/params/params.dart';
import 'package:on_chain_wallet/wallet/models/token/token/token.dart';

class BitcoinParams extends NetworkCoinParams {
  final BasedUtxoNetwork transacationNetwork;
  bool get isBCH => transacationNetwork is BitcoinCashNetwork;
  bool get isForked => isBCH || transacationNetwork is BitcoinSVNetwork;

  factory BitcoinParams.fromCborBytesOrObject(
      {List<int>? bytes, CborObject? obj}) {
    final CborListValue values = CborSerializable.cborTagValue(
        cborBytes: bytes, object: obj, tags: CborTagsConst.bitconNetworkParam);

    return BitcoinParams(
        token: Token.deserialize(obj: values.elementAs<CborTagValue>(2)),
        transacationNetwork: BasedUtxoNetwork.fromName(values.elementAs(3)),
        addressExplorer: values.elementAs(6),
        transactionExplorer: values.elementAs(7));
  }
  BitcoinParams({
    required super.token,
    required this.transacationNetwork,
    super.addressExplorer,
    super.transactionExplorer,
  }) : super(
            chainType: transacationNetwork.isMainnet
                ? ChainType.mainnet
                : ChainType.testnet);

  @override
  CborTagValue toCbor() {
    return CborTagValue(
        CborSerializable.fromDynamic([
          const CborNullValue(),
          const CborNullValue(),
          token.toCbor(),
          transacationNetwork.value,
          CborNullValue(),
          const CborNullValue(),
          addressExplorer,
          transactionExplorer,
        ]),
        CborTagsConst.bitconNetworkParam);
  }

  @override
  NetworkCoinParams updateParams(
      {Token? token,
      String? transactionExplorer,
      String? addressExplorer,
      int? bip32CoinType}) {
    return BitcoinParams(
        token: NetworkCoinParams.validateUpdateParams(
            token: this.token, updateToken: token),
        addressExplorer: addressExplorer,
        transactionExplorer: transactionExplorer,
        transacationNetwork: transacationNetwork);
  }

  @override
  int get averageBlockTime {
    return switch (transacationNetwork) {
      BitcoinCashNetwork.mainnet ||
      BitcoinCashNetwork.testnet ||
      LitecoinNetwork.mainnet ||
      LitecoinNetwork.testnet =>
        150,
      DoriancoinNetwork.mainnet || DoriancoinNetwork.testnet => 150,
      DashNetwork.testnet => 60,
      _ => 8 * 60
    };
  }

  bool get rbfSupport {
    return switch (transacationNetwork) {
      BitcoinNetwork.mainnet ||
      BitcoinNetwork.testnet ||
      BitcoinNetwork.testnet4 ||
      LitecoinNetwork.mainnet ||
      LitecoinNetwork.testnet ||
      DoriancoinNetwork.mainnet ||
      DoriancoinNetwork.testnet =>
        true,
      _ => false
    };
  }

  int? get maxMemoLength {
    return switch (transacationNetwork) {
      BitcoinCashNetwork.mainnet || BitcoinCashNetwork.testnet => 223,
      BitcoinSVNetwork.mainnet || BitcoinSVNetwork.testnet => null,
      _ => 80
    };
  }

  bool get supportMultipleOpReturn {
    return switch (transacationNetwork) {
      BitcoinCashNetwork.mainnet ||
      BitcoinCashNetwork.testnet ||
      BitcoinSVNetwork.mainnet ||
      BitcoinSVNetwork.testnet =>
        true,
      _ => false
    };
  }

  @override
  int get maxTxConfirmationBlock => 10;
}
