part of 'package:on_chain_wallet/wallet/provider/wallet_provider.dart';

abstract class _WalletController with CryptoWokerImpl {
  _WalletController(this._walletCore, this._appChains);

  /// base wallet
  WalletCore? _walletCore;
  WalletCore get _core {
    if (_walletCore == null) {
      throw WalletExceptionConst.walletIsNotavailable;
    }
    return _walletCore!;
  }

  // /// wallet encryption data
  EncryptedMasterKey? _walletKey;

  bool get hasWalletKey => _walletKey != null;

  /// wallet information like name, settings and etc.
  MainWallet get _wallet => _appChains.wallet;

  /// wallet networks controller.
  final ChainsHandler _appChains;

  /// current wallet account
  Chain get _chain => _appChains.chain;

  /// current wallet network
  WalletNetwork get network => _chain.network;

  /// update wallet storage.
  Future<void> _updateWallet(MainWallet wallet) async {
    await _core._updateWallet(wallet);
    _appChains.updateWalletData(wallet);
  }
}

class WalletController extends _WalletController
    with WalletManager, Web3Impl {
  WalletController._(WalletCore super.core, super.chains);

  /// setup wallet.
  static Future<WalletController> _setup(
      WalletCore core, MainWallet wallet, WalletRestoreV2? backup) async {
    try {
      final handler = await () async {
        if (backup != null) {
          return await ChainsHandler.fromBackup(backup: backup, wallet: wallet);
        } else {
          final List<Chain> chains = [];
          final values = await core._readAccounts(wallet);
          for (final i in values) {
            try {
              final chain = Chain.deserialize(bytes: i);
              chains.add(chain);
            } catch (e, s) {
              appLogger.error(
                  runtime: "WalletController",
                  functionName: "_setup",
                  msg: e,
                  trace: s);
              // rethrow;
            }
          }
          return ChainsHandler.setup(chains: chains, wallet: wallet);
        }
      }();
      final controller = WalletController._(core, handler);
      await controller._onInitController();
      return controller;
    } catch (e, s) {
      appLogger.error(
          runtime: "WalletController",
          functionName: "_setup",
          msg: e,
          trace: s);
      rethrow;
    }
  }

  /// dispose wallet.
  @override
  void _dispose() {
    _walletCore = null;
    _walletKey = null;
    _chain.dispose();
    super._dispose();
  }
}
