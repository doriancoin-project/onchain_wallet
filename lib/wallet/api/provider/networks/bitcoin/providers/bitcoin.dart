import 'package:bitcoin_base/bitcoin_base.dart'
    show APIConfig, APIType, BasedUtxoNetwork;
import 'package:blockchain_utils/cbor/core/cbor.dart';
import 'package:blockchain_utils/cbor/types/cbor_tag.dart';
import 'package:blockchain_utils/cbor/types/list.dart';
import 'package:on_chain_wallet/app/http/models/auth.dart';
import 'package:on_chain_wallet/app/serialization/serialization.dart';
import 'package:on_chain_wallet/app/utils/string/utils.dart';
import 'package:on_chain_wallet/wallet/api/provider/models/bitcoin_explorer_provider_type.dart';
import 'package:on_chain_wallet/wallet/api/services/service.dart';
import 'package:on_chain_wallet/wallet/constant/tags/constant.dart';

import 'provider.dart';

class _BitcoinExplorerAPIProviderUtils {
  static APIConfig getDefaultConfig(BasedUtxoNetwork network, APIType type) {
    if (type == APIType.mempool) return APIConfig.mempool(network);
    return APIConfig.fromBlockCypher(network);
  }

  static APIConfig createConfig(
      {required BasedUtxoNetwork network, required APIType type, String? url}) {
    if (url == null) {
      return getDefaultConfig(network, type);
    }
    final String baseUrl = StrUtils.removeLastSlash(url);
    if (type == APIType.mempool) {
      return APIConfig(
          url: "$baseUrl/address/###/utxo",
          feeRate: "$baseUrl/v1/fees/recommended",
          transaction: "$baseUrl/tx/###",
          rawTransaction: "$baseUrl/tx/###/hex",
          sendTransaction: "$baseUrl/tx",
          apiType: APIType.mempool,
          transactions: "$baseUrl/address/###/txs",
          network: network,
          blockHeight: "$baseUrl/block-height/###",
          latestBlockHeight: "$baseUrl/blocks/tip/height");
    }
    return APIConfig(
        url:
            "$baseUrl/addrs/###/?unspentOnly=true&includeScript=true&limit=2000",
        feeRate: baseUrl,
        transaction: "$baseUrl/txs/###",
        rawTransaction: "$baseUrl/txs/###",
        sendTransaction: "$baseUrl/txs/push",
        apiType: APIType.blockCypher,
        transactions: "$baseUrl/addrs/###/full?limit=200",
        network: network,
        blockHeight: "$baseUrl/blocks/###",
        latestBlockHeight: "$baseUrl/");
  }
}

class BitcoinExplorerAPIProviderConst {
  static const mempool = BitcoinExplorerAPIProvider._(
      explorerType: BitcoinExplorerProviderType.mempool,
      identifier: "default-mempool");
  static const blockCypher = BitcoinExplorerAPIProvider._(
      explorerType: BitcoinExplorerProviderType.blockcypher,
      identifier: "default-blockCyper");
}

class BitcoinExplorerAPIProvider extends BaseBitcoinAPIProvider {
  const BitcoinExplorerAPIProvider._({
    super.auth,
    required super.identifier,
    required this.explorerType,
  }) : super(protocol: ServiceProtocol.http);
  factory BitcoinExplorerAPIProvider(
      {required String serviceName,
      required String websiteUri,
      required String uri,
      required BitcoinExplorerProviderType type,
      ProviderAuthenticated? auth,
      required String identifier}) {
    return BitcoinExplorerAPIProvider._(
        auth: auth, explorerType: type, identifier: identifier);
  }

  final BitcoinExplorerProviderType explorerType;

  APIConfig config(BasedUtxoNetwork network) =>
      _BitcoinExplorerAPIProviderUtils.createConfig(
          network: network, type: explorerType.type, url: explorerType.url);

  @override
  String get callUrl => explorerType.url;

  factory BitcoinExplorerAPIProvider.fromCborBytesOrObject(
      {List<int>? bytes, CborObject? obj}) {
    final CborListValue values = CborSerializable.cborTagValue(
        cborBytes: bytes,
        object: obj,
        tags: CborTagsConst.bitcoinExplorerApiProvider);
    return BitcoinExplorerAPIProvider._(
      explorerType: BitcoinExplorerProviderType.fromName(values.elementAs(0)),
      auth: values.elemetMybeAs<ProviderAuthenticated, CborTagValue>(
          1, (e) => ProviderAuthenticated.deserialize(obj: e)),
      identifier: values.elementAs(2),
    );
  }

  @override
  CborTagValue toCbor() {
    return CborTagValue(
        CborSerializable.fromDynamic(
            [explorerType.name, auth?.toCbor(), identifier]),
        CborTagsConst.bitcoinExplorerApiProvider);
  }

  @override
  List get variabels => [protocol, explorerType];

  @override
  BitcoinAPIProviderType get type => BitcoinAPIProviderType.explorer;
}
