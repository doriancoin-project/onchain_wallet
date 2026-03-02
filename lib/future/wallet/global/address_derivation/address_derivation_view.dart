import 'package:blockchain_utils/bip/bip/conf/core/coins.dart';
import 'package:flutter/material.dart';
import 'package:on_chain_wallet/app/core.dart';
import 'package:on_chain_wallet/crypto/keys/access/crypto_keys/crypto_keys.dart';
import 'package:on_chain_wallet/crypto/types/networks.dart';
import 'package:on_chain_wallet/future/future.dart';
import 'package:on_chain_wallet/future/router/page_router.dart';
import 'package:on_chain_wallet/future/state_managment/state_managment.dart';
import 'package:on_chain_wallet/future/wallet/security/pages/accsess_wallet.dart';
import 'package:on_chain_wallet/wallet/wallet.dart';

class NetworkGenericAddressDerivationView extends StatelessWidget {
  const NetworkGenericAddressDerivationView({super.key});

  @override
  Widget build(BuildContext context) {
    final Chain chain = context.getArgruments();
    return AccessWalletView<WalletCredentialResponseLogin,
            WalletCredentialLogin>(
        request: WalletCredentialLogin.instance,
        onAccsess: (credential) {
          return NetworkAccountControllerView<NetworkClient?, ChainAccount?,
              Chain>(
            account: chain,
            initAccount: true,
            childBulder: (wallet, account, client, address, onAccountChanged) {
              return _NetworkGenericAddressDerivationView(account);
            },
            addressRequired: false,
            clientRequired: false,
          );
        },
        title: "setup_address".tr,
        subtitle: PageTitleSubtitle(
            title: "unlock_wallet".tr, body: Text("unlock_access_desc".tr)));
  }
}

enum _SetupAddressPage { desc, generate }

class _NetworkGenericAddressDerivationView extends StatefulWidget {
  const _NetworkGenericAddressDerivationView(this.chain);
  final Chain chain;
  @override
  State<_NetworkGenericAddressDerivationView> createState() =>
      _NetworkGenericAddressDerivationViewState();
}

class _NetworkGenericAddressDerivationViewState
    extends State<_NetworkGenericAddressDerivationView>
    with SafeState<_NetworkGenericAddressDerivationView> {
  bool isSimpleDerivation = false;
  bool supportMultisig = false;
  bool enableMultisig = false;

  NetworkType get type => widget.chain.network.type;
  _SetupAddressPage page = _SetupAddressPage.desc;
  String? multiSigPage;
  NetworkType? networkPage;

  static NewAccountParams getnerateAccoutParams(
      Bip32AddressIndex keyIndex, WalletNetwork network, CryptoCoins coin) {
    switch (network.type) {
      default:
        throw UnimplementedError();
    }
  }

  Future<void> generateAddress(AddressDerivationController controller) async {
    final keyIndex = await controller.getCoin(
        context: context,
        seedGeneration: SeedTypes.bip39,
        selectedCoins: controller.network.coins.first);
    if (keyIndex == null || !keyIndex.isBip32) return;
    final newAccountParam = getnerateAccoutParams(
        keyIndex.cast(), controller.network, controller.coin);
    controller.generateAddress(newAccountParam);
  }

  void onTapGenerateAddress(AddressDerivationController controller) {
    switch (type) {
      case NetworkType.bitcoinAndForked:
      case NetworkType.bitcoinCash:
        networkPage = type;
        break;
      default:
        if (isSimpleDerivation) {
          generateAddress(controller);
        } else {
          page = _SetupAddressPage.generate;
        }
        break;
    }
    updateState();
  }

  @override
  void onInitOnce() {
    super.onInitOnce();
    multiSigPage =
        PageRouter.multisigAddressDerivation(widget.chain.network.type);
    supportMultisig = multiSigPage != null;
    switch (type) {
      case NetworkType.bitcoinAndForked:
      case NetworkType.bitcoinCash:
        enableMultisig = supportMultisig && true;
        break;
      default:
        break;
    }
    enableMultisig |= supportMultisig && widget.chain.haveAddress;
  }

  @override
  Widget build(BuildContext context) {
    final wallet = context.watch<WalletProvider>(StateConst.main);
    return APPAnimatedSwitcher(enable: networkPage, widgets: {
      NetworkType.bitcoinAndForked: (context) =>
          SetupBitcoinAddressView(widget.chain.cast()),
      NetworkType.bitcoinCash: (context) =>
          SetupBitcoinAddressView(widget.chain.cast()),
      null: (context) => StateBuilder<AddressDerivationController>(
            controller: () => AddressDerivationController(
                chain: widget.chain, wallet: wallet),
            repositoryId: StateConst.addressDerivation,
            builder: (controller) => StreamPageProgress(
              controller: controller.pageProgressKey,
              // backToIdle: APPConst.oneSecoundDuration,
              // initialStatus: PageProgressStatus.idle,
              builder: (c) => Center(
                child: CustomScrollView(
                  shrinkWrap: true,
                  slivers: [
                    WidgetConstant.sliverPaddingVertial20,
                    SliverToBoxAdapter(
                        child: ConstraintsBoxView(
                      padding: WidgetConstant.paddingHorizontal20,
                      child: Form(
                          key: controller.form,
                          child: APPAnimated(
                            isActive: page == _SetupAddressPage.desc,
                            onDeactive: (context) =>
                                SetupGenericAddressView(controller: controller),
                            onActive: (context) => Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                PageTitleSubtitle(
                                    title: "setup_network_address"
                                        .tr
                                        .replaceOne(controller
                                            .network.coinParam.token.name),
                                    body: LargeTextView(
                                      [
                                        "disable_standard_derivation_desc".tr,
                                        "setup_address_derivation_keys_desc".tr,
                                        "please_following_steps_to_generate_address"
                                            .tr,
                                        "custom_path_derivation_desc".tr,
                                        ],
                                    )),
                                AppListTile(
                                  title: Text("generate_address".tr),
                                  subtitle: Text("generate_address_desc".tr),
                                  trailing: const Icon(Icons.arrow_forward),
                                  leading: const Icon(Icons.account_box),
                                  onTap: () {
                                    onTapGenerateAddress(controller);
                                  },
                                ),
                                IgnorePointer(
                                  ignoring: !enableMultisig,
                                  child: Opacity(
                                    opacity: enableMultisig
                                        ? 1
                                        : APPConst.disabledOpacity,
                                    child: AppListTile(
                                      trailing: const Icon(Icons.arrow_forward),
                                      title: Text("multi_sig_addr".tr),
                                      leading: const Icon(
                                          Icons.switch_account_sharp),
                                      subtitle: Text(supportMultisig
                                          ? enableMultisig
                                              ? "establishing_multi_sig_addr".tr
                                              : "at_least_one_account_required"
                                                  .tr
                                          : "unsuported_feature".tr),
                                      onTap: () {
                                        context.offTo(multiSigPage!,
                                            argruments: widget.chain);
                                      },
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          )),
                    ))
                  ],
                ),
              ),
            ),
          )
    });
  }
}
