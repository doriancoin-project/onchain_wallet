import 'package:bitcoin_base/bitcoin_base.dart';
import 'package:blockchain_utils/blockchain_utils.dart';
import 'package:on_chain_wallet/app/error/exception/wallet_ex.dart';
import 'package:on_chain_wallet/app/serialization/serialization.dart';
import 'package:on_chain_wallet/app/utils/extensions/numbers.dart';
import 'package:on_chain_wallet/crypto/coins/custom_coins/coins.dart';
import 'package:on_chain_wallet/crypto/types/networks.dart';
import 'package:on_chain_wallet/wallet/constant/chain/const.dart';
import 'package:on_chain_wallet/wallet/constant/tags/constant.dart';
import 'package:on_chain_wallet/wallet/models/network/network.dart';
import 'package:on_chain_wallet/wallet/models/token/token/token.dart';

abstract class WalletNetwork<PARAMS extends NetworkCoinParams>
    with Equality, CborSerializable {
  const WalletNetwork();
  abstract final int value;
  abstract final PARAMS coinParam;
  abstract final NetworkType type;
  bool get isWalletNetwork => value >= 0;
  bool get isImportedNetwork => value >= ChainConst.importedNetworkStartId;
  bool get supportCustomNode;
  Token get token => coinParam.token;
  int get coinDecimal => token.decimal;
  WalletNetwork copyWith({int? value, PARAMS? coinParam});
  String get networkName => token.name;
  String get networkSymbol => token.symbol;
  List<CryptoCoins> get coins;
  bool get supportImportNetwork => false;
  bool get supportWeb3 => false;
  bool get allowSwap => false;
  String? get accountExplorer => ChainConst.getAddressExplorer(value);
  String? get txExplorer => ChainConst.getTxExplorer(value);
  Object get identifier;
  int get blockInterval => 60;

  String get caip;
  String get wsIdentifier;
  String? getAccountExplorer(String? address) {
    if (address == null) return null;
    return accountExplorer?.replaceAll(
        NetworkCoinParamsConst.addrArgs, address);
  }

  String? getTransactionExplorer(String txId) {
    return txExplorer?.replaceAll(NetworkCoinParamsConst.txIdArgs, txId);
  }

  T toNetwork<T extends WalletNetwork>() {
    if (this is! T) throw WalletExceptionConst.incorrectNetwork;
    return this as T;
  }

  static WalletNetwork fromCborBytesOrObject(
      {List<int>? bytes, CborObject? obj}) {
    final toCborTag = (obj ?? CborObject.fromCbor(bytes!)) as CborTagValue;
    final network = NetworkType.fromTag(toCborTag.tags);
    switch (network) {
      case NetworkType.bitcoinAndForked:
        return WalletBitcoinNetwork.fromCborBytesOrObject(obj: toCborTag);
      case NetworkType.bitcoinCash:
        return WalletBitcoinCashNetwork.fromCborBytesOrObject(obj: toCborTag);
      default:
        throw UnimplementedError("network does not exist.");
    }
  }

  // List<APIProvider> getAllProviders() {
  //   return [
  // ...ProvidersConst.getDefaultProvider(this),
  // ...coinParam.providers.where((element) =>
  //     element.protocol.platforms.contains(PlatformInterface.appPlatform)),
  //   ];
  // }
}

class WalletBitcoinNetwork extends WalletNetwork<BitcoinParams> {
  @override
  final int value;
  @override
  final BitcoinParams coinParam;
  @override
  bool get supportWeb3 => true;
  @override
  bool get allowSwap => true;
  @override
  String get caip => ChainConst.buildCaip2(type, genesisBlock);
  @override
  String get wsIdentifier => coinParam.transacationNetwork.identifier;
  factory WalletBitcoinNetwork.fromCborBytesOrObject(
      {List<int>? bytes, CborObject? obj}) {
    final CborListValue cbor = CborSerializable.cborTagValue(
        cborBytes: bytes, object: obj, tags: CborTagsConst.bitconNetwork);
    return WalletBitcoinNetwork(cbor.elementAs(0),
        BitcoinParams.fromCborBytesOrObject(obj: cbor.elementAsCborTag(1)));
  }

  const WalletBitcoinNetwork(this.value, this.coinParam);

  bool get isBitcoin => true;

  @override
  NetworkType get type => NetworkType.bitcoinAndForked;

  @override
  List<BipCoins> get coins => coinParam.transacationNetwork.coins;

  CryptoCoins findCoinFromBitcoinAddressType(BitcoinAddressType type) {
    if (type.isP2sh) {
      return coins
          .firstWhere((element) => element.proposal == BipProposal.bip49);
    }
    switch (type) {
      case P2pkhAddressType.p2pkh:
      case P2pkhAddressType.p2pkhwt:
      case PubKeyAddressType.p2pk:
        return coins
            .firstWhere((element) => element.proposal == BipProposal.bip44);
      case SegwitAddressType.p2wsh:
      case SegwitAddressType.p2wpkh:
        return coins
            .firstWhere((element) => element.proposal == BipProposal.bip84);
      default:
        return coins
            .firstWhere((element) => element.proposal == BipProposal.bip86);
    }
  }

  @override
  List get variabels => [value];

  @override
  CborTagValue toCbor() {
    return CborTagValue(
        CborSerializable.fromDynamic([value, coinParam.toCbor()]),
        CborTagsConst.bitconNetwork);
  }

  @override
  bool get supportCustomNode => true;

  @override
  WalletBitcoinNetwork copyWith({int? value, BitcoinParams? coinParam}) {
    return WalletBitcoinNetwork(
        value ?? this.value, coinParam ?? this.coinParam);
  }

  String get genesisBlock => ChainConst.getDefaultGenesisBlock(value);

  @override
  Object get identifier => genesisBlock;
}

class WalletBitcoinCashNetwork extends WalletBitcoinNetwork {
  @override
  String get caip => ChainConst.buildCaip2(
      type, coinParam.chainType.isMainnet ? "bitcoincash" : "bchtest");
  @override
  String get wsIdentifier => caip;
  @override
  WalletBitcoinCashNetwork copyWith({int? value, BitcoinParams? coinParam}) {
    return WalletBitcoinCashNetwork(
        value ?? this.value, coinParam ?? this.coinParam);
  }

  const WalletBitcoinCashNetwork(super.value, super.coinParam);
  @override
  bool get isBitcoin => false;

  @override
  NetworkType get type => NetworkType.bitcoinCash;

  @override
  CborTagValue toCbor() {
    return CborTagValue(
        CborSerializable.fromDynamic([value, coinParam.toCbor()]),
        CborTagsConst.bitcoinCashNetwork);
  }

  factory WalletBitcoinCashNetwork.fromCborBytesOrObject(
      {List<int>? bytes, CborObject? obj}) {
    final CborListValue cbor = CborSerializable.cborTagValue(
        cborBytes: bytes, object: obj, tags: CborTagsConst.bitcoinCashNetwork);
    return WalletBitcoinCashNetwork(
      cbor.elementAs(0),
      BitcoinParams.fromCborBytesOrObject(obj: cbor.elementAsCborTag(1)),
    );
  }
}
