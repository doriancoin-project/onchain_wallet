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
    0: <APIProvider>[
      BitcoinExplorerAPIProviderConst.mempool,
      BitcoinExplorerAPIProviderConst.blockCypher,
      ElectrumAPIProvider(
          identifier: "${defaultidentifierName}0",
          url: "142.93.6.38:50002",
          protocol: ServiceProtocol.ssl),
      ElectrumAPIProvider(
          identifier: "${defaultidentifierName}1",
          url: "wss://bitcoin.aranguren.org:50004",
          protocol: ServiceProtocol.websocket),
      ElectrumAPIProvider(
          identifier: "${defaultidentifierName}3",
          url: "104.248.139.211:50002",
          protocol: ServiceProtocol.ssl),
    ],
    1: <APIProvider>[
      ElectrumAPIProvider(
          identifier: "${defaultidentifierName}4",
          url: "wss://testnet.aranguren.org:51004",
          protocol: ServiceProtocol.websocket),
      ElectrumAPIProvider(
          identifier: "${defaultidentifierName}5",
          url: "testnet.aranguren.org:51002",
          protocol: ServiceProtocol.ssl),
      ElectrumAPIProvider(
          identifier: "${defaultidentifierName}6",
          url: "blockstream.info:700",
          protocol: ServiceProtocol.ssl),
      BitcoinExplorerAPIProviderConst.mempool,
    ],
    5: <APIProvider>[
      ElectrumAPIProvider(
          identifier: "${defaultidentifierName}tbtc4",
          url: "testnet4-electrumx.wakiyamap.dev:51002",
          protocol: ServiceProtocol.ssl),
      ElectrumAPIProvider(
          identifier: "${defaultidentifierName}tbtc4_1",
          url: "testnet4-electrumx.wakiyamap.dev:51001",
          protocol: ServiceProtocol.tcp),
      ElectrumAPIProvider(
          identifier: "${defaultidentifierName}tbtc4_2",
          url: "wss://blackie.c3-soft.com:57012",
          protocol: ServiceProtocol.websocket),
    ],
    2: <APIProvider>[
      BitcoinExplorerAPIProviderConst.blockCypher,
      ElectrumAPIProvider(
          identifier: "${defaultidentifierName}7",
          url: "wss://electrum.qortal.link:50004",
          protocol: ServiceProtocol.websocket),
      ElectrumAPIProvider(
          identifier: "${defaultidentifierName}8",
          url: "wss://46.101.3.154:50004",
          protocol: ServiceProtocol.websocket),
      ElectrumAPIProvider(
          identifier: "${defaultidentifierName}9",
          url: "46.101.3.154:50002",
          protocol: ServiceProtocol.ssl),
      ElectrumAPIProvider(
          identifier: "${defaultidentifierName}10",
          url: "backup.electrum-ltc.org:443",
          protocol: ServiceProtocol.ssl),
    ],
    7: <APIProvider>[
      ElectrumAPIProvider(
          identifier: "${defaultidentifierName}11",
          url: "electrum-ltc.bysh.me:51002",
          protocol: ServiceProtocol.ssl),
      ElectrumAPIProvider(
          identifier: "${defaultidentifierName}12",
          url: "electrum.ltc.xurious.com:51002",
          protocol: ServiceProtocol.ssl),
    ],
    3: <APIProvider>[
      ElectrumAPIProvider(
          identifier: "${defaultidentifierName}13",
          url: "electrum.qortal.link:54002",
          protocol: ServiceProtocol.ssl),
      ElectrumAPIProvider(
          identifier: "${defaultidentifierName}14",
          url: "wss://electrum.qortal.link:54004",
          protocol: ServiceProtocol.websocket),
      BitcoinExplorerAPIProviderConst.blockCypher
    ],
    8: <APIProvider>[],
    9: <APIProvider>[
      ElectrumAPIProvider(
          identifier: "${defaultidentifierName}15",
          url: "electrumx.bitcoinsv.io:50002",
          protocol: ServiceProtocol.ssl),
    ],
    4: <APIProvider>[
      BitcoinExplorerAPIProviderConst.blockCypher,
    ],
    10: <APIProvider>[
      ElectrumAPIProvider(
          identifier: "${defaultidentifierName}16",
          url: "wss://electrum.imaginary.cash:50004",
          protocol: ServiceProtocol.websocket),
      ElectrumAPIProvider(
          identifier: "${defaultidentifierName}17",
          url: "electrum.imaginary.cash:50002",
          protocol: ServiceProtocol.ssl),

      ///
      ElectrumAPIProvider(
          identifier: "${defaultidentifierName}18",
          url: "wss://bch.loping.net:50004",
          protocol: ServiceProtocol.websocket),
      ElectrumAPIProvider(
          identifier: "${defaultidentifierName}19",
          url: "bch.loping.net:50002",
          protocol: ServiceProtocol.ssl),
    ],
    11: <APIProvider>[
      ElectrumAPIProvider(
          identifier: "${defaultidentifierName}0",
          url: "ws://cbch.loping.net:62103",
          protocol: ServiceProtocol.websocket),
      ElectrumAPIProvider(
          identifier: "${defaultidentifierName}1",
          url: "ws://cbch.loping.net:62104",
          protocol: ServiceProtocol.websocket),
      ElectrumAPIProvider(
          identifier: "${defaultidentifierName}3",
          url: "cbch.loping.net:62102",
          protocol: ServiceProtocol.ssl),
      ElectrumAPIProvider(
          identifier: "${defaultidentifierName}21",
          url: "chipnet.imaginary.cash:50002",
          protocol: ServiceProtocol.ssl)
    ],
    12: <APIProvider>[
      ElectrumAPIProvider(
          identifier: "${defaultidentifierName}22",
          url: "electrum.pepeblocks.com:50002",
          protocol: ServiceProtocol.ssl),
      ElectrumAPIProvider(
          identifier: "${defaultidentifierName}24",
          url: "electrum.pepeblocks.com:50001",
          protocol: ServiceProtocol.tcp),
      ElectrumAPIProvider(
          identifier: "${defaultidentifierName}24",
          url: "wss://electrum.pepeblocks.com:50004",
          protocol: ServiceProtocol.websocket),
      ElectrumAPIProvider(
          identifier: "${defaultidentifierName}25",
          url: "electrum.pepelum.site:50002",
          protocol: ServiceProtocol.ssl),
      ElectrumAPIProvider(
          identifier: "${defaultidentifierName}26",
          url: "electrum.pepelum.site:50001",
          protocol: ServiceProtocol.tcp),
      ElectrumAPIProvider(
          identifier: "${defaultidentifierName}27",
          url: "wss://electrum.pepelum.site:50004",
          protocol: ServiceProtocol.websocket),
      ElectrumAPIProvider(
          identifier: "${defaultidentifierName}25",
          url: "electrum.pepe.tips:50002",
          protocol: ServiceProtocol.ssl),
      ElectrumAPIProvider(
          identifier: "${defaultidentifierName}26",
          url: "electrum.pepe.tips:50001",
          protocol: ServiceProtocol.tcp),
      ElectrumAPIProvider(
          identifier: "${defaultidentifierName}27",
          url: "wss://electrum.pepe.tips:50004",
          protocol: ServiceProtocol.websocket)
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
