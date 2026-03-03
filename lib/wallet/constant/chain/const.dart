import 'package:bitcoin_base/bitcoin_base.dart';
import 'package:blockchain_utils/bip/bip.dart';
import 'package:blockchain_utils/utils/string/string.dart';
import 'package:on_chain_wallet/app/core.dart';
import 'package:on_chain_wallet/crypto/doriancoin/doriancoin.dart';
import 'package:on_chain_wallet/crypto/types/networks.dart';
import 'package:on_chain_wallet/wallet/constant/constant.dart';
import 'package:on_chain_wallet/wallet/models/models.dart';

class _DefaultAppCoins {
  static final BitcoinParams doriancoinMainnet = BitcoinParams(
    transacationNetwork: DoriancoinNetwork.mainnet,
    token: Token(
      name: "Doriancoin",
      symbol: "DSV",
      decimal: 8,
      assetLogo: APPConst.dsv,
    ),
  );
  static final BitcoinParams doriancoinTestnet = BitcoinParams(
    transacationNetwork: DoriancoinNetwork.testnet,
    token: Token(
      name: "Doriancoin testnet",
      symbol: "tDSV",
      decimal: 8,
      assetLogo: APPConst.dsv,
    ),
  );

  static const Map<int, String> defaultChainGenesis = {
    0: "d21da25e277bd20b7456087d69c5fee2ebc6091b410271b5cb0623c7d1e7d1b9",
    1: "70776946e1e0a4d50e5e2baa3c0f678f5aa8b5e73c1e0a37d4b1a1b85a1f5c2d",
  };

  static const Map<int, String> addressExplorer = {
    0: "https://blocks.doriancoin.com/address/#address",
    1: "https://blocks.doriancoin.com/address/#address",
  };

  static const Map<int, String> txExplorer = {
    0: "https://blocks.doriancoin.com/tx/#txid",
    1: "https://blocks.doriancoin.com/tx/#txid",
  };
}

class ChainConst {
  static const int maxNetworkId = 10000 - 1;

  static const int importedNetworkStartId = 2000;
  static const int maxAccountTokens = 1000;
  static final Map<int, WalletNetwork> defaultCoins =
      Map<int, WalletNetwork>.unmodifiable({
    0: WalletBitcoinNetwork(0, _DefaultAppCoins.doriancoinMainnet),
    1: WalletBitcoinNetwork(1, _DefaultAppCoins.doriancoinTestnet),
  });

  static WalletNetwork updateNetwork({int? networkId, WalletNetwork? network}) {
    if (networkId == null || network != null && networkId != network.value) {
      throw WalletExceptionConst.networkDoesNotExist;
    }
    if (!defaultCoins.containsKey(networkId)) {
      if (network == null) {
        throw WalletExceptionConst.networkDoesNotExist;
      }
      return network;
    }
    final WalletNetwork defaultNetwork = defaultCoins[networkId]!;
    if (network == null) return defaultNetwork;
    return defaultNetwork.copyWith(
      coinParam: defaultNetwork.coinParam.updateParams(
        token: network.coinParam.token
            .copyWith(assetLogo: defaultNetwork.coinParam.token.assetLogo),
        addressExplorer: network.coinParam.addressExplorer,
        transactionExplorer: network.coinParam.transactionExplorer,
      ),
    );
  }

  static List<String> services(WalletNetwork network) {
    return ["services", "activity"];
  }

  static String getDefaultGenesisBlock(int value) {
    final genesis = _DefaultAppCoins.defaultChainGenesis[value];
    if (genesis == null) {
      throw WalletExceptionConst.networkDoesNotExist;
    }
    return genesis;
  }

  static String buildCaip2(NetworkType type, String identifier) {
    String part = identifier;
    switch (type) {
      case NetworkType.bitcoinAndForked:
        if (!StringUtils.isHexBytes(part)) {
          throw AppCryptoExceptionConst.invalidHexBytes;
        }
        part = StringUtils.strip0x(identifier.toLowerCase()).substring(0, 32);
        break;
      default:
    }
    return "${type.caip2}:$part";
  }

  static String? getAddressExplorer(int value) {
    return _DefaultAppCoins.addressExplorer[value];
  }

  static String? getTxExplorer(int value) {
    return _DefaultAppCoins.txExplorer[value];
  }
}
