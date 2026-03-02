import 'package:bitcoin_base/bitcoin_base.dart';
import 'package:blockchain_utils/blockchain_utils.dart';
import 'doriancoin_network.dart';

class DoriancoinAddress {
  final BitcoinBaseAddress baseAddress;
  final String address;
  final DoriancoinNetwork network;

  const DoriancoinAddress._(this.baseAddress, this.address, this.network);

  factory DoriancoinAddress(
    String address, {
    DoriancoinNetwork network = DoriancoinNetwork.mainnet,
  }) {
    return DoriancoinAddress._(
      _decodeAddress(address, network),
      address,
      network,
    );
  }

  factory DoriancoinAddress.fromBaseAddress(
    BitcoinBaseAddress address, {
    DoriancoinNetwork network = DoriancoinNetwork.mainnet,
  }) {
    final baseAddress = _validateAddress(address, network);
    return DoriancoinAddress._(
      baseAddress,
      baseAddress.toAddress(network),
      network,
    );
  }

  BitcoinAddressType get type => baseAddress.type;

  String toAddress([DoriancoinNetwork? updateNetwork]) {
    return updateNetwork == null
        ? address
        : baseAddress.toAddress(updateNetwork);
  }

  static BitcoinBaseAddress _validateAddress(
      BitcoinBaseAddress address, DoriancoinNetwork network) {
    if (network.supportedAddress.contains(address.type)) {
      return address;
    }
    throw DartBitcoinPluginException(
        '${network.value} does not support ${address.type.value} address');
  }

  static BitcoinBaseAddress _decodeAddress(
      String address, DoriancoinNetwork network) {
    BitcoinBaseAddress? baseAddress;
    if (network.supportedAddress.contains(SegwitAddressType.p2wpkh)) {
      baseAddress = _toSegwitAddress(address, network);
    }
    baseAddress ??= _toLegacy(address, network);
    if (baseAddress == null) {
      throw const DartBitcoinPluginException('Invalid Doriancoin address.');
    }
    return _validateAddress(baseAddress, network);
  }

  static SegwitAddress? _toSegwitAddress(
      String address, DoriancoinNetwork network) {
    try {
      final convert = SegwitBech32Decoder.decode(network.p2wpkhHrp, address);
      final witnessVersion = convert.item1;
      final decodedBytesHex = BytesUtils.toHexString(convert.item2);
      if (witnessVersion == 1) {
        return P2trAddress.fromProgram(program: decodedBytesHex);
      } else if (witnessVersion == 0) {
        if (convert.item2.length == QuickCrypto.hash160DigestSize) {
          return P2wpkhAddress.fromProgram(program: decodedBytesHex);
        } else if (convert.item2.length == QuickCrypto.sha256DigestSize) {
          return P2wshAddress.fromProgram(program: decodedBytesHex);
        }
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  static LegacyAddress? _toLegacy(
      String address, DoriancoinNetwork network) {
    try {
      final decode = List<int>.unmodifiable(Base58Decoder.decode(address));
      final scriptBytes =
          decode.sublist(1, decode.length - Base58Const.checksumByteLen);
      if (scriptBytes.length != QuickCrypto.hash160DigestSize) {
        return null;
      }
      final version = <int>[decode[0]];
      final data =
          decode.sublist(0, decode.length - Base58Const.checksumByteLen);
      final checksum =
          decode.sublist(decode.length - Base58Const.checksumByteLen);
      final hash = QuickCrypto.sha256DoubleHash(data)
          .sublist(0, Base58Const.checksumByteLen);
      if (!BytesUtils.bytesEqual(checksum, hash)) {
        return null;
      }
      final decodedHex = BytesUtils.toHexString(scriptBytes);
      if (BytesUtils.bytesEqual(version, network.p2pkhNetVer)) {
        return P2pkhAddress.fromHash160(addrHash: decodedHex);
      } else if (BytesUtils.bytesEqual(version, network.p2shNetVer)) {
        return P2shAddress.fromHash160(addrHash: decodedHex);
      }
      return null;
    } catch (e) {
      return null;
    }
  }
}
