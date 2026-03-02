import 'package:flutter/material.dart';

import 'package:on_chain_wallet/app/core.dart' show APPConst;
import 'package:on_chain_wallet/future/state_managment/state_managment.dart';
import 'package:on_chain_wallet/future/wallet/global/pages/address_details.dart';
import 'package:on_chain_wallet/future/wallet/security/pages/accsess_wallet.dart';
import 'package:on_chain_wallet/future/widgets/custom_widgets.dart';
import 'package:on_chain_wallet/wallet/wallet.dart';
import 'package:on_chain_wallet/crypto/keys/keys.dart';
import 'package:on_chain_wallet/crypto/types/networks.dart';


class AccountPublicKeyView extends StatelessWidget {
  const AccountPublicKeyView({super.key});

  @override
  Widget build(BuildContext context) {
    final ChainAccount account = context.getArgruments();
    return AccessWalletView<WalletCredentialResponseLogin,
            WalletCredentialLogin>(
        request: WalletCredentialLogin.instance,
        onAccsess: (credential) => _BipAccountPublicKey(account: account),
        title: "public_key".tr,
        subtitle: PageTitleSubtitle(
            title: "unlock_wallet".tr, body: Text("unlock_access_desc".tr)));
  }
}

class _BipAccountPublicKey extends StatefulWidget {
  const _BipAccountPublicKey({required this.account});
  final ChainAccount account;
  @override
  State<_BipAccountPublicKey> createState() => __BipAccountPublicKeyState();
}

class __BipAccountPublicKeyState extends State<_BipAccountPublicKey>
    with SafeState<_BipAccountPublicKey> {
  final List<PublicKeyDerivationResult> pubKeys = [];
  bool get hasMultipleKey => pubKeys.length > 1;
  late PublicKeyDerivationResult publicKey;
  String? keyInNetwork;
  final StreamPageProgressController progressKey =
      StreamPageProgressController(initialStatus: StreamWidgetStatus.progress);
  late WalletNetwork network;
  String comperessedToNetworkFormat(String key) {
    switch (network.type) {
      default:
        return key;
    }
  }

  Future<void> initPubKey() async {
    final wallet = context.wallet.wallet;
    network = wallet
        .getChains()
        .firstWhere((e) => e.network.value == widget.account.network)
        .network;
    final result = await wallet.getAccountPubKys(account: widget.account);
    if (result.hasResult) {
      pubKeys.addAll(result.result.map((e) => PublicKeyDerivationResult(
          key: e.key,
          index: e.index,
          walletName: e.walletName,
          viewKey: e.viewKey.copyWith(
              comprossed: comperessedToNetworkFormat(e.viewKey.comprossed)))));
      progressKey.success();
      publicKey = pubKeys.first;
    } else {
      if (widget.account.multiSigAccount) {
        progressKey.errorText("unavailable_multi_sig_public_key".tr,
            backToIdle: false);
      } else {
        progressKey.errorText(result.localizationError, backToIdle: false);
      }
    }
  }

  void onChangeKey(PublicKeyDerivationResult? changeKey) {
    if (publicKey == changeKey || changeKey == null) return;
    publicKey = changeKey;
    updateState();
  }

  @override
  void onInitOnce() {
    super.onInitOnce();
    initPubKey();
  }

  @override
  void safeDispose() {
    super.safeDispose();
    progressKey.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return StreamPageProgress(
      controller: progressKey,
      initialWidget:
          ProgressWithTextView(text: "retrieve_account_informations".tr),
      builder: (c) => CustomScrollView(
        shrinkWrap: true,
        slivers: [
          WidgetConstant.sliverPaddingVertial20,
          SliverToBoxAdapter(
            child: ConstraintsBoxView(
              padding: WidgetConstant.paddingHorizontal20,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  WidgetConstant.height20,
                  _AddressInfo(widget.account),
                  if (hasMultipleKey) ...[
                    Text("public_keys".tr,
                        style: context.textTheme.titleMedium),
                    Text("switch_between_keys".tr),
                    WidgetConstant.height8,
                    AppDropDownBottom(
                        onChanged: onChangeKey,
                        items: {
                          for (final i in pubKeys) i: Text(i.viewKey.keyName.tr)
                        },
                        hint: "key_name".tr,
                        value: publicKey),
                    WidgetConstant.height20
                  ],
                  WidgetConstant.sizedBox,
                  AnimatedSwitcher(
                    duration: APPConst.animationDuraion,
                    child: PublicKeysDataView(
                        key: ValueKey(publicKey), publicKey: publicKey),
                  ),
                ],
              ),
            ),
          ),
          WidgetConstant.sliverPaddingVertial40,
        ],
      ),
    );
  }
}

class PublicKeysDataView extends StatelessWidget {
  final PublicKeyDerivationResult publicKey;
  final Color? color;
  final Color? reverse;
  const PublicKeysDataView(
      {super.key, required this.publicKey, this.color, this.reverse});
  PublicKeysView get viewKey => publicKey.viewKey;
  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text("derivation_path".tr, style: context.textTheme.titleMedium),
        WidgetConstant.height8,
        ContainerWithBorder(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          ConditionalWidget(
            enable: publicKey.walletName != null,
            onActive: (context) => Text(publicKey.walletName!),
          ),
          AddressDrivationInfo(publicKey.index,
              color: context.onPrimaryContainer,
              style: context.onPrimaryTextTheme.bodySmall)
        ])),
        WidgetConstant.height20,
        if (viewKey.extendKey != null) ...[
          Text("extended_public_key".tr, style: context.textTheme.titleMedium),
          WidgetConstant.height8,
          SecureContentView(
            content: viewKey.extendKey!,
            isSensitive: false,
          ),
          WidgetConstant.height20,
        ],
        Text("comperessed_public_key".tr, style: context.textTheme.titleMedium),
        WidgetConstant.height8,
        SecureContentView(
          content: viewKey.comprossed,
          isSensitive: false,
        ),
        if (viewKey.uncomprossed != null) ...[
          WidgetConstant.height20,
          Text("uncomperessed_public_key".tr,
              style: context.textTheme.titleMedium),
          WidgetConstant.height8,
          SecureContentView(content: viewKey.uncomprossed!, isSensitive: false),
        ],
      ],
    );
  }
}

class _AddressInfo extends StatelessWidget {
  final ChainAccount account;
  const _AddressInfo(this.account);

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text("address_details".tr, style: context.textTheme.titleMedium),
        WidgetConstant.height8,
        ContainerWithBorder(
          child: CopyableTextWidget(
              text: account.address.toAddress,
              widget: AddressDetailsView(
                  address: account, color: context.onPrimaryContainer)),
        ),
        WidgetConstant.sizedBox,
        WidgetConstant.height20,
      ],
    );
  }
}

