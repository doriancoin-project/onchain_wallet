part of 'package:on_chain_wallet/wallet/chain/chain/chain.dart';

class BitcoinNetworkController extends NetworkController<
    IBitcoinAddress,
    BitcoinChain,
    Web3BitcoinChainAccount,
    Web3InternalDefaultChain,
    ChainConfig> {
  BitcoinNetworkController({super.networks, required super.id})
      : super(type: NetworkType.bitcoinAndForked);

  @override
  Future<Web3BitcoinChainAuthenticated> createWeb3ChainAuthenticated(
    Web3ApplicationAuthentication app,
  ) async {
    final internalNetwork = await _getWeb3InternalChainAuthenticated(app);
    final web3Networks = _networks.values
        .map((e) => Web3BitcoinChainIdnetifier(
            id: e.network.value,
            wsIdentifier: e.network.wsIdentifier,
            caip2: e.network.caip,
            network: e.network.coinParam.transacationNetwork))
        .toList();
    List<Web3BitcoinChainAccount> web3Accounts = [];
    for (final i in internalNetwork.networks) {
      final network = _networks[i.networkId];
      if (network == null) continue;
      final networkAddresses = await network.getAccountAddresses();
      final List<IBitcoinAddress> addresses = [];
      for (final a in i.accounts) {
        final address = networkAddresses.firstWhereOrNull(
            (e) => e.identifier == a.identifier && e.keyIndex == a.keyIndex);
        if (address == null) continue;
        addresses.add(address);
      }
      final defaultAddress = addresses.firstWhereOrNull((e) =>
              e.identifier == i.defaultAccount?.identifier &&
              e.keyIndex == i.defaultAccount?.keyIndex) ??
          addresses.firstOrNull;
      web3Accounts.addAll(addresses.map((e) =>
          Web3BitcoinChainAccount.fromChainAccount(
              address: e,
              network: network.network,
              isDefault: e == defaultAddress)));
    }
    return Web3BitcoinChainAuthenticated(
        accounts: web3Accounts,
        currentNetwork: web3Networks
            .firstWhere((e) => e.id == internalNetwork.defaultChain),
        networks: web3Networks);
  }
}
