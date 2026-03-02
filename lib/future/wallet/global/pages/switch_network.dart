import 'package:blockchain_utils/helper/extensions/extensions.dart';
import 'package:flutter/material.dart';
import 'package:on_chain_wallet/app/core.dart';
import 'package:on_chain_wallet/crypto/types/networks.dart';
import 'package:on_chain_wallet/future/router/page_router.dart';
import 'package:on_chain_wallet/future/state_managment/state_managment.dart';
import 'package:on_chain_wallet/future/wallet/controller/controller.dart';
import 'package:on_chain_wallet/future/widgets/custom_widgets.dart';
import 'package:on_chain_wallet/wallet/wallet.dart';

class SwitchNetworkView extends StatefulWidget {
  const SwitchNetworkView({required this.selectedNetwork, super.key});
  final WalletNetwork selectedNetwork;

  @override
  State<SwitchNetworkView> createState() => _SwitchNetworkViewState();
}

class _SwitchNetworkViewState extends State<SwitchNetworkView>
    with SafeState<SwitchNetworkView> {
  final StreamPageProgressController progressKey =
      StreamPageProgressController(initialStatus: StreamWidgetStatus.progress);
  Map<NetworkType, List<Chain>> allNetworks = {};
  NetworkType currentNetwork = NetworkType.bitcoinAndForked;

  List<Chain> allChains = [];
  late List<Chain> buildedNetwork;
  late WalletProvider wallet;
  List<Chain> filteredNetworks = [];

  bool showTestnet = false;

  void toggleShowTestnet() {
    showTestnet = !showTestnet;
    final setting = wallet.appSetting.walletSetting
        .copyWith(showTestnetNetworks: showTestnet);
    wallet.updateWalletSetting(setting);
    buildChains();
    updateState();
  }

  void initNetwork() {
    wallet = context.watch<WalletProvider>(StateConst.main);
    showTestnet = wallet.appSetting.walletSetting.showTestnetNetworks;
    allChains = wallet.wallet.getChains();
    allNetworks[NetworkType.bitcoinAndForked] =
        allChains.where((e) => e.network.type.isBitcoin).toList();
    currentNetwork = NetworkType.bitcoinAndForked;
    buildChains();
    progressKey.backToIdle();
  }

  void buildChains() {
    buildedNetwork = allNetworks[currentNetwork]!;
    if (!showTestnet) {
      buildedNetwork = buildedNetwork
          .where((e) =>
              e.network.coinParam.chainType.isMainnet ||
              e.network == widget.selectedNetwork)
          .toList();
    }
    filteredNetworks = buildedNetwork.clone();
  }

  @override
  void onInitOnce() {
    super.onInitOnce();
    initNetwork();
  }

  @override
  void safeDispose() {
    allChains = [];
    progressKey.dispose();
    super.safeDispose();
  }

  @override
  Widget build(BuildContext context) {
    return ConstraintsBoxView(
      alignment: Alignment.center,
      maxHeight: APPConst.maxDialogHeight,
      padding: WidgetConstant.padding20,
      maxWidth: APPConst.dialogWidth,
      child: ClipRRect(
        borderRadius: WidgetConstant.border25,
        child: Scaffold(
          appBar: AppBar(
            title: Text("switch_network".tr),
            leading: const SizedBox(),
            leadingWidth: 0,
            actions: [
              TextButton.icon(
                  onPressed: toggleShowTestnet,
                  label: Text('testnets'.tr),
                  icon: APPCheckBox(
                    ignoring: true,
                    value: showTestnet,
                    onChanged: (_) {},
                  )),
              const CloseButton(),
              WidgetConstant.width8
            ],
          ),
          body: StreamPageProgress(
            controller: progressKey,
            builder: (c) => _NetworksView(
                widget.selectedNetwork, filteredNetworks, null),
          ),
        ),
      ),
    );
  }
}

class _NetworksView extends StatelessWidget {
  const _NetworksView(this.selected, this.networks, this.import, {super.key});
  final WalletNetwork selected;
  final List<Chain> networks;
  final NetworkType? import;
  @override
  Widget build(BuildContext context) {
    return CustomScrollView(
      slivers: [
        SliverList.separated(
          itemBuilder: (context, index) {
            final net = networks[index].network;
            final balance = networks[index].totalBalance;
            return Padding(
              padding: WidgetConstant.paddingHorizontal20,
              child: InkWell(
                borderRadius: WidgetConstant.border8,
                onTap: selected == net
                    ? null
                    : () {
                        context.pop(networks[index]);
                      },
                child: Padding(
                  padding: WidgetConstant.padding5,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Column(
                            children: [
                              CircleTokenImageView(net.coinParam.token,
                                  radius: 20),
                              if (net.coinParam.isTestNet)
                                ToolTipView(
                                  message: "testnet_price_desc".tr,
                                  child: Text(
                                    "testnet".tr,
                                    style: context.textTheme.labelSmall
                                        ?.copyWith(color: context.colors.error),
                                  ),
                                ),
                            ],
                          ),
                          WidgetConstant.width8,
                          Expanded(
                              child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(net.coinParam.token.symbol,
                                  style: context.textTheme.labelLarge),
                              OneLineTextWidget(net.coinParam.token.name),
                              CoinAndMarketLivePriceView(liveBalance: balance),
                            ],
                          )),
                          WidgetConstant.width8,
                          if (selected == net) const Icon(Icons.check_circle)
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
          itemCount: networks.length,
          separatorBuilder: (context, index) => WidgetConstant.divider,
        )
      ],
    );
  }
}

class SwitchNetworkIcon extends StatelessWidget {
  final Chain account;
  const SwitchNetworkIcon({required this.account, super.key});

  @override
  Widget build(BuildContext context) {
    return IconButton(
        onPressed: () async {
          await context
              .openDialogPage("switch_network".tr,
                  fullWidget: (context) =>
                      SwitchNetworkView(selectedNetwork: account.network))
              .then(
            (value) {
              if (value == null) return;
              if (context.mounted) {
                if (value is Chain) {
                  context.wallet.wallet.switchNetwork(value);
                } else {
                  context.mybeTo(PageRouter.importNetwork(value));
                }
              }
            },
          );
        },
        icon: CircleTokenImageView(account.network.token,
            radius: APPConst.circleRadius12));
  }
}
