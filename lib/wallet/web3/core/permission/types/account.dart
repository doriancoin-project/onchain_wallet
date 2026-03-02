import 'package:blockchain_utils/cbor/cbor.dart';
import 'package:blockchain_utils/helper/extensions/extensions.dart';
import 'package:blockchain_utils/utils/equatable/equatable.dart';
import 'package:on_chain_wallet/app/core.dart';
import 'package:on_chain_wallet/crypto/keys/access/crypto_keys/crypto_keys.dart';
import 'package:on_chain_wallet/crypto/types/networks.dart';
import 'package:on_chain_wallet/wallet/wallet.dart';
import 'package:on_chain_wallet/wallet/web3/constant/constant/exception.dart';
import 'package:on_chain_wallet/wallet/web3/networks/bitcoin/bitcoin.dart';
import 'package:on_chain_wallet/wallet/web3/networks/bitcoin_cash/permission/models/account.dart';

abstract class Web3ChainAccount<NETWORKADDRESS>
    with CborSerializable, Equality {
  int get id;
  final AddressDerivationIndex keyIndex;
  final NETWORKADDRESS address;
  final String identifier;
  final bool defaultAddress;
  String get addressStr;

  Web3ChainAccount({
    required this.keyIndex,
    required this.address,
    required this.identifier,
    required this.defaultAddress,
  });

  Web3ChainAccount<NETWORKADDRESS> clone();

  @override
  List get variabels => [keyIndex, addressStr, id, defaultAddress];
}

abstract class Web3ChainIdnetifier with CborSerializable, Equality {
  final int id;
  final String wsIdentifier;
  final String caip2;
  final String caipChainId;
  final String wsChainId;

  bool isChain(String chainId) {
    if (chainId.indexOf(":") > 0) {
      return wsIdentifier == chainId || caip2 == chainId;
    }
    return caipChainId == chainId || wsChainId == chainId;
  }

  Web3ChainIdnetifier(
      {required this.id, required this.wsIdentifier, required this.caip2})
      : caipChainId = caip2.split(":").last,
        wsChainId = wsIdentifier.split(":").last;
  @override
  List get variabels => [id];
}

class Web3ChainDefaultIdnetifier extends Web3ChainIdnetifier {
  Web3ChainDefaultIdnetifier(
      {required super.id, required super.wsIdentifier, required super.caip2});
  factory Web3ChainDefaultIdnetifier.deserialize(
      {List<int>? bytes, CborObject? object, String? hex}) {
    final CborListValue values = CborSerializable.cborTagValue(
        cborBytes: bytes,
        object: object,
        hex: hex,
        tags: CborTagsConst.web3ChainIdentifier);
    return Web3ChainDefaultIdnetifier(
        id: values.elementAs(0),
        wsIdentifier: values.elementAs(1),
        caip2: values.elementAs(2));
  }

  @override
  CborTagValue toCbor() {
    return CborTagValue(CborSerializable.fromDynamic([id, wsIdentifier, caip2]),
        CborTagsConst.web3ChainIdentifier);
  }
}

abstract class Web3ChainAuthenticated<CHAINACCOUNT extends Web3ChainAccount>
    with CborSerializable {
  final NetworkType networkType;
  final List<CHAINACCOUNT> accounts;
  abstract final List<Web3ChainIdnetifier> networks;
  abstract final Web3ChainIdnetifier currentNetwork;

  Web3ChainAuthenticated({
    required this.networkType,
    required List<CHAINACCOUNT> accounts,
  }) : accounts = accounts.immutable;
  factory Web3ChainAuthenticated.deserialize(
      {List<int>? bytes, CborObject? object, String? hex}) {
    final CborTagValue tag =
        CborSerializable.decode(object: object, cborBytes: bytes, hex: hex);
    final type = NetworkType.fromTag(tag.tags);
    return switch (type) {
      NetworkType.bitcoinAndForked =>
        Web3BitcoinChainAuthenticated.deserialize(object: tag),
      NetworkType.bitcoinCash =>
        Web3BitcoinCashChainAuthenticated.deserialize(object: tag),
      _ => throw Web3RequestExceptionConst.networkDoesNotExists
    } as Web3ChainAuthenticated<CHAINACCOUNT>;
  }

  T cast<T extends Web3ChainAuthenticated>() {
    if (this is! T) {
      throw WalletExceptionConst.internalError("Web3ChainAuthenticated");
    }
    return this as T;
  }

  @override
  CborTagValue toCbor() {
    return CborTagValue(
        CborSerializable.fromDynamic([
          CborSerializable.fromDynamic(
              accounts.map((e) => e.toCbor()).toList()),
          CborSerializable.fromDynamic(
              networks.map((e) => e.toCbor()).toList()),
          currentNetwork.toCbor(),
        ]),
        networkType.tag);
  }
}
