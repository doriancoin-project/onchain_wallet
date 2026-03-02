import 'package:bitcoin_base/bitcoin_base.dart';
import 'package:blockchain_utils/blockchain_utils.dart';
import 'package:on_chain_wallet/app/core.dart';
import 'package:on_chain_wallet/crypto/doriancoin/doriancoin.dart';
import 'package:on_chain_wallet/wallet/models/network/network.dart';
import 'package:on_chain_wallet/crypto/types/networks.dart';

class BlockchainAddressUtils {
  static BitcoinBaseAddress toBitcoinAddress(
      String address, BasedUtxoNetwork network,
      {BitcoinAddressType? p2shAddressType}) {
    BitcoinBaseAddress addr;
    try {
      if (network is BitcoinCashNetwork) {
        addr = BitcoinCashAddress(address, network: network).baseAddress;
      } else if (network is BitcoinNetwork) {
        addr = BitcoinAddress(address, network: network).baseAddress;
      } else if (network is DogecoinNetwork) {
        addr = DogeAddress(address, network: network).baseAddress;
      } else if (network is DashNetwork) {
        addr = DashAddress(address, network: network).baseAddress;
      } else if (network is LitecoinNetwork) {
        addr = LitecoinAddress(address, network: network).baseAddress;
      } else if (network is PepeNetwork) {
        addr = PepeAddress(address, network: network).baseAddress;
      } else if (network is DoriancoinNetwork) {
        addr = DoriancoinAddress(address, network: network).baseAddress;
      } else {
        throw UnimplementedError();
      }
      if (addr.type.isP2sh && p2shAddressType != null) {
        if (addr.type != p2shAddressType) {
          addr = P2shAddress.fromHash160(
              addrHash: addr.addressProgram,
              type: p2shAddressType.isP2sh
                  ? p2shAddressType as P2shAddressType
                  : P2shAddressType.p2pkInP2sh);
        }
      }
      return addr;
    } catch (e) {
      throw ArgumentError("invalid ${network.conf.coinName} address");
    }
  }

  static BitcoinBaseAddress publicKeyToBitcoinAddress(
      {required List<int> publicKey,
      required CryptoCoins coin,
      required BitcoinAddressType addressType,
      required PubKeyModes keyType}) {
    final bitcoinPublicKey = ECPublic.fromBytes(publicKey);
    BitcoinBaseAddress address;
    switch (coin.proposal) {
      case BipProposal.bip44:
        address = bitcoinPublicKey.toAddress(mode: keyType);
        if (addressType == P2pkhAddressType.p2pkhwt) {
          address = P2pkhAddress.fromHash160(
              addrHash: address.addressProgram, type: P2pkhAddressType.p2pkhwt);
        }
        break;
      case BipProposal.bip49:
        switch (addressType) {
          case P2shAddressType.p2wshInP2sh:
            address = bitcoinPublicKey.toP2wshInP2sh();
            break;
          case P2shAddressType.p2wpkhInP2sh:
            address = bitcoinPublicKey.toP2wpkhInP2sh();
            break;
          case P2shAddressType.p2pkhInP2sh:
          case P2shAddressType.p2pkhInP2sh32:
          case P2shAddressType.p2pkhInP2shwt:
          case P2shAddressType.p2pkhInP2sh32wt:
            address = bitcoinPublicKey.toP2pkhInP2sh(
                useBCHP2sh32: addressType == P2shAddressType.p2pkhInP2sh32 ||
                    addressType == P2shAddressType.p2pkhInP2sh32wt,
                mode: keyType);
            if (addressType == P2shAddressType.p2pkhInP2shwt ||
                addressType == P2shAddressType.p2pkhInP2sh32wt) {
              address = P2shAddress.fromHash160(
                  addrHash: address.addressProgram, type: addressType.cast());
            }
            break;
          case P2shAddressType.p2pkInP2sh:
          case P2shAddressType.p2pkInP2sh32:
          case P2shAddressType.p2pkInP2shwt:
          case P2shAddressType.p2pkInP2sh32wt:
            address = bitcoinPublicKey.toP2pkInP2sh(
                useBCHP2sh32: addressType == P2shAddressType.p2pkInP2sh32 ||
                    addressType == P2shAddressType.p2pkInP2sh32wt,
                mode: keyType);
            if (addressType == P2shAddressType.p2pkInP2shwt ||
                addressType == P2shAddressType.p2pkInP2sh32wt) {
              address = P2shAddress.fromHash160(
                  addrHash: address.addressProgram, type: addressType.cast());
            }
            break;
          default:
            throw WalletExceptionConst.invalidBitcoinAddressType;
        }
        break;
      case BipProposal.bip84:
        if (addressType == SegwitAddressType.p2wsh) {
          address = bitcoinPublicKey.toP2wshAddress();
        } else {
          address = bitcoinPublicKey.toSegwitAddress();
        }

        break;
      default:
        address = bitcoinPublicKey.toTaprootAddress();
        break;
    }

    if (address.type != addressType) {
      throw WalletExceptionConst.invalidBitcoinAddressType;
    }

    return address;
  }

  static BitcoinBaseAddress toBitcoinAddressFromType(
      {required String bitcoinAddress,
      required BitcoinAddressType addressType,
      required WalletBitcoinNetwork network}) {
    BitcoinBaseAddress address;
    final bitcoinNetwork = network.coinParam.transacationNetwork;
    if (addressType.isP2sh) {
      return P2shAddress.fromAddress(
          address: bitcoinAddress,
          network: bitcoinNetwork,
          type: addressType.cast());
    }
    switch (addressType) {
      case P2pkhAddressType.p2pkh:
      case P2pkhAddressType.p2pkhwt:
        address = P2pkhAddress.fromAddress(
            address: bitcoinAddress, network: bitcoinNetwork);
        break;
      case PubKeyAddressType.p2pk:
        final bitcoinPublicKey = ECPublic.fromHex(bitcoinAddress);
        address = P2pkAddress(publicKey: bitcoinPublicKey.toHex());
      case SegwitAddressType.p2wpkh:
        address = P2wpkhAddress.fromAddress(
            address: bitcoinAddress, network: bitcoinNetwork);
        break;
      case SegwitAddressType.p2tr:
        address = P2trAddress.fromAddress(
            address: bitcoinAddress, network: bitcoinNetwork);
        break;
      case SegwitAddressType.p2wsh:
        address = P2wshAddress.fromAddress(
            address: bitcoinAddress, network: bitcoinNetwork);
        break;
      default:
        throw UnimplementedError("invalid address types");
    }
    return address;
  }

  static BitcoinBaseAddress? validateBitcoinNetwork(
      String address, WalletBitcoinNetwork network) {
    return MethodUtils.nullOnException(() {
      return toBitcoinAddress(address, network.coinParam.transacationNetwork);
    });
  }

  static Object? validateNetworkAddress(
      String? address, WalletNetwork network) {
    if (address == null) return null;
    const int minumumAddressLength = 32;
    if (address.length < minumumAddressLength) return null;
    return validateBitcoinNetwork(address, network.toNetwork());
  }

  static bool isValidNetworkAddress(String? address, WalletNetwork network) {
    return validateNetworkAddress(address, network) != null;
  }

  static List<Bip32KeyIndex> praseBip32Path(String path) {
    return Bip32PathParser.parse(path).elems;
  }
}
