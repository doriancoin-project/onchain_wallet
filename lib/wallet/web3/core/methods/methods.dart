import 'package:on_chain_wallet/app/utils/list/extension.dart';
import 'package:on_chain_wallet/crypto/types/networks.dart';
import 'package:on_chain_wallet/wallet/web3/constant/constant/exception.dart';
import 'package:on_chain_wallet/wallet/web3/networks/bitcoin/methods/methods.dart';
import 'package:on_chain_wallet/wallet/web3/networks/bitcoin_cash/methods/methods.dart';

enum Web3RequestMode { silent, user }

abstract class Web3RequestMethods {
  final int id;
  final String name;
  final List<String> methodsName;
  final bool reloadAuthenticated;
  final Web3RequestMode mode;
  bool get isGlobalMethod => false;
  List<String> get walletConnectMethodNames => [name, ...methodsName];

  const Web3RequestMethods(
      {required this.id,
      required this.name,
      required this.methodsName,
      required this.reloadAuthenticated,
      this.mode = Web3RequestMode.user});
  T cast<T extends Web3RequestMethods>() {
    if (this is! T) {
      throw Web3RequestExceptionConst.internalError;
    }
    return this as T;
  }

  @override
  String toString() {
    return name;
  }
}

enum Web3NetworkEvent {
  accountsChanged,
  chainChanged,
  message,
  connect,
  disconnect,
  change;

  bool get needEmit =>
      this == accountsChanged ||
      this == chainChanged ||
      this == connect ||
      this == change;

  static Web3NetworkEvent name(String? name) {
    return values.firstWhere((e) => e.name == name,
        orElse: () => throw Web3RequestExceptionConst.internalError);
  }

  static List<Web3NetworkEvent> getEvents(NetworkType network) {
    switch (network) {
      default:
        return [change];
    }
  }

  static Web3NetworkEvent? fromName(String? name) {
    return values.firstWhereOrNull((e) => e.name == name);
  }
}

abstract class Web3NetworkRequestMethods extends Web3RequestMethods {
  const Web3NetworkRequestMethods(
      {required super.id,
      required super.name,
      super.methodsName = const [],
      super.reloadAuthenticated = false});
  abstract final NetworkType network;
  List<int> get tag => [...network.tag, id];
  static Web3NetworkRequestMethods fromTag(List<int>? tag) {
    final network = NetworkType.fromTag(tag);
    return switch (network) {
      NetworkType.bitcoinAndForked =>
        Web3BitcoinRequestMethods.fromId(tag!.last),
      NetworkType.bitcoinCash =>
        Web3BitcoinCashRequestMethods.fromId(tag!.last),
      _ => throw Web3RequestExceptionConst.invalidNetwork
    };
  }

  static List<Web3NetworkRequestMethods> getMethods(NetworkType network) {
    return switch (network) {
      NetworkType.bitcoinAndForked => Web3BitcoinRequestMethods.values,
      NetworkType.bitcoinCash => Web3BitcoinCashRequestMethods.values,
      _ => throw Web3RequestExceptionConst.invalidNetwork
    };
  }
}
