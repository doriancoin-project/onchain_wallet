import 'package:bitcoin_base/bitcoin_base.dart';
import 'doriancoin_network.dart';

class DoriancoinAddress extends BitcoinNetworkAddress<DoriancoinNetwork> {
  const DoriancoinAddress._(
    BitcoinBaseAddress baseAddress,
    String address,
    DoriancoinNetwork network,
  ) : super._(address: address, baseAddress: baseAddress, network: network);

  factory DoriancoinAddress(
    String address, {
    DoriancoinNetwork network = DoriancoinNetwork.mainnet,
  }) {
    return DoriancoinAddress._(
      BitcoinAddressUtils.decodeAddress(address, network),
      address,
      network,
    );
  }

  factory DoriancoinAddress.fromBaseAddress(
    BitcoinBaseAddress address, {
    DoriancoinNetwork network = DoriancoinNetwork.mainnet,
  }) {
    final baseAddress = BitcoinAddressUtils.validateAddress(address, network);
    return DoriancoinAddress._(
      baseAddress,
      baseAddress.toAddress(network),
      network,
    );
  }
}
