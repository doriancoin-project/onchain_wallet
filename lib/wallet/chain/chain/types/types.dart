part of 'package:on_chain_wallet/wallet/chain/chain/chain.dart';

enum _WalletChainStatus {
  init,
  ready,
  dispose;

  bool get isInit => this == init;
}

enum _WalletAddressStatus {
  init,
  ready;

  bool get isInit => this == init;
  bool get isReady => this == ready;
}

abstract class StorageId {
  abstract final int storageId;
}

abstract class ChainStorageId extends StorageId {}

abstract class NetworkConfig<STORAGE extends StorageId>
    with CborSerializable, Equality {
  double get appbarHeight => 0;
  bool get hasAction => false;
  final bool supportToken;
  final bool supportNft;
  final bool supportWeb3;
  final bool enableProvider;

  List<StorageId> get storageKeys;
  const NetworkConfig(
      {required this.supportToken,
      required this.supportNft,
      required this.supportWeb3,
      required this.enableProvider});

  @override
  List get variabels => [storageKeys, hasAction];
}

class DefaultNetworkConfig<T extends DefaultNetworkStorageId>
    extends NetworkConfig<T> {
  const DefaultNetworkConfig(
      {required super.supportToken,
      required super.supportNft,
      required super.supportWeb3,
      required super.enableProvider});
  factory DefaultNetworkConfig.deserialize(
      {List<int>? cborBytes, String? cborHex, CborObject? cborObject}) {
    final values = CborSerializable.cborTagValue(
        cborBytes: cborBytes,
        hex: cborHex,
        object: cborObject,
        tags: CborTagsConst.defaultNetworkConfig);
    return DefaultNetworkConfig(
      supportToken:
          values.indexMaybeAs<bool, CborBoleanValue>(0, (e) => e.value) ?? true,
      supportNft:
          values.indexMaybeAs<bool, CborBoleanValue>(1, (e) => e.value) ??
              false,
      supportWeb3:
          values.indexMaybeAs<bool, CborBoleanValue>(2, (e) => e.value) ?? true,
      enableProvider:
          values.indexMaybeAs<bool, CborBoleanValue>(3, (e) => e.value) ?? true,
    );
  }
  // DefaultNetworkConfig.deserialize({String?  cbor,
  // List<int>? bytes,CborObject?object})
  static const DefaultNetworkConfig defaultConfig = DefaultNetworkConfig(
      supportNft: false,
      supportToken: true,
      supportWeb3: true,
      enableProvider: true);

  DefaultNetworkConfig copyWith(
      {bool? supportToken,
      bool? supportNft,
      bool? supportWeb3,
      bool? enableProvider}) {
    return DefaultNetworkConfig(
        supportToken: supportToken ?? this.supportToken,
        supportNft: supportNft ?? this.supportNft,
        supportWeb3: supportWeb3 ?? this.supportWeb3,
        enableProvider: enableProvider ?? this.enableProvider);
  }

  @override
  CborTagValue toCbor() {
    return CborTagValue(
        CborSerializable.fromDynamic([
          supportToken,
          supportNft,
          supportWeb3,
          enableProvider,
        ]),
        CborTagsConst.defaultNetworkConfig);
  }

  @override
  List<DefaultNetworkStorageId> get storageKeys =>
      DefaultNetworkStorageId.values;
}

/// maximum value 999
class DefaultNetworkStorageId implements StorageId {
  static const DefaultNetworkStorageId contacts = DefaultNetworkStorageId(0);
  static const DefaultNetworkStorageId transaction = DefaultNetworkStorageId(1);
  static const DefaultNetworkStorageId token = DefaultNetworkStorageId(2);
  static const DefaultNetworkStorageId nft = DefaultNetworkStorageId(3);
  static const DefaultNetworkStorageId web3 = DefaultNetworkStorageId(4);
  static const DefaultNetworkStorageId address = DefaultNetworkStorageId(5);
  static const DefaultNetworkStorageId providers = DefaultNetworkStorageId(6);
  static const DefaultNetworkStorageId account = DefaultNetworkStorageId(1000);
  static const List<DefaultNetworkStorageId> values = [
    contacts,
    transaction,
    token,
    nft,
    web3
  ];

  @override
  final int storageId;
  const DefaultNetworkStorageId(this.storageId);
}

class DefaultChainStorageId implements ChainStorageId {
  static const DefaultChainStorageId web3 = DefaultChainStorageId(2);
  static const DefaultChainStorageId config = DefaultChainStorageId(3);
  @override
  final int storageId;
  const DefaultChainStorageId(this.storageId);

  static const List<DefaultChainStorageId> values = [web3, config];
}

abstract final class BaseChain<
    PROVIDER extends APIProvider,
    NETWORKPARAMS extends NetworkCoinParams,
    NETWORKADDRESS,
    CHAINTOKEN extends TokenCore,
    CHAINNFT extends NFTCore,
    ADDRESS extends ChainAccount,
    NETWORK extends WalletNetwork,
    CLIENT extends NetworkClient,
    CONFIG extends DefaultNetworkConfig,
    TRANSACTION extends ChainTransaction,
    CONTACT extends ContactCore,
    ADDRESSPARAM extends NewAccountParams> with CborSerializable {
  abstract _WalletChainStatus _status;
  abstract final NETWORK network;
  abstract final InternalStreamValue<IntegerBalance> totalBalance;
  abstract final String id;
  abstract ProviderIdentifier? _serviceIdentifier;
  abstract CLIENT? _service;

  abstract NodeClientStatus _clientStatus;
  NetworkServiceProtocol? get service => _service?.service;
  NodeClientStatus get serviceStatus => _clientStatus;

  abstract List<ADDRESS> _addresses;
  abstract int _addressIndex;
  abstract final List<String> services;
  abstract List<CONTACT> _contacts;
  List<CONTACT> get contacts => _contacts;
  ADDRESS get address => _addresses.elementAt(_addressIndex);
  abstract CONFIG _config;
  CONFIG get config => _config;
  abstract final SafeAtomicLock _lock;

  abstract final NetworkStorageManager _storage;

  ProviderIdentifier? get serviceIdentifier => _serviceIdentifier;

  late final StreamController<ChainEvent> _controller =
      StreamController.broadcast();
  Stream<ChainEvent> get stream => _controller.stream;
  T cast<T extends Chain>() {
    if (this is! T) {
      throw WalletExceptionConst.internalError("Chain");
    }
    return this as T;
  }
}

abstract class ChainNotify {
  abstract final int value;
}

enum DefaultChainNotify implements ChainNotify {
  address(0),
  account(1),
  client(2),
  config(3),
  contacts(4),
  transaction(5),
  token(6),
  nft(7),
  updateProvider(8);

  @override
  final int value;
  const DefaultChainNotify(this.value);
}

enum ChainNotifyStatus {
  progress,
  complete;

  bool get isComplete => this == complete;
}

class ChainEvent {
  final ChainNotify type;
  final ChainNotifyStatus status;
  const ChainEvent({required this.type, required this.status});
  factory ChainEvent.progress(ChainNotify type) {
    return ChainEvent(type: type, status: ChainNotifyStatus.progress);
  }
  factory ChainEvent.complete(ChainNotify type) {
    return ChainEvent(type: type, status: ChainNotifyStatus.complete);
  }
}

enum ChainWalletEventType {
  ping,
  connection,
  chainChanged;
}

abstract final class ChainWalletEvent {
  final ChainWalletEventType type;
  const ChainWalletEvent({required this.type});
  T cast<T extends ChainWalletEvent>() {
    if (this is T) return this as T;
    throw WalletExceptionConst.internalError("ChainWalletEvent");
  }
}

final class ChainWalletPingEvent extends ChainWalletEvent {
  const ChainWalletPingEvent() : super(type: ChainWalletEventType.ping);
}

final class ChainWalletConnectionEvent extends ChainWalletEvent {
  final bool isOnline;
  const ChainWalletConnectionEvent(this.isOnline)
      : super(type: ChainWalletEventType.connection);
}

final class ChainWalletChainChangeEvent extends ChainWalletEvent {
  final Chain? prv;
  final Chain current;
  const ChainWalletChainChangeEvent({required this.prv, required this.current})
      : super(type: ChainWalletEventType.chainChanged);
}

typedef ONSTREAMVALUEDISPOSE = bool Function();

final class InternalStreamValue<T> implements StreamValue<T> {
  final bool _allowDispose;
  ONSTREAMVALUEDISPOSE? _disposeCallback;
  T _value;
  // InternalStreamValue(T val, {this.immutable = false}) : _value = val;
  InternalStreamValue.immutable(T val, {bool allowDispose = false})
      : _value = val,
        immutable = true,
        _allowDispose = allowDispose;
  @override
  final bool immutable;
  @override
  bool get isClosed => _controller.isClosed;

  late final StreamController<T> _controller =
      StreamController.broadcast(onCancel: () {}, onListen: () {});
  @override
  Stream<T> get stream => _controller.stream;

  @override
  T get value {
    return _value;
  }

  @override
  set silent(T newValue) {
    assert(!isClosed, 'stream  closed.');
    assert(!immutable, 'data marked as immutable');
    if (_value == newValue || immutable) return;
    _value = newValue;
  }

  @override
  set value(T newValue) {
    assert(!isClosed, 'stream  closed.');
    assert(!immutable, 'data marked as immutable');
    if (_value == newValue || immutable) return;
    _value = newValue;
    if (_controller.hasListener && !isClosed) {
      _controller.add(newValue);
    }
  }

  @override
  set updateValue(T newValue) {
    assert(!isClosed, 'stream  closed.');
    assert(!immutable, 'data marked as immutable');
    if (immutable) return;
    _value = newValue;
    if (_controller.hasListener && !isClosed) {
      _controller.add(newValue);
    }
  }

  @override
  void notify() {
    assert(!isClosed, 'stream  closed.');
    if (_controller.hasListener && !isClosed) {
      _controller.add(_value);
    }
  }

  void _disposeInternal() {
    assert(!isClosed, 'stream  closed.');
    _controller.close();
  }

  @override
  void dispose() {
    if (!_allowDispose) return;
    final callBack = _disposeCallback;
    if (callBack != null) {
      if (callBack()) {
        _disposeInternal();
      }
      return;
    }
    _disposeInternal();
  }
}

abstract class ChainConfig with CborSerializable, Equality {
  const ChainConfig();
  NetworkType get network;
  @override
  List get variabels => [];
  factory ChainConfig.deserialize(
      {List<int>? cborBytes, String? cborHex, CborObject? cborObject}) {
    throw WalletExceptionConst.internalError("ChainConfig.deserialize");
  }
  factory ChainConfig.create(NetworkType network) {
    throw WalletExceptionConst.internalError("ChainConfig.create");
  }
  T cast<T extends ChainConfig>() {
    if (this is! T) {
      throw WalletExceptionConst.internalError("ChainConfig.cast");
    }
    return this as T;
  }
}
