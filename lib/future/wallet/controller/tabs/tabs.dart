import 'dart:async';

import 'package:blockchain_utils/utils/atomic/atomic.dart';
import 'package:on_chain_wallet/app/core.dart';
import 'package:on_chain_wallet/future/state_managment/core/observer.dart';
import 'package:on_chain_wallet/future/state_managment/state_managment.dart';
import 'package:on_chain_wallet/future/wallet/controller/wallet/ui_wallet.dart';
import 'package:on_chain_wallet/future/wallet/webview/controller/controller/controller.dart';
import 'package:on_chain_wallet/marketcap/prices/live_currency.dart';
import 'package:on_chain_wallet/wallet/api/provider/core/provider.dart';
import 'package:on_chain_wallet/wallet/chain/account.dart';
import 'package:on_chain_wallet/wallet/models/others/models/wallet.dart';

enum WalletPage {
  wallet,
  webview;

  bool get inWallet => this == wallet;
  bool get inWebview => this == webview;
  static WalletPage findCurrentPage({required int index}) {
    if (index == 0) return WalletPage.wallet;
    return WalletPage.webview;
  }
}

mixin WalletProviderTabController on StateController {
  final _lock = SafeAtomicLock();
  final LiveCurrencies currency = LiveCurrencies();
  WebViewController? _webviewController;
  APPSetting get appSetting;
  WalletRouteObserver get observer;
  bool get supportWebView;
  UIWallet get wallet;

  bool _enableWebview = false;
  bool get enableWebView => _enableWebview;
  bool _multipleTab = false;
  bool get multipleTab => _multipleTab;
  WebViewController? get webviewContoller => _webviewController;

  WalletPage _walletPage = WalletPage.wallet;
  WalletPage get walletPage => _walletPage;
  int _homepageIndex = 0;
  int get homepageIndex => _homepageIndex;

  bool _canPop = false;

  bool get canPop => _canPop;
  Timer? _popTimer;

  void resetTimer() {
    _popTimer?.cancel();
    _popTimer = null;
    _popTimer = Timer(APPConst.twoSecoundDuration, () {
      if (!_canPop) return;
      _canPop = false;
      notify();
    });
  }

  void onPop(bool canPop, Object? n) {
    if (canPop) return;
    if (_walletPage.inWebview) {
      final webview = _webviewController;
      if (webview == null || webview.onBackButton()) {
        onChangeIndex(0);
      }
    } else if (!_walletPage.inWallet) {
      onChangeIndex(0);
    } else {
      _canPop = true;
      wallet.navigatorKey.currentContext
          ?.showAlert("press_back_button_twice".tr);
      resetTimer();
      notify();
    }
  }

  void updateWalletSetting(APPWalletSetting setting);

  void toggleWebView() {
    _enableWebview = !_enableWebview;
    updateWalletSetting(
        appSetting.walletSetting.copyWith(enableWebView: _enableWebview));
    _lock.run(() async {
      if (!_enableWebview) {
        await _webviewController?.dispose();
        _webviewController = null;
      } else {
        await _initWebView();
      }
      _multipleTab = _enableWebview;
      onChangeIndex(0);
      notify();
    });
  }

  Future<bool> _initWebView() async {
    if (_webviewController == null &&
        supportWebView &&
        appSetting.walletSetting.enableWebView) {
      _webviewController =
          WebViewController(walletCore: wallet, observer: observer);
      await _webviewController?.init();
      _enableWebview = true;
      return true;
    }
    return false;
  }

  void onChangeIndex(int index) {
    if (index == homepageIndex) return;
    _canPop = false;
    _homepageIndex = index;
    _walletPage = WalletPage.findCurrentPage(index: index);
    _cancelable.cancel();
    notify();
  }

  Future<void> _initTabs() async {
    _lock.run(() async {
      final webView = await _initWebView();
      final multipleTab = _enableWebview;
      if (webView || multipleTab != this.multipleTab) {
        _multipleTab = multipleTab;
        notify();
      }
    });
  }

  Future<void> _dispose() async {
    _lock.run(() async {
      await _webviewController?.dispose();
      _webviewController = null;
      _enableWebview = false;
      _multipleTab = _enableWebview;
      notify();
    });
  }

  Future<void> onWalletEvent(WalletActionEvent event) async {
    switch (event.walletStatus) {
      case WStatus.lock:
        await _dispose();
        onChangeIndex(0);
        break;
      case WStatus.unlock:
      case WStatus.readOnly:
        _initTabs();
        break;
      default:
    }
    await _webviewController?.onWalletEvent(event);
  }

  final Cancelable _cancelable = Cancelable();

  bool get allowRefresh =>
      (walletPage.inWallet && wallet.isOpen) ||
      (walletPage.inWebview && (webviewContoller?.page.inBrowser ?? false));

  Future<void> _onRefresh() async {
    _cancelable.dispose();
    await MethodUtils.call(() async {
      switch (walletPage) {
        case WalletPage.wallet:
          if (!wallet.isOpen) return;
          return await wallet.updateBalance();
        case WalletPage.webview:
          return await webviewContoller?.reload();
        default:
      }
    }, cancelable: _cancelable);
  }

  Future<void> onRefresh() async {
    await _onRefresh();
  }

  Future<void> setAccountProvider(
      {required ProviderIdentifier? provider, required Chain account}) async {
    if (provider == null) return;
    _cancelable.cancel();
    await account.setProvider(provider);
  }
}
