import 'package:on_chain_bridge/platform_interface.dart';
import 'package:on_chain_wallet/app/error/exception/wallet_ex.dart';
import 'package:on_chain_wallet/app/http/models/auth.dart';
import 'package:on_chain_wallet/crypto/types/networks.dart';
import 'package:on_chain_wallet/wallet/api/api.dart';
import 'package:on_chain_wallet/wallet/models/network/network.dart';

class ProvidersConst {
  static List<APIProviderServiceInfo> networkSupportServices(
      WalletNetwork network) {
    return switch (network.type) {
      NetworkType.bitcoinAndForked || NetworkType.bitcoinCash => [
          APIProviderServiceInfo(name: "Electrum")
        ],
      _ => throw AppExceptionConst.internalError("ProvidersConst"),
    };
  }

  static const String defaultidentifierName = "default-";
  static final Map<int, List<APIProvider>> _providers =
      Map<int, List<APIProvider>>.unmodifiable({
    // Doriancoin Mainnet
    0: <APIProvider>[
      BitcoinExplorerAPIProviderConst.mempool,
      ElectrumAPIProvider(
          identifier: "${defaultidentifierName}0",
          url: "node1.doriancoin.com:50002",
          protocol: ServiceProtocol.ssl),
      ElectrumAPIProvider(
          identifier: "${defaultidentifierName}1",
          url: "node1.doriancoin.com:50001",
          protocol: ServiceProtocol.tcp),
      ElectrumAPIProvider(
          identifier: "${defaultidentifierName}2",
          url: "node2.doriancoin.com:50002",
          protocol: ServiceProtocol.ssl),
      ElectrumAPIProvider(
          identifier: "${defaultidentifierName}3",
          url: "node2.doriancoin.com:50001",
          protocol: ServiceProtocol.tcp),
      ElectrumAPIProvider(
          identifier: "${defaultidentifierName}4",
          url: "electrumx.doriancoin.com:50002",
          protocol: ServiceProtocol.ssl),
      ElectrumAPIProvider(
          identifier: "${defaultidentifierName}5",
          url: "electrumx.doriancoin.com:50001",
          protocol: ServiceProtocol.tcp),
    ],
    // Doriancoin Testnet
    1: <APIProvider>[
      BitcoinExplorerAPIProviderConst.mempool,
    ],
  });

  static List<T> getDefaultProvider<T extends APIProvider>(
      WalletNetwork network) {
    final providers = _providers[network.value] ?? [];
    return providers
        .whereType<T>()
        .where((element) =>
            element.protocol.platforms.contains(PlatformInterface.appPlatform))
        .toList();
  }
}
