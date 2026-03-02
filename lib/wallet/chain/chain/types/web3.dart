part of 'package:on_chain_wallet/wallet/chain/chain/chain.dart';

abstract class Web3InternalNetworkAccount with CborSerializable, Equality {
  final AddressDerivationIndex keyIndex;
  final String identifier;
  const Web3InternalNetworkAccount(
      {required this.keyIndex, required this.identifier});
}

abstract class Web3InternalNetwork<ACCOUNT extends Web3InternalNetworkAccount>
    with CborSerializable, Equality {
  final List<ACCOUNT> accounts;
  final ACCOUNT? defaultAccount;
  final int networkId;
  Web3InternalNetwork._(
      {required List<ACCOUNT> accounts,
      required this.networkId,
      this.defaultAccount})
      : accounts = accounts.immutable;
}

abstract class Web3InternalChain<T extends Web3InternalNetwork>
    with CborSerializable, Equality {
  final List<T> networks;
  final int defaultChain;
  final NetworkType type;

  bool hasAnyChainPermission() {
    return networks.any((e) => e.accounts.isNotEmpty);
  }

  bool hasAnyNetworkPermission(int networkId) {
    final network = networks.firstWhereOrNull((e) => e.networkId == networkId);
    assert(network != null, "invalid network id");
    return network?.accounts.isNotEmpty ?? false;
  }

  E cast<E extends Web3InternalChain>() {
    if (this is! E) {
      throw WalletExceptionConst.internalError("Web3InternalChain");
    }
    return this as E;
  }

  const Web3InternalChain._(
      {required this.networks, required this.defaultChain, required this.type});

  factory Web3InternalChain.deserialize(
      {List<int>? bytes, CborObject? object, String? hex}) {
    final CborTagValue tag =
        CborSerializable.decode(cborBytes: bytes, hex: hex, object: object);
    final type = NetworkType.fromTag(tag.tags);
    final chain = Web3InternalDefaultChain.deserialize(object: tag);
    if (chain is! Web3InternalChain<T>) {
      throw WalletExceptionConst.internalError("Web3InternalChain");
    }
    return chain;
  }
}

class Web3InternalDefaultNetworkAccount extends Web3InternalNetworkAccount {
  const Web3InternalDefaultNetworkAccount(
      {required super.keyIndex, required super.identifier});
  factory Web3InternalDefaultNetworkAccount.deserialize(
      {List<int>? bytes, CborObject? object, String? hex}) {
    final CborListValue values = CborSerializable.cborTagValue(
        cborBytes: bytes,
        hex: hex,
        object: object,
        tags: CborTagsConst.web3InternalNetworkAccount);
    return Web3InternalDefaultNetworkAccount(
        keyIndex: AddressDerivationIndex.deserialize(obj: values.indexAs(0)),
        identifier: values.valueAs(1));
  }
  @override
  CborTagValue<CborObject> toCbor() {
    return CborTagValue(
        CborListValue<CborObject>.definite(
            [keyIndex.toCbor(), CborStringValue(identifier)]),
        CborTagsConst.web3InternalNetworkAccount);
  }

  @override
  List get variabels => [keyIndex, identifier];
}

class Web3InternalDefaultNetwork
    extends Web3InternalNetwork<Web3InternalDefaultNetworkAccount> {
  Web3InternalDefaultNetwork._(
      {required super.accounts, required super.networkId, super.defaultAccount})
      : super._();
  factory Web3InternalDefaultNetwork(
      {required List<Web3InternalDefaultNetworkAccount> accounts,
      required int networkId,
      Web3InternalDefaultNetworkAccount? defaultAccount}) {
    if ((accounts.isNotEmpty && !accounts.contains(defaultAccount)) ||
        (accounts.isEmpty && defaultAccount != null)) {
      throw WalletExceptionConst.invalidWeb3AccountData;
    }
    return Web3InternalDefaultNetwork._(
        accounts: accounts.clone()
          ..sort((a, b) => a.identifier.compareTo(b.identifier)),
        defaultAccount: defaultAccount,
        networkId: networkId);
  }

  factory Web3InternalDefaultNetwork.deserialize(
      {List<int>? bytes, CborObject? object, String? hex}) {
    final CborListValue values = CborSerializable.cborTagValue(
        cborBytes: bytes,
        hex: hex,
        object: object,
        tags: CborTagsConst.web3InternalNetwork);
    return Web3InternalDefaultNetwork(
        accounts: values
            .elementAsListOf<CborTagValue>(0)
            .map(
                (e) => Web3InternalDefaultNetworkAccount.deserialize(object: e))
            .toList(),
        defaultAccount: values.indexMaybeAs<Web3InternalDefaultNetworkAccount,
                CborTagValue>(
            1, (e) => Web3InternalDefaultNetworkAccount.deserialize(object: e)),
        networkId: values.elementAs(2));
  }

  @override
  CborTagValue<CborObject> toCbor() {
    return CborTagValue(
        CborListValue<CborObject>.definite([
          CborListValue.definite(
              accounts.map((e) => e.toCbor()).toImutableList),
          defaultAccount?.toCbor() ?? const CborNullValue(),
          CborIntValue(networkId)
        ]),
        CborTagsConst.web3InternalNetwork);
  }

  @override
  List get variabels => [accounts, defaultAccount, networkId];
}

class Web3InternalDefaultChain
    extends Web3InternalChain<Web3InternalDefaultNetwork> {
  const Web3InternalDefaultChain._(
      {required super.networks,
      required super.defaultChain,
      required super.type})
      : super._();
  factory Web3InternalDefaultChain(
      {required List<Web3InternalDefaultNetwork> networks,
      required int defaultChain,
      required NetworkType type}) {
    if (networks.map((e) => e.networkId).toSet().length != networks.length) {
      throw WalletExceptionConst.invalidWeb3AccountData;
    }
    return Web3InternalDefaultChain._(
        networks: networks.clone()
          ..sort((a, b) => a.networkId.compareTo(b.networkId)),
        defaultChain: defaultChain,
        type: type);
  }
  factory Web3InternalDefaultChain.deserialize(
      {List<int>? bytes, CborObject? object, String? hex}) {
    final CborTagValue tag =
        CborSerializable.decode(cborBytes: bytes, hex: hex, object: object);
    final type = NetworkType.fromTag(tag.tags);
    final values = tag.valueAs<CborListValue>();
    return Web3InternalDefaultChain(
        networks: values
            .elementAsListOf<CborTagValue>(0)
            .map((e) => Web3InternalDefaultNetwork.deserialize(object: e))
            .toList(),
        defaultChain: values.elementAs(1),
        type: type);
  }

  @override
  CborTagValue<CborObject> toCbor() {
    return CborTagValue(
        CborListValue<CborObject>.definite([
          CborListValue.definite(networks.map((e) => e.toCbor()).toList()),
          CborIntValue(defaultChain),
          CborIntValue(type.id),
        ]),
        type.tag);
  }

  @override
  List get variabels => [networks, defaultChain, type];
}

