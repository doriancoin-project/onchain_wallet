import 'package:flutter/material.dart';
import 'package:on_chain_wallet/crypto/types/networks.dart';
import 'package:on_chain_wallet/future/future.dart';
import 'package:on_chain_wallet/future/wallet/transaction/pages/transaction_state_builder.dart';
import 'package:on_chain_wallet/wallet/models/network/core/network.dart';

class PageRouter {
  ///TransactionStateBuilder
  static const String transaction = "/transaction";

  static const String manageTokens = "/account/tokens";

  /// bitcoin casah
  static const String bitcoinCashTransaction = "/bitcoincash/transaction";

  static const String bitcoinTransaction = "/bitcoin/transaction";
  static const String contacts = "setting/contacts";

  static const String setupGenericAddress = "/networks/setup_address";

  static const String setupBitcoinMultsig = "/bitcoin/setup_multisig_address";

  static const String bitcoinMultisigAccountInfo =
      "/bitcoin/multisig_account_info";
  static const String bitcoinCashMultisigAccountInfo =
      "/bitcoinCash/multisig_account_info";
  static const String createWallet = "/create_wallet";
  static const String createSubWallet = "/create_sub_wallet";
  static const String setup = "/setup";
  static const String home = "/";

  static const String setting = "/setting";
  static const String updateSetting = "/setting/update";

  /// acccount
  static const String removeAccount = "/account/remove";
  static const String importAccount = "/account/import";
  static const String showPublicKey = "account/public_key";

  /// security
  static const String changePassword = "/security/password";
  static const String eraswWallet = "/security/erase";
  static const String backupWallet = "/security/backup";
  static const String exportPrivateKey = "/security/privateKey";
  static const String manageImportedKey = "/security/manageKeys";
  static const String exportSeed = "/security/seed";

  static const String updateElectrumProviders = "/networks/bitcoin/providers";

  static const String updateNetwork = "/networks/update";

  static const String barcodeScanner = "barcode_scanner";

  /// WalletConnectView
  /// web3
  static const String web3Request = "web3/";
  static const String walletConnect = "web3/wallet_connect";
  static const String manageDaps = "web3/manage_dapps";
  static const String walletConnectPairing = "web3/wallet_connect/pairing";
  static const String web3Bitcoin = "web3/bitcoin";
  static const String web3Permission_ = "web3/permission";
  static const String web3Global = "web3/connect";
  static const String web3WalletConnect = "web3/wallet_connect";

  static const String webview = "web/";
  static const String webviewMenu = "web/menu";
  static const String webviewRemoveHistory = "web/history";
  static const String webViewSearch = "webview/search";
  static const String settingMenu = "setting/menu";

  static const String publicKeyDeration = "account/public_key_derivation";

  static Widget _page(String? name) {
    switch (name) {
      case web3Request:
        return const Web3StatePageBuilder();
      case manageTokens:
        return const ManageAccountTokenView();
      case transaction:
        return const TransactionStateBuilder();
      case setupBitcoinMultsig:
        return const SetupBitcoinMultiSigAddressView();
      case exportSeed:
        return const ExportSeedView();
      case changePassword:
        return const ChangeWalletPasswordView();
      case eraswWallet:
        return const EraseWalletView();
      case exportPrivateKey:
        return const AccountPrivteKeyView();
      case removeAccount:
        return const DeleteAccountView();
      case importAccount:
        return const ImportAccountView();
      case setting:
        return const AppSettingView();
      case updateSetting:
        return const UpdateWalletSettingView();
      case backupWallet:
        return const BackupWalletView();
      case manageImportedKey:
        return const ManageImportedKeysView();
      case setupGenericAddress:
        return const NetworkGenericAddressDerivationView();
      case updateElectrumProviders:
        return const ImportElectrumProviderView();
      case contacts:
        return const ManageAccountContactsView();
      case showPublicKey:
        return const AccountPublicKeyView();
      case createWallet:
        return const WalletSetupPageWidget();
      case createSubWallet:
        return const SubWalletSetupPageView();
      case barcodeScanner:
        return const BarcodeScannerView();
      case walletConnect:
        return WalletConnectView();
      case manageDaps:
        return ManageWeb3DapssView();
      case updateNetwork:
        return const UpdateNetworkView();
      case bitcoinMultisigAccountInfo:
      case bitcoinCashMultisigAccountInfo:
        return const BitcoinMultisigAccountInfoView();
      case web3Global:
        return const GlobalWeb3FieldsView();
      default:
        return const WalletScreen();
    }
  }

  static Route<dynamic> onGenerateRoute(RouteSettings settings) {
    return PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) {
          return MaterialPageView(child: _page(settings.name));
        },
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(opacity: animation, child: child);
        },
        transitionDuration: const Duration(milliseconds: 300),
        settings: settings,
        reverseTransitionDuration: const Duration(milliseconds: 300),
        allowSnapshotting: false,
        fullscreenDialog: false,
        opaque: false);
  }

  static String updateProvider(WalletNetwork network) {
    switch (network.type) {
      case NetworkType.bitcoinAndForked:
      case NetworkType.bitcoinCash:
        return updateElectrumProviders;
      default:
        throw UnsupportedError("edit provider unsuported.");
    }
  }

  static String? web3Page(WalletNetwork network) {
    return web3Request;
  }

  static String? importNetwork(NetworkType type) {
    switch (type) {
      default:
        return null;
    }
  }

  static String? multisigAccountInfo(NetworkType type) {
    switch (type) {
      case NetworkType.bitcoinAndForked:
        return bitcoinMultisigAccountInfo;
      case NetworkType.bitcoinCash:
        return bitcoinCashMultisigAccountInfo;
      default:
        return null;
    }
  }

  static String? multisigAddressDerivation(NetworkType type) {
    switch (type) {
      case NetworkType.bitcoinAndForked:
      case NetworkType.bitcoinCash:
        return setupBitcoinMultsig;
      default:
        return null;
    }
  }

  static String? networkSettings(WalletNetwork network) {
    switch (network.type) {
      default:
        return null;
    }
  }
}
