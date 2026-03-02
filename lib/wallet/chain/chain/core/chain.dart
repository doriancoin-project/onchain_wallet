part of 'package:on_chain_wallet/wallet/chain/chain/chain.dart';

abstract final class Chain<
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
        ADDRESSPARAM extends NewAccountParams>
    extends BaseChain<
        PROVIDER,
        NETWORKPARAMS,
        NETWORKADDRESS,
        CHAINTOKEN,
        CHAINNFT,
        ADDRESS,
        NETWORK,
        CLIENT,
        CONFIG,
        TRANSACTION,
        CONTACT,
        ADDRESSPARAM>
    with
        ChainRepository<PROVIDER, ADDRESS, NETWORK, CLIENT, CONFIG, CHAINTOKEN,
            CHAINNFT, TRANSACTION, CONTACT, ADDRESSPARAM>,
        BaseChainController<
            PROVIDER,
            NETWORKPARAMS,
            NETWORKADDRESS,
            CHAINTOKEN,
            CHAINNFT,
            ADDRESS,
            NETWORK,
            CLIENT,
            CONFIG,
            TRANSACTION,
            CONTACT,
            ADDRESSPARAM>,
        BaseChainWeb3Controller<
            PROVIDER,
            NETWORKPARAMS,
            NETWORKADDRESS,
            CHAINTOKEN,
            CHAINNFT,
            ADDRESS,
            NETWORK,
            CLIENT,
            CONFIG,
            TRANSACTION,
            CONTACT,
            ADDRESSPARAM>,
        CborSerializable,
        CryptoWokerImpl {
  @override
  final NetworkStorageManager _storage;

  NETWORK _network;
  @override
  NETWORK get network => _network;
  @override
  ProviderIdentifier? _serviceIdentifier;
  @override
  CLIENT? _service;

  @override
  List<ADDRESS> _addresses;
  @override
  int _addressIndex;
  @override
  final InternalStreamValue<IntegerBalance> totalBalance;
  @override
  List<CONTACT> _contacts;
  // @override
  List<ADDRESS> get addresses => _addresses;

  bool get haveAddress => _addresses.isNotEmpty;
  @override
  List<CONTACT> get contacts => _contacts;
  @override
  ADDRESS get address => _addresses.elementAt(_addressIndex);
  @override
  final String id;
  @override
  CONFIG _config;
  @override
  CONFIG get config => _config;

  @override
  _WalletChainStatus _status = _WalletChainStatus.init;
  @override
  NodeClientStatus _clientStatus = NodeClientStatus.disconnect;

  bool get transferEnabled => true;

  @override
  final _lock = SafeAtomicLock();

  factory Chain.deserialize({String? hex, CborObject? obj, List<int>? bytes}) {
    final CborListValue values = CborSerializable.cborTagValue(
        cborBytes: bytes, object: obj, hex: hex, tags: CborTagsConst.iAccount);
    final int networkId = values.elementAs(0);
    WalletNetwork? network = MethodUtils.nullOnException(() {
      return WalletNetwork.fromCborBytesOrObject(
          obj: values.elementAsCborTag(1));
    });
    network = ChainConst.updateNetwork(networkId: networkId, network: network);
    return Chain._fromNetwork(network: network, values: values);
  }
  static Chain setup({required WalletNetwork network, required String id}) {
    switch (network.type) {
      case NetworkType.bitcoinAndForked:
      case NetworkType.bitcoinCash:
        return BitcoinChain.setup(network: network.toNetwork(), id: id);
      default:
        throw WalletExceptionConst.networkDoesNotExist;
    }
  }

  factory Chain._fromNetwork(
      {required WalletNetwork network, required CborListValue values}) {
    final Chain chain;
    switch (network.type) {
      case NetworkType.bitcoinCash:
      case NetworkType.bitcoinAndForked:
        chain = BitcoinChain.deserialize(
            network: network.toNetwork(), cbor: values);
        break;
      default:
        throw WalletExceptionConst.networkDoesNotExist;
    }
    return chain.cast();
  }

  Chain._(
      {required NETWORK network,
      required this.id,
      required CONFIG config,
      List<ADDRESS> addresses = const [],
      required int addressIndex,
      required ProviderIdentifier? service,
      required BigInt? totalBalance})
      : _addresses = addresses.imutable,
        _network = network,
        _addressIndex = addressIndex < 0 ? 0 : addressIndex,
        _contacts = [],
        _serviceIdentifier = service,
        _config = config,
        totalBalance = InternalStreamValue.immutable(IntegerBalance.token(
            totalBalance ?? BigInt.zero, network.token,
            immutable: true)),
        _storage =
            NetworkStorageManager(network: network, id: id, config: config);

  Chain copyWith(
      {NETWORK? network,
      List<ChainAccount>? addresses,
      int? addressIndex,
      String? id,
      CONFIG? config,
      ProviderIdentifier? service});

  @override
  String toString() {
    return "Chain: ${network.networkName}";
  }
}
