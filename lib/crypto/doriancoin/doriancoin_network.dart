import 'package:bitcoin_base/bitcoin_base.dart';
import 'package:blockchain_utils/blockchain_utils.dart';

class DoriancoinNetwork implements BasedUtxoNetwork {
  static const DoriancoinNetwork mainnet = DoriancoinNetwork._(
    'doriancoinMainnet',
    _mainnetConf,
    'doriancoin:mainnet',
  );

  static const DoriancoinNetwork testnet = DoriancoinNetwork._(
    'doriancoinTestnet',
    _testnetConf,
    'doriancoin:testnet',
  );

  @override
  final CoinConf conf;

  @override
  final String value;

  @override
  final String identifier;

  const DoriancoinNetwork._(this.value, this.conf, this.identifier);

  @override
  List<int> get wifNetVer => conf.params.wifNetVer!;

  @override
  List<int> get p2pkhNetVer => conf.params.p2pkhNetVer!;

  @override
  List<int> get p2shNetVer => conf.params.p2shNetVer!;

  @override
  String get p2wpkhHrp => conf.params.p2wpkhHrp!;

  @override
  bool get isMainnet => this == DoriancoinNetwork.mainnet;

  @override
  final List<BitcoinAddressType> supportedAddress = const [
    P2pkhAddressType.p2pkh,
    SegwitAddressType.p2wpkh,
    PubKeyAddressType.p2pk,
    SegwitAddressType.p2tr,
    SegwitAddressType.p2wsh,
    P2shAddressType.p2wshInP2sh,
    P2shAddressType.p2wpkhInP2sh,
    P2shAddressType.p2pkhInP2sh,
    P2shAddressType.p2pkInP2sh,
  ];

  @override
  List<BipCoins> get coins {
    if (isMainnet) {
      return [
        Bip44Coins.litecoin,
        Bip49Coins.litecoin,
        Bip84Coins.litecoin,
        Bip86Coins.bitcoin,
      ];
    }
    return [
      Bip44Coins.litecoinTestnet,
      Bip49Coins.litecoinTestnet,
      Bip84Coins.litecoinTestnet,
      Bip86Coins.bitcoinTestnet,
    ];
  }

  @override
  bool operator ==(Object other) {
    if (identical(other, this)) return true;
    return other is DoriancoinNetwork &&
        other.runtimeType == runtimeType &&
        value == other.value;
  }

  @override
  int get hashCode => value.hashCode;

  static const CoinConf _mainnetConf = CoinConf(
    coinName: CoinNames("Doriancoin", "DSV"),
    params: CoinParams(
      p2pkhNetVer: [0x1e],
      p2shNetVer: [0x05],
      wifNetVer: [0xb0],
      p2wpkhHrp: "dsv",
      p2trHrp: "dsv",
      p2trWitVer: 1,
      p2wpkhWitVer: 0,
    ),
  );

  static const CoinConf _testnetConf = CoinConf(
    coinName: CoinNames("Doriancoin testnet", "tDSV"),
    params: CoinParams(
      p2pkhNetVer: [0x1e],
      p2shNetVer: [0x16],
      wifNetVer: [0xef],
      p2wpkhHrp: "tdsv",
      p2trHrp: "tdsv",
      p2trWitVer: 1,
      p2wpkhWitVer: 0,
    ),
  );

  static void register() {
    final currentValues = BasedUtxoNetwork.values;
    if (currentValues.any((n) => n is DoriancoinNetwork)) return;
    BasedUtxoNetwork.values = [
      ...currentValues,
      DoriancoinNetwork.mainnet,
      DoriancoinNetwork.testnet,
    ];
  }
}
