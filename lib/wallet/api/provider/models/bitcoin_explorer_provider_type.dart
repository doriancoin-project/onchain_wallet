import 'package:on_chain_wallet/app/error/exception/app_exception.dart';
import 'package:bitcoin_base/bitcoin_base.dart' show APIType;

enum BitcoinExplorerProviderType {
  blockcypher("https://api.blockcypher.com"),
  mempool("https://blocks.doriancoin.com/api");

  final String url;
  const BitcoinExplorerProviderType(this.url);
  static BitcoinExplorerProviderType fromName(String? name) {
    return values.firstWhere((element) => element.name == name,
        orElse: () => throw AppSerializationException(
            objectName: "BitcoinExplorerProviderType"));
  }

  APIType get type {
    if (this == blockcypher) return APIType.blockCypher;
    return APIType.mempool;
  }

  bool get isBlockCypher => this == BitcoinExplorerProviderType.blockcypher;
}
