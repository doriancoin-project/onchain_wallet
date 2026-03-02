import 'dart:async';

import 'package:blockchain_utils/blockchain_utils.dart';
import 'package:flutter/foundation.dart';
import 'package:on_chain_bridge/platform_interface.dart';
import 'package:on_chain_wallet/app/core.dart';
import 'package:on_chain_wallet/future/state_managment/core/observer.dart';
import 'package:on_chain_wallet/future/wallet/controller/wallet/ui_wallet.dart';
import 'package:on_chain_wallet/future/wallet/webview/controller/controller/tab_controller.dart';
import 'package:on_chain_wallet/future/wallet/webview/controller/controller/tab_handler.dart';
import 'package:on_chain_wallet/future/wallet/web3/controller/web3_request_controller.dart';
import 'package:on_chain_wallet/wallet/web3/web3.dart';
import 'package:on_chain_wallet/crypto/impl/worker_impl.dart';

class WebViewController
    with
        CryptoWokerImpl,
        Web3RequestControllerImpl,
        WebViewListener,
        WebViewTabImpl,
        HttpImpl {
  @override
  final WalletRouteObserver observer;
  final Cancelable _cancelable = Cancelable();
  final _lock = SafeAtomicLock();
  @override
  final UIWallet walletCore;
  WebViewController({required this.walletCore, required this.observer});
  String? _pageScript;
  String? _webviewWalletScript;
  final bool enableBackForwardKey = PlatformInterface.isMacos;

  Future<String> _loadWebViewPageScript() async {
    try {
      if (kDebugMode) {
        if (PlatformInterface.appPlatform == AppPlatform.android) {
          return (await httpGet<String>("http://10.0.2.2:3000/webview_page.js"))
              .result;
        } else {
          return (await httpGet<String>(
                  "http://localhost:3000/webview_page.js"))
              .result;
        }
      }
      _pageScript ??=
          await PlatformUtils.loadAssetText(APPConst.assetWebviewPageScript);
      return _pageScript!;
    } catch (e, s) {
      appLogger.error(
          runtime: runtimeType,
          functionName: "_loadWebViewPageScript",
          msg: e,
          trace: s);
      rethrow;
    }
  }

  Future<String> _loadWebViewScript() async {
    if (kDebugMode) {
      if (PlatformInterface.appPlatform == AppPlatform.android) {
        return (await httpGet<String>("http://10.0.2.2:3000/webview")).result;
      } else {
        return (await httpGet<String>("http://localhost:3000/webview")).result;
      }
    }
    _webviewWalletScript ??=
        await PlatformUtils.loadAssetText(APPConst.assetWebviewScript);
    return _webviewWalletScript!;
  }

  Future<T?> _loadScript<T>(
      {required String viewType, required String script}) async {
    final result =
        await webViewController.loadScript(viewType: viewType, script: script);
    if (result == null) return null;
    return StringUtils.tryToJson(result as String);
  }

  Future<void> _runPageScripts(String viewId) async {
    appLogger.debug(runtime: runtimeType, functionName: "_runPageScripts");
    final script = await _loadWebViewPageScript();
    await _loadScript(viewType: viewId, script: script);
    appLogger.debug(
        runtime: runtimeType,
        functionName: "_runPageScripts",
        msg: "_loadWebViewPageScript");
  }

  Future<bool> _postEvent(WalletEvent event, {String? viewType}) async {
    try {
      assert(tabsAuthenticated.containsKey(viewType ?? event.clientId),
          "clinet does not exists.");
      if (!tabsAuthenticated.containsKey(viewType ?? event.clientId)) {
        return false;
      }
      final result = await _loadScript<bool>(
          script:
              "onChain.onWebViewMessage(${StringUtils.fromJson(event.toJson())})",
          viewType: viewType ?? event.clientId);
      return result!;
    } catch (e) {
      return false;
    }
  }

  void updatePageScriptStatus(
      {required WalletJSScriptStatus status, required String identifier}) {
    final event = latestClient.value;
    if (event.identifier == identifier && event.web3Status.inProgress) {
      latestClient.value = LastWeb3ActiveClient(
          client: event.client,
          web3Status: status,
          url: event.url,
          identifier: identifier);
    }
  }

  void updatePageScriptClient(
      {required Web3ActiveClient client, required String identifier}) {
    final event = latestClient.value;
    if (event.identifier == identifier && event.web3Status.inProgress) {
      latestClient.value = LastWeb3ActiveClient(
          client: client,
          web3Status: WalletJSScriptStatus.progress,
          url: event.url,
          identifier: identifier);
    }
  }

  Future<bool> _scriptInitialized(String viewType) async {
    try {
      final event = WalletEvent(
              target: WalletEventTarget.wallet,
              type: WalletEventTypes.message,
              clientId: "-1")
          .toJson();
      final result = await _loadScript(
          script: "onChain.onWebViewMessage(${StringUtils.fromJson(event)})",
          viewType: viewType);
      return result != null;
    } catch (_) {
      return false;
    }
  }

  final bool isWorker = true;

  Future<void> _activeScript(WebViewEvent event) async {
    final auth = tabsAuthenticated[event.viewId];
    if (auth == null) return;
    await _runPageScripts(event.viewId);
    if (isWorker) {
      final script = await _loadWebViewScript();
      final responseEvent = toResponseEvent(
          id: auth.viewId,
          type: WalletEventTypes.activation,
          additional: script,
          platform: PlatformInterface.appPlatform.name);
      await _postEvent(responseEvent, viewType: event.viewId);
    }
  }

  Future<void> _activeClient(
      {required String viewId,
      required WalletEvent event,
      Web3ClientInfo? client}) async {
    final authenticated = await createPageAuthenticated(
        peerKey: event.clientId, info: client, identifier: viewId);
    final activeClient = authenticated.client;
    if (activeClient != null) {
      updatePageScriptClient(client: activeClient, identifier: viewId);
    }
    final result = await _postEvent(authenticated.event, viewType: viewId);
    if (!result) {
      updatePageScriptStatus(
          status: WalletJSScriptStatus.failed, identifier: viewId);
      return;
    }
    if (!isWorker) {
      updatePageScriptStatus(
          status: WalletJSScriptStatus.active, identifier: viewId);
    }
  }

  @override
  Future<void> switchTab(WebViewTabController controller) async {
    await super.switchTab(controller);
    final viewType = this.viewType;
    if (viewType == null) return;
    final inited = await _scriptInitialized(viewType);
    if (!inited) reload();
  }

  @override
  void onPageStart(WebViewEvent event) async {
    _cancelable.cancel();

    await _lock.run(() async {
      onWeb3ClinetDisconnected(latestClient.value.client);
      super.onPageStart(event);
      final execute = await MethodUtils.call(
          () async => await _activeScript(event),
          cancelable: _cancelable);
      if (execute.hasError) {
        updatePageScriptStatus(
            status: WalletJSScriptStatus.failed, identifier: event.viewId);
      }
    });
  }

  @override
  void onPageRequest(WebViewEvent event) async {
    final request = event.request;
    if (request == null) return;

    if (request.type == WalletEventTypes.tabId) {
      final client = createClientInfos(
          clientId: event.viewId,
          url: event.url,
          faviIcon: event.favicon,
          title: event.title);
      _activeClient(viewId: event.viewId, event: request, client: client);
      return;
    }
    if (isWorker) {
      final bool isWalletRequest = await _lock.run(() async {
        final requestType =
            WalletJSScriptStatus.fromJSWalletEvent(request.type);
        if (requestType != null) {
          updatePageScriptStatus(
              status: requestType, identifier: request.clientId);
          assert(requestType != WalletJSScriptStatus.failed,
              'page script activation failed: ${StringUtils.tryDecode(request.data)}');
          return false;
        }
        return true;
      });
      if (!isWalletRequest) return;
    }
    final Completer<WalletEvent?> completer = Completer();
    onRequest(
        request: request,
        identifier: event.viewId,
        url: event.url,
        image: event.favicon,
        title: event.title,
        completer: completer);
    final response = await completer.future;
    bool result = false;
    if (response != null) {
      result = await _postEvent(response, viewType: event.viewId);
    }
    completeRequest(
        requestId: request.requestId,
        clientId: request.clientId,
        result: result);
  }

  @override
  Future<void> sendMessageToClient(
      {required Web3ActiveClient client,
      required Web3EncryptedMessage message}) async {
    final tab = tabsAuthenticated.values.firstWhereOrNull((e) =>
        Web3ApplicationAuthentication.toApplicationId(e.url) ==
            client.client.identifier &&
        e.viewId == client.identifier);
    if (tab == null) return;
    final event = toResponseEvent(
        id: client.clientId,
        type: WalletEventTypes.message,
        data: message.toCbor().encode());
    await _postEvent(event, viewType: tab.viewId);
  }

  Future<void> sendToClient(WalletEvent event) async {
    await _postEvent(event);
  }

  @override
  Future<void> dispose() async {
    webViewController.removeListener(this);
    _pageScript = null;
    _webviewWalletScript = null;
    await super.dispose();
  }
}
