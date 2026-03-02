part of 'package:on_chain_wallet/wallet/chain/chain/chain.dart';

enum ChainsHandlerInstance { main, background }

const instance = ChainsHandlerInstance.background;

class ChainsHandler {
  MainWallet _wallet;
  MainWallet get wallet => _wallet;
  StreamSubscription<bool>? _networkStream;
  StreamSubscription<dynamic>? _ping;
  final Map<NetworkType, NetworkController> _networks;
  Chain _chain;
  String get id => _wallet.key;
  WalletNetwork get network => _chain.network;
  Chain get chain => _chain;
  ChainsHandler._(
      {required List<NetworkController> networks,
      required int network,
      required MainWallet wallet,
      required Chain chain})
      : _networks = {for (final i in networks) i.type: i},
        _wallet = wallet,
        _chain = chain;

  static Future<ChainsHandler> setup(
      {required List<Chain> chains,
      required MainWallet wallet,
      bool isBackup = false}) async {
    for (final i in chains) {
      if (i.id != wallet.key) {
        throw WalletExceptionConst.incorrectWalletData;
      }
    }
    final Map<int, Chain> toMap = {for (final i in chains) i.network.value: i};
    List<Chain> newChains = [];
    for (final i in ChainConst.defaultCoins.keys) {
      if (toMap.containsKey(i)) {
        continue;
      }
      final network = ChainConst.defaultCoins[i]!;
      final chain = Chain.setup(network: network, id: wallet.key);
      newChains.add(chain);
      toMap.addAll({chain.network.value: chain});
    }
    if (isBackup) {
      await Future.wait(toMap.values.map((e) => e._saveAccountInternal()));
    } else {
      await Future.wait(newChains.map((e) => e._saveAccountInternal()));
    }

    int currentNetwork = wallet.network;
    if (!toMap.containsKey(wallet.network)) {
      currentNetwork = 0;
    }
    final List<Chain> n = toMap.values.toList();
    return ChainsHandler._(
        networks: List.generate(NetworkType.values.length, (i) {
          final networkType = NetworkType.values[i];
          final chains = n.where((e) => e.network.type == networkType).toList();
          switch (networkType) {
            case NetworkType.bitcoinAndForked:
              return BitcoinNetworkController(
                  networks: chains.cast(), id: wallet.key);
            case NetworkType.bitcoinCash:
              return BitcoinCashNetworkController(
                  networks: chains.cast(), id: wallet.key);
            default:
              throw WalletExceptionConst.networkDoesNotExist;
          }
        }),
        network: currentNetwork,
        wallet: wallet,
        chain: toMap[currentNetwork]!);
  }

  static Future<ChainsHandler> fromBackup(
      {required WalletRestoreV2 backup, required MainWallet wallet}) async {
    final chains = backup.networks.map((e) => e.chain).toList();

    final handler = await setup(chains: chains, wallet: wallet, isBackup: true);
    await handler.restoreBackup(backup);
    return handler;
  }

  void updateWalletData(MainWallet wallet) {
    if (_wallet.key != wallet.key) {
      throw WalletExceptionConst.walletDoesNotExists;
    }
    _wallet = wallet;
  }

  List<String> coinIds() {
    return _networks.values.expand((e) => e.coinIds()).toSet().toList();
  }

  List<Chain> chains() {
    return _networks.values.expand((e) => e.getChains()).toList();
  }

  T controller<T extends NetworkController>(NetworkType type) {
    final controller = _networks[type];
    if (controller == null) {
      throw WalletExceptionConst.internalError("ChainsHandler.controller");
    }
    return controller.cast<T>();
  }

  Future<bool> switchNetwork(Chain network) async {
    if (_chain == network ||
        !_networks[network.network.type]!
            ._networks
            .containsKey(network.network.value)) {
      return false;
    }
    final currentChain = chain;
    _chain = network;
    await currentChain.closeClient();
    await chain.init();
    final emit = ChainWalletChainChangeEvent(prv: currentChain, current: chain);
    await _emitChainChanged(emit);
    updateWalletData(_wallet.updateNetwork(network.network.value));
    return true;
  }

  Future<Chain> updateNetwork(WalletNetwork network) async {
    final controller = _networks[network.type];
    if (controller == null || !network.isWalletNetwork) {
      throw WalletExceptionConst.networkDoesNotExist;
    }
    int networkId = network.value;
    Chain? existChain = controller._networks[networkId];
    if (existChain == null) {
      throw WalletExceptionConst.invalidNetworkInformation;
    }
    existChain.dispose();
    existChain = existChain.copyWith(network: network);
    existChain = Chain.deserialize(bytes: existChain.toCbor().encode());
    controller._updateNetwork(existChain);
    if (existChain.network.value == chain.network.value) {
      _chain = existChain;
      await _chain.init();
    }
    return existChain;
  }

  Future<Chain> importNewNetwork(
      WalletNetwork network, List<APIProvider> providers) async {
    final controller = _networks[network.type];
    if (controller == null ||
        network.isWalletNetwork ||
        !network.supportImportNetwork) {
      throw WalletExceptionConst.invalidNetworkInformation;
    }
    final chains =
        controller.getChains().where((e) => e.network.type == network.type);
    if (chains.any((e) => e.network.identifier == network.identifier)) {
      throw WalletExceptionConst.networkAlreadyExist;
    }
    int networkId = network.value;
    final ids = _networks.values.expand((e) => e._networks.keys).toList();
    networkId = StrUtils.findFirstMissingNumber(ids,
        start: ChainConst.importedNetworkStartId);
    if (networkId > ChainConst.maxNetworkId) {
      throw WalletExceptionConst.toManyNetworkImported;
    }
    network = network.copyWith(value: networkId);
    if (network.value != networkId) {
      throw WalletExceptionConst.invalidNetworkInformation;
    }
    final newChain = Chain.setup(network: network, id: id);
    await newChain._removeAccount();
    await newChain._saveAccountInternal();
    await Future.wait(providers.map((e) => newChain.updateProvider(e)));
    controller._updateNetwork(newChain);
    return newChain;
  }

  Future<void> removeChain(Chain removeChain) async {
    if (removeChain.id != id) {
      throw WalletExceptionConst.internalError("removeChain");
    }
    final hasDefaultNetwork =
        ChainConst.defaultCoins[removeChain.network.value];
    if (!removeChain.network.isWalletNetwork || hasDefaultNetwork != null) {
      throw WalletExceptionConst.internalError("removeChain");
    }
    final controller = _networks[removeChain.network.type];
    if (controller == null) {
      throw WalletExceptionConst.internalError("removeChain");
    }
    if (chain == removeChain) {
      final changeNetwork =
          controller._networks.values.firstWhere((e) => e != removeChain);
      await switchNetwork(changeNetwork);
    }
    controller._removeNetwork(removeChain);
    await removeChain._removeAccount();
    removeChain.dispose();
  }

  Future<List<Web3InternalChain>> getWeb3InternalChains(
      Web3ApplicationAuthentication authenticated,
      {List<NetworkType>? networks}) {
    networks ??= NetworkType.values;
    return Future.wait(networks.map((e) =>
        _networks[e]!._getWeb3InternalChainAuthenticated(authenticated)));
  }

  Future<void> disconnectWeb3Chain(Web3ApplicationAuthentication app,
      {List<NetworkType>? networks}) async {
    networks ??= NetworkType.values;
    await Future.wait(
        networks.map((e) => _networks[e]!._disconnectWeb3Chain(app)));
  }

  Future<Web3APPData> createAuth(Web3ApplicationAuthentication app,
      {List<NetworkType>? networks}) async {
    networks ??= NetworkType.values;

    return Web3APPData(
        token: app.token,
        networks: networks,
        applicationId: app.applicationId,
        chains: app.active
            ? await Future.wait(networks
                .map((e) => _networks[e]!.createWeb3ChainAuthenticated(app)))
            : []);
  }

  Future<WalletBackup> createBackup(
      {required GenerateWalletBackupOptions options,
      required String masterKey,
      List<Web3ApplicationAuthentication> web3Applications = const []}) async {
    final networkBackups = await Future.wait(_networks.values.map((e) =>
        e._getNetworksBackup(
            options.chains.where((c) => c.network.type == e.type).toList())));
    final chainBackups = await Future.wait(_networks.values
        .map((e) => e._getChainBackup(web3Applications: web3Applications)));
    return WalletBackup(
        wallet: _wallet,
        key: masterKey,
        networks: networkBackups.expand((e) => e).toList(),
        chains: chainBackups.expand((e) => e).toList());
  }

  Future<void> restoreBackup(WalletRestoreV2 backup) async {
    await Future.wait(_networks.values.map((e) => e._restoreNetworksBackup(
        backup.networks
            .where((c) => c.chain.network.type == e.type)
            .toList())));
    await Future.wait(_networks.values.map((e) => e._restoreChainBackup(
        backup.chains.where((c) => c.chainID == e.type.id).toList())));
    final chains = this.chains();
    await Future.wait(chains.map((e) => e._saveAddresses(e.addresses)));
  }

  Future<void> updateWeb3InternalChains(
      {required Web3ApplicationAuthentication app,
      required List<Web3InternalChain> chains}) async {
    if (app.active) {
      await Future.wait(chains.map((e) =>
          _networks[e.type]!._updateWeb3InternalChain(app: app, web3Chain: e)));
    } else {
      await Future.wait(
          _networks.values.map((e) => e._disconnectWeb3Chain(app)));
    }
  }

  Future<void> _emitChainChanged(ChainWalletChainChangeEvent event) async {
    for (final i in _networks.entries) {
      for (final n in i.value._networks.values) {
        await n._onWalletEvent(event);
      }
    }
  }

  void _onConnectionStatus(bool isOnline) {
    final event = ChainWalletConnectionEvent(isOnline);
    for (final i in _networks.entries) {
      for (final n in i.value._networks.values) {
        n._onWalletEvent(event);
      }
    }
  }

  Future<void> _onPing(var _) async {
    final event = ChainWalletPingEvent();
    for (final i in _networks.entries) {
      for (final n in i.value._networks.values) {
        await n._onWalletEvent(event);
      }
    }
  }

  Future<void> init() async {
    await chain.init();
    assert(_networkStream == null && _ping == null);
    if (appLogger.mode.isDev) return;
    _networkStream =
        AppNativeMethods.platform.onNetworkStatus.listen(_onConnectionStatus);
    _ping = Stream.periodic(const Duration(minutes: 10)).listen(_onPing);
    final emit = ChainWalletChainChangeEvent(prv: null, current: chain);
    _emitChainChanged(emit);
  }

  void dispose() {
    _networkStream?.cancel();
    _ping?.cancel();
    _networkStream = null;
    _ping = null;
    for (final i in _networks.values) {
      for (final n in i._networks.values) {
        n.dispose();
      }
    }
  }
}
