import 'package:bitcoin_base/bitcoin_base.dart';
import 'package:on_chain_bridge/platform_interface.dart';
import 'package:on_chain_wallet/app/core.dart';
import 'package:on_chain_wallet/crypto/keys/access/crypto_keys/crypto_keys.dart';
import 'package:on_chain_wallet/crypto/types/networks.dart';
import 'package:on_chain_wallet/wallet/api/client/client.dart';
import 'package:on_chain_wallet/wallet/api/constant/constant.dart';
import 'package:on_chain_wallet/wallet/api/provider/provider.dart';
import 'package:on_chain_wallet/wallet/api/services/service.dart';
import 'package:on_chain_wallet/wallet/models/models.dart';

class APIUtils {
  static BitcoinExplorerApiProvider _buildBlockCypherOrMempolProvider({
    required WalletBitcoinNetwork network,
    required BitcoinExplorerAPIProvider provider,
    APPIsolate isolate = APPIsolate.separate,
  }) {
    final btcNetwork = network.coinParam.transacationNetwork;
    final api = ApiProvider(
        api: provider.config(btcNetwork),
        service: BitcoinHTTPService(provider: provider, isolate: isolate));
    return BitcoinExplorerApiProvider(provider: api, network: network);
  }

  static String getProviderIdentifier() {
    return CryptoKeyUtils.generateRandomString(8);
  }

  static BitcoinElectrumClient buildBitcoinElectrumProvider({
    required ElectrumAPIProvider provider,
    required WalletBitcoinNetwork network,
    APPIsolate isolate = APPIsolate.separate,
  }) {
    return BitcoinElectrumClient(
        provider: ElectrumProvider(ElectrumService.fromProvider(provider)),
        network: network);
  }

  static BitcoinClient buildBitcoinApiPorivder({
    required APIProvider provider,
    required WalletBitcoinNetwork network,
    APPIsolate isolate = APPIsolate.separate,
  }) {
    if (provider is ElectrumAPIProvider) {
      return buildBitcoinElectrumProvider(
          provider: provider, network: network, isolate: isolate);
    }
    return _buildBlockCypherOrMempolProvider(
        network: network,
        provider: provider as BitcoinExplorerAPIProvider,
        isolate: isolate);
  }

  static List<APIProvider>? _findProviders(
      {required ProviderIdentifier identifier,
      required List<APIProvider> providers,
      required NetworkType type}) {
    if (providers.isEmpty) return null;
    final defaultIdentifier = identifier.cast<DefaultProviderIdentifier>();
    final provider = providers.firstWhereOrNull(
        (e) => e.identifier == defaultIdentifier.identifier);
    if (provider == null) return null;
    return [provider];
  }

  static List<List<T>>? _getProviders<T extends APIProvider>(
      {required List<T> providers, required NetworkType type}) {
    if (providers.isEmpty) return null;
    return providers.map((e) => <T>[e]).toList();
  }

  static T? findClient<T extends NetworkClient>(
      {required WalletNetwork network,
      required List<APIProvider> providers,
      required ProviderIdentifier identifier,
      Duration? requestTimeut,
      bool allowInWeb3 = false,
      APPIsolate isolate = APPIsolate.separate}) {
    final defaultProviders = ProvidersConst.getDefaultProvider(network);
    List<APIProvider> allProviders = [...providers, ...defaultProviders]
        .where(
            (e) => e.protocol.platforms.contains(PlatformInterface.appPlatform))
        .toList();
    if (allowInWeb3) {
      allProviders = allProviders.where((e) => e.allowInWeb3).toList();
    }
    List<APIProvider>? serviceProvider = _findProviders(
        identifier: identifier, providers: allProviders, type: network.type);
    if (serviceProvider == null) return null;
    return createClient<T>(
        network: network,
        providers: serviceProvider,
        requestTimeut: requestTimeut,
        isolate: isolate);
  }

  static T createClient<T extends NetworkClient>(
      {required WalletNetwork network,
      required List<APIProvider> providers,
      Duration? requestTimeut,
      APPIsolate isolate = APPIsolate.separate}) {
    NetworkClient? client;
    switch (network.type) {
      case NetworkType.bitcoinAndForked:
      case NetworkType.bitcoinCash:
        client = buildBitcoinApiPorivder(
            provider: providers.first,
            network: network.toNetwork(),
            isolate: isolate);
        break;
      default:
        throw WalletExceptionConst.internalError("createClient");
    }

    if (client is! T) {
      throw WalletExceptionConst.internalError("createClient");
    }
    return client;
  }

  static List<T>? getClients<T extends NetworkClient>(
      {required WalletNetwork network,
      required List<APIProvider> providers,
      Duration? requestTimeut,
      bool allowInWeb3 = false,
      APPIsolate isolate = APPIsolate.separate}) {
    final defaultProviders = ProvidersConst.getDefaultProvider(network);
    List<APIProvider> allProviders = [...providers, ...defaultProviders]
        .where(
            (e) => e.protocol.platforms.contains(PlatformInterface.appPlatform))
        .toList();
    if (allowInWeb3) {
      allProviders = allProviders.where((e) => e.allowInWeb3).toList();
    }

    List<List<APIProvider>>? serviceProvider =
        _getProviders(providers: allProviders, type: network.type);
    if (serviceProvider == null) return null;
    return serviceProvider
        .map((e) => createClient<T>(
            network: network,
            providers: e,
            isolate: isolate,
            requestTimeut: requestTimeut))
        .toList();
  }

  static List<T>? findProvider<T extends APIProvider>({
    required WalletNetwork network,
    required List<T> providers,
    ProviderIdentifier? identifier,
    bool allowInWeb3 = false,
  }) {
    final defaultProviders = ProvidersConst.getDefaultProvider<T>(network);
    List<T> allProviders = [...providers, ...defaultProviders]
        .where(
            (e) => e.protocol.platforms.contains(PlatformInterface.appPlatform))
        .toList();
    if (allowInWeb3) {
      allProviders = allProviders.where((e) => e.allowInWeb3).toList();
    }

    if (identifier != null) {
      final providers = _findProviders(
          identifier: identifier, providers: allProviders, type: network.type);
      if (providers != null) return providers.cast<T>();
    }

    List<List<T>>? serviceProvider =
        _getProviders<T>(providers: allProviders, type: network.type);
    return serviceProvider?.firstOrNull;
  }

  static List<T> getAllProviders<T extends APIProvider>(
      {required WalletNetwork network,
      required List<T> providers,
      bool allowInWeb3 = false}) {
    final defaultProviders = ProvidersConst.getDefaultProvider<T>(network);
    List<T> allProviders = [...providers, ...defaultProviders]
        .where(
            (e) => e.protocol.platforms.contains(PlatformInterface.appPlatform))
        .toList();
    if (allowInWeb3) {
      allProviders = allProviders.where((e) => e.allowInWeb3).toList();
    }
    return allProviders;
  }
}
