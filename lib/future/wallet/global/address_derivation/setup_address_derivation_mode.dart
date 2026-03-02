import 'package:blockchain_utils/blockchain_utils.dart';
import 'package:flutter/material.dart';
import 'package:on_chain_wallet/app/core.dart';
import 'package:on_chain_wallet/future/state_managment/state_managment.dart';
import 'package:on_chain_wallet/future/wallet/global/global.dart';
import 'package:on_chain_wallet/future/widgets/custom_widgets.dart';
import 'package:on_chain_wallet/wallet/wallet.dart' show Chain, WalletNetwork;
import 'package:on_chain_wallet/crypto/worker.dart';

typedef _OnGenerateDerivation = Future<AddressDerivationIndex?> Function();
typedef ADDRESSDNEXTDERIVATION = AddressDerivationIndex Function(
    {required CryptoCoins<CoinConfig> coin,
    required SeedTypes seedGeneration,
    required int? subId});

///     "setup_derivation".tr,
class SetupDerivationModeView extends StatefulWidget {
  final CryptoCoins coin;
  final Chain chainAccout;
  final AddressDerivationIndex? defaultDerivation;
  final SeedTypes seedGenerationType;
  final ScrollController controller;
  final ADDRESSDNEXTDERIVATION? nextAddressDerivationBuilder;
  const SetupDerivationModeView(
      {super.key,
      required this.coin,
      required this.chainAccout,
      this.defaultDerivation,
      required this.seedGenerationType,
      required this.controller,
      this.nextAddressDerivationBuilder});

  @override
  State<SetupDerivationModeView> createState() =>
      _SetupDerivationModeView2State();
}

class _SetupDerivationModeView2State extends State<SetupDerivationModeView>
    with SafeState<SetupDerivationModeView> {
  final StreamPageProgressController controller =
      StreamPageProgressController(initialStatus: StreamWidgetStatus.progress);
  List<ViewDerivationKeyModel> derivationKeys = [];
  late ViewDerivationKeyModel derivationKey;
  late AddressDerivationIndex nextKeyIndex;
  AddressDerivationIndex? customKeyIndex;
  WalletNetwork get network => chainAccount.network;
  Chain get chainAccount => widget.chainAccout;
  late CryptoCoins coin = widget.coin;
  late final bool useByronLegacyDeriavation =
      coin.proposal == CustomProposal.cip0019;
  List<EncryptedCustomKey> customKeys = [];
  bool get derivationStandard => customKeyIndex == null;

  Map<ViewDerivationKeyModel, Widget> items = {};

  AddressDerivationIndex getNextDerivation() {
    final defaultP = widget.defaultDerivation;
    if (defaultP != null && defaultP.subId == derivationKey.subId) {
      return defaultP;
    }
    final builder =
        widget.nextAddressDerivationBuilder ?? chainAccount.nextDerive;
    final nextDerive = builder(
        coin: coin,
        seedGeneration: widget.seedGenerationType,
        subId: derivationKey.subId);
    if (derivationKey.subId != null) {
      return nextDerive.asSubWalletKey(derivationKey.subId!);
    }
    return nextDerive;
  }

  final generateAddressKey = GlobalKey();

  void onChangeDerivationKey(ViewDerivationKeyModel? key) {
    if (key == null || key == derivationKey) return;
    customKeyIndex = null;
    derivationKey = key;

    if (key.allowDerivation) {
      nextKeyIndex = getNextDerivation();
    }
    updateState();
  }

  Future<void> onChangeDerivation(
      _OnGenerateDerivation onGenerateDerivation) async {
    assert(derivationKey.allowDerivation);
    if (derivationStandard) {
      customKeyIndex = await onGenerateDerivation();
    } else {
      customKeyIndex = null;
    }
    updateState();
  }

  void onSubmit() {
    final key = derivationKey.toDerivationIndex(
        coin: coin,
        customKeyIndex: customKeyIndex,
        defaultKeyIndex: nextKeyIndex,
        seedGeneration: widget.seedGenerationType);
    assert(derivationKey.importedKey == key.importedKeyId);
    assert(derivationKey.subId == key.subId);
    assert(widget.seedGenerationType == key.seedGeneration);
    context.pop(key);
  }

  void buildKeys() {
    final wallet = context.wallet.wallet.wallet;
    final mainWalletDerivation = ViewDerivationKeyModel(
        name: wallet.name,
        created: wallet.created,
        allowDerivation: true,
        icon: Icon(Icons.account_balance_wallet_rounded));
    final List<ViewDerivationKeyModel> keys = [mainWalletDerivation];
    final sWIcon = Icon(Icons.account_balance_wallet_outlined);
    for (final i in wallet.subWallets) {
      switch (i.walletType) {
        case SubWalletType.bip39:
          keys.add(ViewDerivationKeyModel(
              name: i.name,
              created: i.created,
              subId: i.id,
              allowDerivation: true,
              icon: sWIcon));
          break;
        case SubWalletType.monero:
          break;
        case SubWalletType.ton:
          break;
      }
    }

    for (final i in customKeys) {
      keys.add(ViewDerivationKeyModel(
          name: i.name ?? i.publicKey,
          created: i.created,
          importedKey: i.id,
          allowDerivation: false,
          icon: Icon(Icons.key)));
    }

    derivationKeys = keys;
    derivationKey = keys.firstWhere(
        (e) => e.subId == widget.defaultDerivation?.subId,
        orElse: () => mainWalletDerivation);
    nextKeyIndex = getNextDerivation();
  }

  Map<ViewDerivationKeyModel, Widget> buildKeysItems() {
    return {for (final i in derivationKeys) i: ViewDerivationKeyModelWidget(i)};
  }

  Future<void> init() async {
    customKeys = await context.wallet.wallet.getCustomKeysForCoin(coin);
    buildKeys();
    items = buildKeysItems();

    controller.backToIdle();
    MethodUtils.after(() async {
      generateAddressKey.ensureKeyVisible();
    }, duration: APPConst.animationDuraion);
  }

  @override
  void onInitOnce() {
    super.onInitOnce();
    init();
  }

  @override
  void safeDispose() {
    super.safeDispose();
    controller.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("setup_derivation".tr)),
      body: StreamPageProgress(
        controller: controller,
        builder: (context) => CustomScrollView(
          controller: widget.controller,
          slivers: [
            SliverConstraintsBoxView(
              padding: WidgetConstant.padding20,
              sliver: SliverToBoxAdapter(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    AlertTextContainer(
                        message: "custom_key_derivation_desc".tr,
                        enableTap: false),
                    WidgetConstant.height20,
                    Text("derivation_path".tr,
                        style: context.textTheme.titleMedium),
                    WidgetConstant.height8,
                    ContainerWithBorder(
                        onRemove: derivationKey.allowDerivation
                            ? () {
                                onChangeDerivation(
                                  () async {
                                    if (useByronLegacyDeriavation) {
                                      return context.openSliverBottomSheet<
                                              Bip32AddressIndex>(
                                          "key_derivation".tr,
                                          child: ByronLegacyKeyDerivationView(
                                              coin: coin,
                                              curve: coin.conf.type));
                                    }
                                    return context
                                        .openMaxExtendSliverBottomSheet<
                                                AddressDerivationIndex>(
                                            "key_derivation".tr,
                                            child: Bip32KeyDerivationView(
                                                coin: coin,
                                                defaultPath:
                                                    nextKeyIndex.hdPath,
                                                seedGeneration:
                                                    widget.seedGenerationType),
                                            centerContent: false);
                                  },
                                );
                              }
                            : null,
                        onRemoveIcon: ConditionalWidgets<bool>(
                            enable: derivationStandard,
                            widgets: {
                              true: (e) => Icon(Icons.edit,
                                  color: context.colors.onPrimaryContainer),
                              false: (e) => Icon(Icons.remove_circle,
                                  color: context.colors.onPrimaryContainer)
                            }),
                        child: APPAnimated(
                          isActive: derivationKey.allowDerivation,
                          onActive: (context) => FullWidthWrapper(
                            key: ValueKey(customKeyIndex ?? nextKeyIndex),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                    derivationStandard
                                        ? "standard_derivation".tr
                                        : "custom_derivation".tr,
                                    style: context.textTheme.labelLarge),
                                AddressDrivationInfo(
                                    customKeyIndex ?? nextKeyIndex)
                              ],
                            ),
                          ),
                          onDeactive: (context) => FullWidthWrapper(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text("non_derivation".tr,
                                    style: context.textTheme.labelLarge),
                                ErrorTextContainer(
                                    error: "key_derivation_disabled_desc".tr,
                                    showErrorIcon: false)
                              ],
                            ),
                          ),
                        )),
                    WidgetConstant.height20,
                    Text("select_creation_type".tr,
                        style: context.textTheme.titleMedium),
                    Text("generate_from_hd_wallet".tr),
                    WidgetConstant.height8,
                    AppDropDownBottom(
                        items: items,
                        value: derivationKey,
                        onChanged: onChangeDerivationKey,
                        isDense: false,
                        isExpanded: true),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        FixedElevatedButton(
                            key: generateAddressKey,
                            padding: WidgetConstant.paddingVertical40,
                            onPressed: onSubmit,
                            child: Text("generate_address".tr))
                      ],
                    )
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class ViewDerivationKeyModelWidget extends StatelessWidget {
  final ViewDerivationKeyModel derivationKey;
  const ViewDerivationKeyModelWidget(this.derivationKey, {super.key});

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      derivationKey.icon,
      WidgetConstant.width8,
      Expanded(
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(derivationKey.name, style: context.textTheme.bodyMedium),
        Text(derivationKey.createdAt, style: context.textTheme.bodySmall)
      ]))
    ]);
  }
}

class ViewDerivationKeyModel {
  final String name;
  final String createdAt;
  final String? importedKey;
  final int? subId;
  final bool allowDerivation;
  final Icon icon;
  bool get isMainWallet => subId == null && importedKey == null;
  bool get isSubWallet => subId != null;

  AddressDerivationIndex toDerivationIndex(
      {required AddressDerivationIndex defaultKeyIndex,
      required AddressDerivationIndex? customKeyIndex,
      required CryptoCoins coin,
      required SeedTypes seedGeneration}) {
    if (!allowDerivation) {
      final keyIndex = switch (coin.proposal) {
        SubstratePropoosal.substrate =>
          SubstrateAddressIndex(currencyCoin: coin as SubstrateCoins),
        _ =>
          Bip32AddressIndex(currencyCoin: coin, seedGeneration: seedGeneration)
      };
      if (importedKey != null) {
        return keyIndex.asImportedKey(importedKey!);
      }
      return keyIndex.asSubWalletKey(subId!);
    }
    final keyIndex = customKeyIndex ?? defaultKeyIndex;
    if (subId != null) return keyIndex.asSubWalletKey(subId!);
    return keyIndex;
  }

  ViewDerivationKeyModel(
      {required this.name,
      required DateTime created,
      required this.allowDerivation,
      required this.icon,
      this.importedKey,
      this.subId})
      : createdAt = created.toDateAndTime();
}
