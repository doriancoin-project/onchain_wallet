import 'package:on_chain_wallet/crypto/types/networks.dart';
import 'package:on_chain_wallet/wallet/web3/constant/constant/exception.dart';
import 'package:on_chain_wallet/wallet/web3/core/exception/exception.dart';
import 'package:on_chain_wallet/wallet/web3/core/messages/models/models/chain.dart';
import 'package:on_chain_wallet/wallet/web3/core/messages/models/models/exception.dart';
import 'package:on_chain_wallet/wallet/web3/core/messages/models/models/global_response.dart';
import 'package:on_chain_wallet/wallet/web3/core/messages/models/models/wallet_response.dart';
import 'package:on_chain_wallet/wallet/web3/core/messages/types/message.dart';
import 'package:on_chain_wallet/wallet/web3/core/messages/types/message_types.dart';
import 'package:on_chain_wallet/wallet/web3/core/permission/models/authenticated.dart';
import 'package:on_chain_wallet/wallet/web3/core/permission/types/account.dart';
import 'package:on_chain_wallet/wallet/web3/core/request/params.dart';
import 'package:on_chain_wallet/wallet/web3/state/core/types.dart';
import 'package:on_chain_wallet/wallet/web3/networks/global/methods/methods.dart';
import 'package:on_chain_wallet/wallet/web3/networks/global/params/connect.dart';
import 'package:on_chain_wallet/wallet/web3/utils/web3_validator_utils.dart';
import 'package:on_chain_wallet/wc/wallet/core/network.dart';
import 'package:on_chain_wallet/wc/wallet/networks/bitcoin.dart';
import 'package:on_chain_wallet/wc/wallet/networks/bitcoin_cash.dart';
import 'package:on_chain_wallet/wc/wallet/types/types.dart';
import 'package:on_chain_wallet/wc/core/types/types.dart';

typedef SENDMESSAGETOWALLET = void Function(WalletMessageRequest message);
typedef SENDEVENTTOCLIENT = Future<void> Function(WalletEventRequest message);

class Web3WalletConnectSessionHandler extends Web3WalletHandler<
    Web3WalletConnectStateHandler, WalletConnectNetworkRequest> {
  final Web3ClientInfo client;
  final SENDMESSAGETOWALLET sendMessagetowallet;
  final SENDEVENTTOCLIENT sendEventToClient;
  SessionData _session;
  String get topic => _session.topic;
  SessionData get session => _session;
  Web3WalletConnectSessionHandler(
      {required this.sendMessagetowallet,
      required this.sendEventToClient,
      required this.client,
      required SessionData session})
      : _session = session;
  late final Map<NetworkType, Web3WalletConnectStateHandler> _networks = {
    NetworkType.bitcoinAndForked: BitcoinWeb3WalletConnectStateHandler(
        sendInternalMessage: _sendInternalWalletMessage),
    NetworkType.bitcoinCash: BitcoinCashWeb3WalletConnectStateHandler(
        sendInternalMessage: _sendInternalWalletMessage),
  };

  Future<(List<WalletConnectAddress>, List<String>)> _getWalletChange() async {
    final states =
        await Future.wait(_networks.values.map((e) => e.getState()).toList());
    final accounts =
        states.map((e) => e.stateAccounts).expand((e) => e).toList();
    final chains = states.map((e) => e.chains).expand((e) => e).toList();
    return (accounts, chains.map((e) => e.caip2).toList());
  }

  Future<List<Web3ChainIdnetifier>> _getWalletNetwork() async {
    final states =
        await Future.wait(_networks.values.map((e) => e.getState()).toList());
    final chains = states.map((e) => e.chains).expand((e) => e).toList();
    return chains;
  }

  Future<Web3MessageCore> _onGlobalRequest(
      {required Web3GlobalRequestMethods method,
      required NetworkType? network,
      required WalletConnectNetworkRequest request}) async {
    switch (method) {
      case Web3GlobalRequestMethods.disconnect:
        return _networks[network]!.discoonect();
      case Web3GlobalRequestMethods.connect:
        final connectParam = request.requestParams.elementAtOrNull(0);
        List<int> networkIds = [];
        if (connectParam != null) {
          final data = request.paramsAsMap();
          final List<String>? chains =
              Web3ValidatorUtils.parseList<List<String>?, String>(
                  key: "chains", method: method, json: data);
          if (chains != null && chains.isNotEmpty) {
            final walletChains = await _getWalletNetwork();
            for (final i in chains) {
              if (!Web3ValidatorUtils.isCaip2(i)) {
                throw Web3RequestExceptionConst.invalidCaip2ChainIdStyle;
              }
              final network = walletChains.firstWhere((e) => e.isChain(i),
                  orElse: () =>
                      throw Web3RequestExceptionConst.networkIdDoesNotExists(
                          i));
              networkIds.add(network.id);
            }
          }
        }

        return Web3ConnectApplication.networks(networkIds);
      default:
        throw Web3RequestExceptionConst.methodDoesNotExist;
    }
  }

  Future<WalletConnectWalletMessageResponse> _finalizeGlobalResponse(
      {required WalletConnectNetworkRequest message,
      required Web3WalletRequestParams? params,
      required Web3GlobalResponseMessage response}) async {
    final method = Web3GlobalRequestMethods.fromName(message.method);
    switch (method) {
      case Web3GlobalRequestMethods.disconnect:
        return WalletConnectWalletMessageResponse.success(data: true);
      case Web3GlobalRequestMethods.connect:
        final accounts = (await _getWalletChange()).$1;
        if (accounts.isNotEmpty) {
          return WalletConnectWalletMessageResponse.success(data: accounts);
        }
        return WalletConnectWalletMessageResponse.fail(
            Web3RequestExceptionConst.rejectedByUser.toResponseMessage());
      default:
        throw Web3RequestExceptionConst.methodDoesNotExist;
    }
  }

  Future<void> updateAuthenticated(Web3APPData authenticated) async {
    final events = await Future.wait(authenticated.networks
        .map((e) async => await _networks[e]?.initChain(authenticated)));
    await _sendEventToClient(
        events.whereType<WalletConnectClientEvent>().toList());
  }

  Future<Web3MessageCore> _sendInternalWalletMessage(
      {required NetworkType network,
      required Web3WalletRequestParams request}) async {
    final result = await _buildAndSendMessage(message: request);
    final Web3MessageCore response = result.$1;
    if (response.type == Web3MessageTypes.error) {
      final result = response.cast<Web3ExceptionMessage>();
      throw result.toException();
    }
    return response.cast();
  }

  void onWalletResponse(
      {required Web3MessageCore message, required String requestId}) async {
    try {
      switch (message.type) {
        case Web3MessageTypes.globalResponse:
          final Web3GlobalResponseMessage msg =
              message.cast<Web3GlobalResponseMessage>();
          if (msg.authenticated != null) {
            await updateAuthenticated(msg.authenticated!);
          }
          completer.complete(response: msg, requestId: requestId);
          break;
        case Web3MessageTypes.walletResponse:
          final Web3WalletResponseMessage msg =
              message.cast<Web3WalletResponseMessage>();
          if (msg.authenticated != null) {
            await updateAuthenticated(msg.authenticated!);
          }

          completer.complete(response: msg, requestId: requestId);
          break;
        case Web3MessageTypes.error:
          final msg = message.cast<Web3ExceptionMessage>();
          if (msg.authenticated != null) {
            await updateAuthenticated(msg.authenticated!);
          }
          completer.complete(response: msg, requestId: requestId);
          break;
        case Web3MessageTypes.chains:
          final Web3ChainMessage msg = message.cast<Web3ChainMessage>();
          final auth = msg.authenticated;
          updateAuthenticated(auth);
          break;
        default:
      }
    } on Web3RequestException catch (e) {
      final toMessage = e.toResponseMessage(requestId: requestId);
      completer.complete(response: toMessage, requestId: requestId);
    } catch (e) {
      final toMessage = Web3RequestExceptionConst.internalError
          .toResponseMessage(requestId: requestId);
      completer.complete(response: toMessage, requestId: requestId);
    }
  }

  Future<void> _sendEventToClient(
    List<WalletConnectClientEvent> events,
  ) async {
    final namespaces = await generateNamespaces();
    if (namespaces != _session.namespaces) {
      _session = _session.copyWith(namespaces: namespaces);
      await sendEventToClient(WalletEventRequest(
          event: events, topic: _session.peerKey, session: _session));
      return;
    }
    await sendEventToClient(
        WalletEventRequest(event: events, topic: _session.peerKey));
  }

  Future<WalletConnectWalletMessageResponse> _requestCompleter(
      WalletConnectNetworkRequest params) async {
    final client = params.request?.network;
    final handler = _networks[client];
    try {
      final result = await _buildAndSendMessage(params: params);
      final Web3MessageCore response = result.$1;
      final Web3WalletRequestParams? request = result.$2;
      return switch (response.type) {
        Web3MessageTypes.globalResponse => await _finalizeGlobalResponse(
            message: params,
            response: response.cast(),
            params: request?.cast()),
        Web3MessageTypes.walletResponse => await handler!
            .finalizeWalletResponse(
                message: params,
                response: response.cast(),
                params: request?.cast()),
        Web3MessageTypes.error => await handler?.finalizeError(
                message: params,
                error: response.cast(),
                params: request?.cast()) ??
            WalletConnectWalletMessageResponse.fail(
                response.cast<Web3ExceptionMessage>()),
        _ => WalletConnectWalletMessageResponse.fail(
            Web3RequestExceptionConst.invalidRequest.toResponseMessage())
      };
    } finally {
      handler?.onRequestDone(params);
    }
  }

  Future<(Web3MessageCore, Web3WalletRequestParams?)> _buildAndSendMessage({
    WalletConnectNetworkRequest? params,
    Web3MessageCore? message,
  }) async {
    final completer = this.completer.nextRequest;
    final String requestId = completer.id;
    try {
      if (message == null) {
        if (params == null) {
          throw Web3RequestExceptionConst.invalidRequest;
        }
        Web3GlobalRequestMethods? method =
            Web3GlobalRequestMethods.fromName(params.method);
        if (method != null) {
          message = await _onGlobalRequest(
              method: method,
              network: params.request?.network,
              request: params);
        } else {
          final handler = _networks[params.request?.network];
          if (handler == null) {
            throw Web3RequestExceptionConst.invalidRequest;
          }
          message ??= await handler.request(params);
        }
      }

      switch (message.type) {
        case Web3MessageTypes.globalResponse:
        case Web3MessageTypes.walletResponse:
          this.completer.complete(response: message, requestId: requestId);
          break;
        default:
          final msg = WalletMessageRequest(
              message: message.cast(),
              requestId: requestId,
              topic: _session.peerKey,
              wcRequestId: params?.wcRequestId);
          sendMessagetowallet(msg);
          break;
      }
    } on Web3RequestException catch (e) {
      final exception = e.toResponseMessage();
      this.completer.complete(response: exception, requestId: requestId);
    } catch (e) {
      final exception =
          Web3RequestExceptionConst.internalError.toResponseMessage();
      this.completer.complete(response: exception, requestId: requestId);
    }
    final response = await completer.wait;
    if (message?.type != Web3MessageTypes.walletRequest &&
        message?.type != Web3MessageTypes.walletGlobalRequest) {
      return (response, null);
    }
    return (response, message?.cast<Web3WalletRequestParams>());
  }

  Future<WalletConnectWalletMessageResponse> onClientRequest(
      WalletConnectClientRequestParams sessionRequest) async {
    try {
      final handler = _networks[sessionRequest.network];
      if (handler == null) throw Web3RequestExceptionConst.networkDoesNotExists;
      final request = WalletConnectNetworkRequest.network(
          method: sessionRequest.method, request: sessionRequest);
      return _requestCompleter(request);
    } on Web3RequestException catch (e) {
      return WalletConnectWalletMessageResponse.fail(e.toResponseMessage());
    } catch (e) {
      return WalletConnectWalletMessageResponse.fail(
          Web3RequestExceptionConst.internalError.toResponseMessage());
    }
  }

  Future<WCSessionNamespaces> generateNamespaces() async {
    final namespaces =
        await Future.wait(_networks.values.map((e) => e.generateNamespace()));
    return WCSessionNamespaces(namespaces.expand((e) => e).toList());
  }

  Future<bool> activeSession(WalletConnectNetworkRequest request) async {
    if (_session.isActive) {
      throw Web3RequestExceptionConst.internalError;
    }
    final response = await _requestCompleter(request);
    final isActive =
        response.type == WalletConnectWalletMessageResponseType.success;
    _session = _session.copyWith(isActive: isActive);
    return isActive;
  }
}
