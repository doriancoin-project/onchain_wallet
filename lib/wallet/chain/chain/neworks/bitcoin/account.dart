part of 'package:on_chain_wallet/wallet/chain/chain/chain.dart';

class BitcoinNetworkStorageId extends DefaultNetworkStorageId {
  static const BitcoinNetworkStorageId utxos = BitcoinNetworkStorageId(11);
  const BitcoinNetworkStorageId(super.storageId);
  static const List<DefaultNetworkStorageId> values = [
    ...DefaultNetworkStorageId.values,
    utxos,
  ];
}

class BitcoinNetworkConfig
    extends DefaultNetworkConfig<BitcoinNetworkStorageId> {
  BitcoinNetworkConfig(
      {super.supportToken = false,
      super.supportNft = false,
      super.supportWeb3 = true,
      super.enableProvider = true});
  factory BitcoinNetworkConfig.deserialize(
      {List<int>? cborBytes, String? cborHex, CborObject? cborObject}) {
    final values = CborSerializable.cborTagValue(
        cborBytes: cborBytes, hex: cborHex, object: cborObject);
    return BitcoinNetworkConfig(
      supportToken: values.valueAs<bool?>(0) ?? false,
      supportNft: values.valueAs<bool?>(1) ?? false,
      supportWeb3: values.valueAs<bool?>(2) ?? true,
      enableProvider: values.valueAs<bool?>(3) ?? true,
    );
  }
  @override
  BitcoinNetworkConfig copyWith(
      {bool? supportToken,
      bool? supportNft,
      bool? supportWeb3,
      bool? enableProvider}) {
    return BitcoinNetworkConfig(
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
        CborTagsConst.bitcoinChainConfig);
  }

  @override
  List<DefaultNetworkStorageId> get storageKeys =>
      BitcoinNetworkStorageId.values;
}

final class BitcoinChain extends Chain<
    BaseBitcoinAPIProvider,
    BitcoinParams,
    BitcoinBaseAddress,
    TokenCore,
    NFTCore,
    IBitcoinAddress,
    WalletBitcoinNetwork,
    BitcoinClient,
    BitcoinNetworkConfig,
    BitcoinWalletTransaction,
    BitcoinContact,
    BaseBitcoinNewAddressParams> with BitcoinChainController {
  BitcoinChain._({
    required super.network,
    required super.addressIndex,
    required super.id,
    required super.config,
    required super.service,
    required super.addresses,
    super.totalBalance,
  }) : super._();
  @override
  BitcoinChain copyWith({
    WalletBitcoinNetwork? network,
    List<ChainAccount>? addresses,
    int? addressIndex,
    ProviderIdentifier? service,
    String? id,
    BitcoinNetworkConfig? config,
    BigInt? totalBalance,
  }) {
    return BitcoinChain._(
        network: network ?? this.network,
        addressIndex: addressIndex ?? _addressIndex,
        addresses: addresses?.cast<IBitcoinAddress>() ?? _addresses,
        service: service ?? _serviceIdentifier,
        id: id ?? this.id,
        config: config ?? this.config,
        totalBalance: totalBalance ?? this.totalBalance._value.balance);
  }

  factory BitcoinChain.setup(
      {required WalletBitcoinNetwork network,
      required String id,
      ProviderIdentifier? service}) {
    return BitcoinChain._(
        network: network,
        addressIndex: 0,
        id: id,
        service: service,
        addresses: [],
        config: BitcoinNetworkConfig());
  }

  factory BitcoinChain.deserialize(
      {required WalletBitcoinNetwork network, required CborListValue cbor}) {
    final int networkId = cbor.elementAs(0);
    if (networkId != network.value) {
      throw WalletExceptionConst.incorrectNetwork;
    }
    final String id = cbor.elementAs<String>(2);
    final List<IBitcoinAddress> accounts = cbor
        .elementAsListOf<CborTagValue>(3)
        .map((e) => switch (network.type) {
              NetworkType.bitcoinAndForked =>
                IBitcoinAddress.deserialize(network, obj: e),
              NetworkType.bitcoinCash =>
                IBitcoinCashAddress.deserialize(network, obj: e),
              _ => throw WalletExceptionConst.invalidAccountDeta(
                  "BitcoinChain.deserialize")
            })
        .toList();
    final int addressIndex = cbor.elementAs(4);
    final BitcoinNetworkConfig config =
        BitcoinNetworkConfig.deserialize(cborObject: cbor.indexAs(5));
    final ProviderIdentifier? service = MethodUtils.nullOnException(() {
      final CborTagValue? identifier = cbor.elementAs(6);
      if (identifier == null) return null;
      return ProviderIdentifier.deserialize(cbor: identifier);
    });
    final BigInt? totalBalance = cbor.elementAs<BigInt?>(7);
    return BitcoinChain._(
        network: network,
        addresses: accounts,
        addressIndex: addressIndex,
        service: service,
        id: id,
        totalBalance: totalBalance,
        config: config);
  }

  BitcoinBaseAddress? findAddressFromScript(Script script) {
    return _addresses
        .firstWhereOrNull((e) => e.networkAddress.toScriptPubKey() == script)
        ?.networkAddress;
  }

  @override
  Future<void> _updateAddressBalanceInternal(IBitcoinAddress address,
      {bool tokens = true}) async {
    _utxos.remove(address);
    await onClient(onConnect: (client) async {
      await getAccountUtxos(address);
    });
  }

  @override
  Future<void> updateTokenBalance(
      {required IBitcoinAddress address,
      required List<TokenCore<BalanceCore<dynamic, APPToken>, APPToken>>
          tokens}) async {}

  @override
  IBitcoinAddress _deserializeAddress(List<int> adressBytes) {
    return switch (network.type) {
      NetworkType.bitcoinAndForked =>
        IBitcoinAddress.deserialize(network, bytes: adressBytes),
      NetworkType.bitcoinCash =>
        IBitcoinCashAddress.deserialize(network, bytes: adressBytes),
      _ => throw WalletExceptionConst.invalidAccountDeta(
          "BitcoinChain.deserialize")
    };
  }
}
