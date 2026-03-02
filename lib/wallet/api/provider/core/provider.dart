import 'package:blockchain_utils/blockchain_utils.dart';
import 'package:on_chain_wallet/app/error/exception/wallet_ex.dart';
import 'package:on_chain_wallet/app/http/models/auth.dart';
import 'package:on_chain_wallet/app/serialization/cbor/cbor.dart';
import 'package:on_chain_wallet/crypto/types/networks.dart';
import 'package:on_chain_wallet/wallet/api/constant/constant.dart';
import 'package:on_chain_wallet/wallet/api/provider/networks/bitcoin/providers/provider.dart';
import 'package:on_chain_wallet/wallet/api/services/models/models.dart';
import 'package:on_chain_wallet/wallet/models/network/network.dart';

abstract class APIProvider with Equality, CborSerializable {
  const APIProvider(
      {required this.protocol,
      this.auth,
      required this.identifier,
      this.allowInWeb3 = true});
  final String identifier;
  final ServiceProtocol protocol;
  final ProviderAuthenticated? auth;
  final bool allowInWeb3;
  bool get isDefaultProvider =>
      identifier.startsWith(ProvidersConst.defaultidentifierName);

  T cast<T extends APIProvider>() {
    if (this is! T) {
      throw AppExceptionConst.internalError("APIProvider.toProvider");
    }
    return this as T;
  }

  @override
  List get variabels => [callUrl, protocol, auth];

  String get callUrl;

  factory APIProvider.deserialize(WalletNetwork network,
      {List<int>? bytes, CborObject? obj}) {
    switch (network.type) {
      case NetworkType.bitcoinAndForked:
      case NetworkType.bitcoinCash:
        return BaseBitcoinAPIProvider.fromCborBytesOrObject(
            obj: obj, bytes: bytes);
      default:
        throw AppExceptionConst.internalError(
            "APIProvider.fromCborBytesOrObject");
    }
  }
}

abstract class ProviderIdentifier with Equality, CborSerializable {
  final NetworkType network;
  const ProviderIdentifier({required this.network});
  factory ProviderIdentifier.deserialize(
      {List<int>? bytes, String? hex, CborObject? cbor}) {
    final CborTagValue tag =
        CborSerializable.decode(cborBytes: bytes, hex: hex, object: cbor);
    final network = NetworkType.fromTag(tag.tags);
    return DefaultProviderIdentifier.deserialize(cbor: tag);
  }
  T cast<T extends ProviderIdentifier>() {
    if (this is! T) {
      throw AppExceptionConst.internalError("ProviderIdentifier");
    }
    return this as T;
  }
}

class DefaultProviderIdentifier extends ProviderIdentifier {
  final String identifier;
  const DefaultProviderIdentifier._({
    required this.identifier,
    required super.network,
  });
  factory DefaultProviderIdentifier({
    required String identifier,
    required NetworkType network,
  }) {
    return DefaultProviderIdentifier._(
        network: network, identifier: identifier);
  }
  factory DefaultProviderIdentifier.deserialize(
      {List<int>? bytes, String? hex, CborObject? cbor}) {
    final CborTagValue tag =
        CborSerializable.decode(cborBytes: bytes, hex: hex, object: cbor);
    final network = NetworkType.fromTag(tag.tags);
    final values = tag.valueAs<CborListValue>();
    return DefaultProviderIdentifier(
        identifier: values.elementAs(0), network: network);
  }

  @override
  CborTagValue toCbor() {
    return CborTagValue(
        CborSerializable.fromDynamic([identifier]), network.tag);
  }

  @override
  List get variabels => [identifier];
}
