import 'package:flutter/material.dart';

import 'package:on_chain_wallet/app/core.dart' show APPConst, MethodUtils;
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
  ICardanoAddress? adaLegacyAddress;
  late WalletNetwork network;
  String comperessedToNetworkFormat(String key) {
    switch (network.type) {
      default:
        return key;
    }
  }

  Future<void> initPubKey() async {
    adaLegacyAddress = isAdaLegacy();
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

  ICardanoAddress? isAdaLegacy() {
    if (widget.account is ICardanoAddress) {
      final account = widget.account.cast<ICardanoAddress>();
      if (account.addressInfo.isLegacy) {
        return account;
      }
    }
    return null;
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
                  _HDPathDetails(byronLegacy: adaLegacyAddress),
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

class _HDPathDetails extends StatelessWidget {
  const _HDPathDetails({this.byronLegacy});
  final ICardanoAddress? byronLegacy;

  @override
  Widget build(BuildContext context) {
    final addressInfo = byronLegacy?.addressInfo as CardanoAddrDetails?;
    if (addressInfo == null) return WidgetConstant.sizedBox;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text("hd_path_key".tr, style: context.textTheme.titleMedium),
        WidgetConstant.height8,
        ContainerWithBorder(
          onRemove: () {},
          onRemoveIcon: CopyTextIcon(
              isSensitive: false, dataToCopy: addressInfo.hdPathKeyHex!),
          child: Text(
            addressInfo.hdPathKeyHex!,
            style: context.onPrimaryTextTheme.bodyMedium,
          ),
        ),
        WidgetConstant.height20
      ],
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
        ConditionalWidget(
            onActive: (context) => _MoneroKeysView(pubKey: viewKey.cast()),
            enable: viewKey.keyType == CryptoPublicKeyDataType.monero)
      ],
    );
  }
}

class _MoneroKeysView extends StatelessWidget {
  final MoneroPublicKeysView pubKey;
  const _MoneroKeysView({required this.pubKey});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        WidgetConstant.height20,
        Text("spend_public_key".tr, style: context.textTheme.titleMedium),
        WidgetConstant.height8,
        SecureContentView(
          content: pubKey.spendPublicKey,
          isSensitive: false,
        ),
        WidgetConstant.height20,
        Text("view_public_key".tr, style: context.textTheme.titleMedium),
        WidgetConstant.height8,
        SecureContentView(
          content: pubKey.viewPublicKey,
          isSensitive: false,
        ),
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
        switch (account.runtimeType) {
          const (IMoneroAddress) => _MoneroAccountInfo(account.cast()),
          const (IXRPAddress) => _XRPAddressInfo(account.cast()),
          const (IStellarAddress) => _StellarAddressInfo(account.cast()),
          const (ITonAddress) => _TonAddressInfo(account.cast()),
          _ => WidgetConstant.sizedBox,
        },
        WidgetConstant.height20,
      ],
    );
  }
}

class _MoneroAccountInfo extends StatelessWidget {
  final IMoneroAddress address;
  const _MoneroAccountInfo(this.address);

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      ConditionalWidget(
          onDeactive: (context) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                WidgetConstant.height20,
                Text("primary_address".tr,
                    style: context.textTheme.titleMedium),
                WidgetConstant.height8,
                ContainerWithBorder(
                    child: CopyableTextWidget(
                        maxLines: 2,
                        text:
                            address.addrDetails.viewKey.primaryAddress.address,
                        color: context.onPrimaryContainer)),
              ],
            );
          },
          onActive: (context) => WidgetConstant.sizedBox,
          enable: address.addrDetails.isPrimary),
      WidgetConstant.height20,
      Text("account_index".tr, style: context.textTheme.titleMedium),
      WidgetConstant.height8,
      ContainerWithBorder(
          child: Text(address.addrDetails.index.major.toString(),
              style: context.onPrimaryTextTheme.bodyMedium)),
      WidgetConstant.height20,
      Text("address_index".tr, style: context.textTheme.titleMedium),
      WidgetConstant.height8,
      ContainerWithBorder(
          child: Text(address.addrDetails.index.minor.toString(),
              style: context.onPrimaryTextTheme.bodyMedium))
    ]);
  }
}

class _XRPAddressInfo extends StatelessWidget {
  final IXRPAddress address;
  const _XRPAddressInfo(this.address);

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      ConditionalWidget(
          onActive: (context) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                WidgetConstant.height20,
                Text("base_address".tr, style: context.textTheme.titleMedium),
                WidgetConstant.height8,
                ContainerWithBorder(
                    child: CopyableTextWidget(
                        text: address.networkAddress.address,
                        color: context.onPrimaryContainer,
                        maxLines: 2)),
                WidgetConstant.height20,
                Text("tag".tr, style: context.textTheme.titleMedium),
                WidgetConstant.height8,
                ContainerWithBorder(
                    child: Text(address.tag?.toString() ?? "",
                        style: context.onPrimaryTextTheme.bodyMedium)),
              ],
            );
          },
          onDeactive: (context) => WidgetConstant.sizedBox,
          enable: address.tag != null)
    ]);
  }
}

class _StellarAddressInfo extends StatelessWidget {
  final IStellarAddress address;
  const _StellarAddressInfo(this.address);

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      ConditionalWidget(
          onActive: (context) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                WidgetConstant.height20,
                Text("base_address".tr, style: context.textTheme.titleMedium),
                WidgetConstant.height8,
                ContainerWithBorder(
                    child: CopyableTextWidget(
                        text: address.networkAddress.baseAddress,
                        color: context.onPrimaryContainer,
                        maxLines: 2)),
                WidgetConstant.height20,
                Text("muxed_id".tr, style: context.textTheme.titleMedium),
                WidgetConstant.height8,
                ContainerWithBorder(
                    child: Text(address.id?.toString() ?? "",
                        style: context.onPrimaryTextTheme.bodyMedium)),
              ],
            );
          },
          onDeactive: (context) => WidgetConstant.sizedBox,
          enable: address.id != null)
    ]);
  }
}

class _TonAddressInfo extends StatelessWidget {
  final ITonAddress address;
  const _TonAddressInfo(this.address);

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      WidgetConstant.height20,
      Text("wallet_version".tr, style: context.textTheme.titleMedium),
      WidgetConstant.height8,
      ContainerWithBorder(
          child: Text(address.context.version.name,
              style: context.onPrimaryTextTheme.bodyMedium)),
      WidgetConstant.height20,
      Text("type".tr, style: context.textTheme.titleMedium),
      WidgetConstant.height8,
      ContainerWithBorder(
          child: ConditionalWidget(
              onDeactive: (context) {
                return Text("non_bouncable".tr,
                    style: context.onPrimaryTextTheme.bodyMedium);
              },
              onActive: (context) {
                return Text("bouncable".tr,
                    style: context.onPrimaryTextTheme.bodyMedium);
              },
              enable: address.context.bouncable)),
      ConditionalWidget(
          onActive: (context) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                WidgetConstant.height20,
                Text("sub_or_wallet_id".tr,
                    style: context.textTheme.titleMedium),
                WidgetConstant.height8,
                ContainerWithBorder(
                  child: Text(address.context.subOrWalletId?.toString() ?? ''),
                ),
              ],
            );
          },
          onDeactive: (context) => WidgetConstant.sizedBox,
          enable: address.context.subOrWalletId != null)
    ]);
  }
}
