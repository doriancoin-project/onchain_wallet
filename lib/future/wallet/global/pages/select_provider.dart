import 'dart:async';

import 'package:flutter/material.dart';
import 'package:on_chain_wallet/app/core.dart';
import 'package:on_chain_wallet/crypto/types/networks.dart';
import 'package:on_chain_wallet/future/constant/constant.dart';
import 'package:on_chain_wallet/future/future.dart';
import 'package:on_chain_wallet/future/router/page_router.dart';
import 'package:on_chain_wallet/future/state_managment/state_managment.dart';
import 'package:on_chain_wallet/future/wallet/global/pages/types.dart';

import 'package:on_chain_wallet/wallet/wallet.dart';

class AccountManageProviderIcon extends StatelessWidget {
  const AccountManageProviderIcon({super.key, required this.service});
  final NetworkServiceProtocol? service;
  @override
  Widget build(BuildContext context) {
    return SliverToBoxAdapter(
        child: Column(
      children: [
        ConditionalWidget(
            enable: service != null,
            onDeactive: (context) => AppListTile(
                  title: Text("service_provider".tr),
                  onTap: () {
                    context.openSliverDialog<ProviderIdentifier>(
                        widget: (ctx) => SelectProviderView(),
                        label: "service_provider".tr);
                  },
                  subtitle: Text("manage_network_service_providers".tr),
                  trailing: Icon(service?.tracker.icon ?? Icons.error),
                ),
            onActive: (context) => APPStreamBuilder(
                value: service!.tracker.status,
                builder: (context, value) => AppListTile(
                      title: Text("service_provider".tr),
                      onTap: () {
                        context.openSliverDialog<ProviderIdentifier>(
                            widget: (ctx) => SelectProviderView(),
                            label: "service_provider".tr);
                      },
                      subtitle: Text("manage_network_service_providers".tr),
                      trailing: TappedTooltipView(
                          tooltipWidget: ToolTipView(
                        message: service?.tracker.message().tr ?? "",
                        child: Icon(service!.tracker.icon),
                      )),
                    ))),
        WidgetConstant.divider,
      ],
    ));
  }
}

class ProviderTrackerStatusView extends StatelessWidget {
  const ProviderTrackerStatusView({super.key, required this.provider});
  final APIServiceTracker provider;
  @override
  Widget build(BuildContext context) {
    return ToolTipView(
        message: provider.message().tr,
        waitDuration: null,
        child: Icon(Icons.circle,
            color:
                provider.hasActive ? ColorConst.green : context.colors.error));
  }
}

class SelectProviderView extends StatelessWidget {
  const SelectProviderView({super.key});

  @override
  Widget build(BuildContext context) {
    final account = context.wallet.wallet.currentChain;
    return switch (account.network.type) {
      _ => _SelectProviderView(chain: account)
    };
    // return;
  }
}

class _SelectProviderView extends StatefulWidget {
  const _SelectProviderView({required this.chain});
  final Chain chain;

  @override
  State<_SelectProviderView> createState() => _SelectProviderViewState();
}

// abstract class SelectProviderViewState extends State<_SelectProviderView>
//     with SafeState<_SelectProviderView> {}

mixin SelectProviderViewState<
    W extends StatefulWidget,
    PROVIDER extends APIProvider,
    SERVICE extends NetworkServiceProtocol> on SafeState<W> {
  StreamSubscription<ChainEvent>? listener;
  APPCHAINPROVIDER<PROVIDER> get chain;
  WalletNetwork get network => chain.network;
  SERVICE? service;
  List<PROVIDER> providers = [];
  late bool isEnable = chain.config.enableProvider;
  Future<void> onUpdateProvider() async {
    await context.to(PageRouter.updateProvider(network), argruments: network);
    updateState();
  }

  void onTapProvider(PROVIDER provider) {
    final identifier = DefaultProviderIdentifier(
        identifier: provider.identifier, network: network.type);
    context.wallet.setAccountProvider(provider: identifier, account: chain);
  }

  void onToggleProvider() {
    isEnable = !isEnable;
    chain.toggleServiceProvider(isEnable);
    updateState();
  }

  final StreamPageProgressController progressKey =
      StreamPageProgressController(initialStatus: StreamWidgetStatus.progress);

  Future<void> init() async {
    providers = await chain.getProviders();
    service = chain.service as SERVICE?;
    progressKey.backToIdle();
  }

  Future<void> onAccountUpdate(ChainEvent event) async {
    if (!event.status.isComplete) return;
    if (event.type == DefaultChainNotify.client) {
      service = chain.service as SERVICE?;
      updateState();
    } else if (event.type == DefaultChainNotify.updateProvider) {
      await init();
      updateState();
    }
  }

  @override
  void safeDispose() {
    super.safeDispose();
    listener?.cancel();
    listener = null;
  }

  @override
  void onInitOnce() {
    super.onInitOnce();
    init();
    listener = chain.stream.listen(onAccountUpdate);
  }

  Widget providerStateBuilder(BuildContext context) {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ListView.builder(
            physics: WidgetConstant.noScrollPhysics,
            shrinkWrap: true,
            itemBuilder: (context, index) {
              final provider = providers.elementAt(index);
              final bool isSelected =
                  service?.provider.identifier == provider.identifier;
              return ProviderInfoWidget(
                  onTapProvider: onTapProvider,
                  provider: provider,
                  isSelected: isSelected,
                  connect: chain.serviceStatus.isConnect,
                  service: service);
            },
            itemCount: providers.length,
          ),
          if (network.supportCustomNode)
            ContainerWithBorder(
              onRemove: onUpdateProvider,
              validate: providers.isNotEmpty,
              onRemoveIcon:
                  Icon(Icons.add_box, color: context.onPrimaryContainer),
              child: Text("network_add_provider".tr,
                  style: context.onPrimaryTextTheme.bodyMedium),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return StreamPageProgress(
      controller: progressKey,
      builder: (context) {
        return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text("network".tr, style: context.textTheme.titleMedium),
          WidgetConstant.height8,
          ContainerWithBorder(
              child: Text(network.coinParam.token.name,
                  style: context.onPrimaryTextTheme.bodyMedium)),
          ChainStreamBuilder(
              allowNotify: [DefaultChainNotify.client],
              builder: (context, chain, lastNotify) {
                // bool disable = !isE
                return Shimmer(
                    onActive: (enable, context) => Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              WidgetConstant.height20,
                              AppCheckListTile(
                                value: isEnable,
                                contentPadding: EdgeInsets.zero,
                                title: Text("service_provider".tr,
                                    style: context.textTheme.titleMedium),
                                subtitle: Text(
                                    "enable_disable_service_provider_desc".tr),
                                onChanged: (s) {
                                  onToggleProvider();
                                },
                              ),
                              IgnorePointer(
                                ignoring: !isEnable,
                                child: Opacity(
                                  opacity: isEnable
                                      ? APPConst.defaultOpacity
                                      : APPConst.disabledOpacity,
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      ConditionalWidget(
                                          enable: providers.isNotEmpty,
                                          onActive: (context) => Column(
                                                  crossAxisAlignment:
                                                      CrossAxisAlignment.start,
                                                  children: [
                                                    WidgetConstant.height20,
                                                    Text("choose_provider".tr,
                                                        style: context.textTheme
                                                            .titleMedium),
                                                    Text("select_provider_desc"
                                                        .tr),
                                                    WidgetConstant.height8,
                                                  ])),
                                      providerStateBuilder(context)
                                    ],
                                  ),
                                ),
                              ),
                            ]),
                    enable: lastNotify == null);
              },
              account: chain)
        ]);
      },
    );
  }
}

class _SelectProviderViewState extends State<_SelectProviderView>
    with
        SafeState<_SelectProviderView>,
        SelectProviderViewState<_SelectProviderView, APIProvider,
            NetworkServiceProtocol> {
  @override
  Chain get chain => widget.chain;
  @override
  void didUpdateWidget(covariant _SelectProviderView oldWidget) {
    super.didUpdateWidget(oldWidget);
    // providers = network.getAllProviders();
    service = widget.chain.service;
  }
}

typedef ONTAPPROVIDER<T extends APIProvider> = Function(T);

class ProviderInfoWidget<T extends APIProvider> extends StatelessWidget {
  const ProviderInfoWidget({
    super.key,
    required this.onTapProvider,
    required this.provider,
    required this.isSelected,
    required this.connect,
    this.service,
  });
  final bool isSelected;
  final bool connect;
  final NetworkServiceProtocol? service;
  final T provider;
  final ONTAPPROVIDER<T> onTapProvider;

  @override
  Widget build(BuildContext context) {
    return CustomizedContainer(
      onStackIcon: Icons.open_in_full,
      validate: !isSelected || (isSelected && connect),
      onTapStackIcon: (!isSelected || !connect)
          ? null
          : () {
              context.openSliverBottomSheet("network_provider_log_details".tr,
                  slivers: [
                    ProviderLogsView(
                        tracker: service!.tracker, provider: service!.provider),
                  ]);
            },
      onRemoveIcon: ConditionalWidget(
        enable: isSelected,
        onActive: (context) {
          if (!connect) return Icon(Icons.refresh);
          return Icon(Icons.check_circle, color: context.onPrimaryContainer);
        },
      ),
      onRemove: () => onTapProvider(provider),
      enableTap: (isSelected && connect) ? false : true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                  child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(provider.protocol.value.tr,
                      style: context.onPrimaryTextTheme.labelLarge),
                  Text(provider.callUrl,
                      style:
                          context.colors.onPrimaryContainer.bodyMedium(context),
                      maxLines: 2),
                ],
              )),
            ],
          ),
        ],
      ),
    );
  }
}

extension ProviderQuickTooltipMessageExtension on APIServiceTracker? {
  String message() {
    if (this == null) {
      return "network_no_provider_detected";
    }
    switch (this?.status.value) {
      case APIServiceStatus.active:
        return "no_error_found";
      case APIServiceStatus.error:
        return "network_all_request_error";
      default:
        return "network_some_request_error";
    }
  }

  IconData get icon {
    if (this == null) {
      return Icons.error;
    }
    switch (this?.status.value) {
      case APIServiceStatus.active:
        return Icons.check_circle;
      case APIServiceStatus.error:
        return Icons.error;
      default:
        return Icons.warning;
    }
  }
}

class _ProviderRequestView extends StatefulWidget {
  const _ProviderRequestView({required this.provider});
  final APIServiceTracker provider;

  @override
  State<_ProviderRequestView> createState() => _ProviderRequestViewState();
}

class _ProviderRequestViewState extends State<_ProviderRequestView>
    with SafeState<_ProviderRequestView> {
  ApiRequest? full;

  void onSetFullView(ApiRequest? request) {
    full = request;
    updateState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final requets = widget.provider.requests;
    return SliverList.builder(
        itemCount: requets.length,
        itemBuilder: (context, index) {
          final request = requets[index];
          final int? maxLine = full == request ? null : 1;
          return AnimatedSize(
            duration: APPConst.animationDuraion,
            alignment: Alignment.topCenter,
            child: ContainerWithBorder(
                key: ValueKey<int?>(maxLine),
                onRemove: () {
                  onSetFullView(request);
                },
                onRemoveWidget: WidgetConstant.sizedBox,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Text(request.time.toDateAndTime(),
                            style: context.onPrimaryTextTheme.labelSmall),
                      ],
                    ),
                    Text("url".tr,
                        style: context.onPrimaryTextTheme.titleMedium),
                    WidgetConstant.height8,
                    ContainerWithBorder(
                      backgroundColor: context.onPrimaryContainer,
                      onRemove: () {},
                      onRemoveIcon: CopyTextIcon(
                        dataToCopy: request.uri,
                        isSensitive: false,
                        color: context.primaryContainer,
                      ),
                      enableTap: false,
                      child: Text(
                        request.uri,
                        style: context.primaryTextTheme.bodyMedium,
                        maxLines: maxLine,
                      ),
                    ),
                    if (request.error != null) ...[
                      WidgetConstant.height20,
                      Text("error".tr,
                          style: context.onPrimaryTextTheme.titleMedium),
                      WidgetConstant.height8,
                      ContainerWithBorder(
                        backgroundColor: context.colors.error,
                        child: Text(
                          request.error!.toString().tr,
                          style: context.textTheme.bodyMedium
                              ?.copyWith(color: context.colors.onError),
                          maxLines: maxLine,
                        ),
                      ),
                    ],
                  ],
                )),
          );
        });
  }
}

class ProviderLogsView extends StatefulWidget {
  const ProviderLogsView(
      {super.key, required this.tracker, required this.provider});
  final APIServiceTracker tracker;
  final APIProvider provider;

  @override
  State<ProviderLogsView> createState() => _ProviderLogsViewState();
}

class _ProviderLogsViewState extends State<ProviderLogsView> with SafeState {
  ApiRequest? full;

  void onSetFullView(ApiRequest? request) {
    full = request;
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final requets = widget.tracker.requests;
    return SliverConstraintsBoxView(
      padding: WidgetConstant.paddingHorizontal20,
      sliver: MultiSliver(
        children: [
          SliverToBoxAdapter(
            child: ConstraintsBoxView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text("status".tr, style: context.textTheme.titleMedium),
                  WidgetConstant.height8,
                  ContainerWithBorder(
                    onRemove: () {},
                    onRemoveIcon: Icon(widget.tracker.icon,
                        color: context.colors.onPrimaryContainer),
                    child: Text(
                      widget.tracker.message().tr,
                      style: context.onPrimaryTextTheme.bodyMedium,
                    ),
                  ),
                  WidgetConstant.height20,
                  Text("provider".tr, style: context.textTheme.titleMedium),
                  WidgetConstant.height8,
                  ContainerWithBorder(
                    onRemove: () {},
                    onRemoveWidget: LaunchBrowserIcon(
                      url: widget.provider.callUrl,
                      color: context.colors.onPrimaryContainer,
                    ),
                    enableTap: false,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.provider.protocol.value.tr,
                          style: context.onPrimaryTextTheme.labelLarge,
                        ),
                        SelectableText(
                          widget.provider.callUrl,
                          style: context.onPrimaryTextTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                  WidgetConstant.height20,
                  Text("network_total_request".tr,
                      style: context.textTheme.titleMedium),
                  WidgetConstant.height8,
                  ContainerWithBorder(
                      child: Text(
                    widget.tracker.requestCount.toString().to3Digits,
                    style: context.onPrimaryTextTheme.bodyMedium,
                  )),
                  WidgetConstant.height20,
                  Text("network_total_success_request".tr,
                      style: context.textTheme.titleMedium),
                  WidgetConstant.height8,
                  ContainerWithBorder(
                      child: Text(
                    widget.tracker.totalSuccess.toString().to3Digits,
                    style: context.onPrimaryTextTheme.bodyMedium,
                  )),
                  if (requets.isNotEmpty) ...[
                    WidgetConstant.height20,
                    Text("network_request_details".tr,
                        style: context.textTheme.titleMedium),
                    WidgetConstant.height8,
                  ]
                ],
              ),
            ),
          ),
          _ProviderRequestView(provider: widget.tracker)
        ],
      ),
    );
  }
}
