import 'dart:async';

import 'package:blockchain_utils/helper/extensions/extensions.dart';
import 'package:flutter/material.dart';
import 'package:on_chain_wallet/app/core.dart';
import 'package:on_chain_wallet/future/state_managment/state_managment.dart';
import 'package:on_chain_wallet/future/wallet/controller/controller.dart';
import 'package:on_chain_wallet/future/wallet/global/pages/types.dart';
import 'package:on_chain_wallet/future/wallet/network/bitcoin/web3/permission/btcoin_cash_permission.dart';
import 'package:on_chain_wallet/future/wallet/network/bitcoin/web3/permission/web3_permission.dart';
import 'package:on_chain_wallet/future/wallet/security/pages/accsess_wallet.dart';
import 'package:on_chain_wallet/future/wallet/web3/pages/client_info.dart';
import 'package:on_chain_wallet/future/wallet/web3/types/types.dart';
import 'package:on_chain_wallet/future/widgets/custom_widgets.dart';
import 'package:on_chain_wallet/wallet/wallet.dart';
import 'package:on_chain_wallet/wallet/web3/web3.dart';
import 'package:on_chain_wallet/crypto/types/networks.dart';

class Web3PermissionUpdateView extends StatelessWidget {
  const Web3PermissionUpdateView(
      {required this.authenticated,
      required this.onPermissionUpdate,
      super.key});
  final Web3UpdatePermissionRequest authenticated;
  final ONWEB3PERMISSIONUPDATED onPermissionUpdate;

  @override
  Widget build(BuildContext context) {
    return ConstraintsBoxView(
      alignment: Alignment.center,
      padding: WidgetConstant.paddingHorizontal20,
      maxWidth: APPConst.dialogWidth,
      child: ClipRRect(
          borderRadius: WidgetConstant.border25,
          child: AccessWalletView<WalletCredentialResponseLogin,
                  WalletCredentialLogin>(
              request: WalletCredentialLogin.instance,
              appbar: AppBar(
                title: Text('web3_permission'.tr,
                    style: context.textTheme.titleMedium),
              ),
              onAccsess: (_) {
                return Web3ApplicationPermissionView(
                    authenticated: authenticated,
                    onPermissionUpdate: onPermissionUpdate);
              })),
    );
  }
}

class Web3ApplicationPermissionView extends StatelessWidget {
  final Web3UpdatePermissionRequest authenticated;
  final ONWEB3PERMISSIONUPDATED onPermissionUpdate;
  const Web3ApplicationPermissionView(
      {super.key,
      required this.authenticated,
      required this.onPermissionUpdate});

  @override
  Widget build(BuildContext context) {
    return _Web3ApplicationPermissionView(
        authenticated: authenticated, onPermissionUpdate: onPermissionUpdate);
  }
}

class Web3ApplicationPermissionData extends InheritedWidget {
  final Web3UpdatePermissionRequest request;
  final Web3InternalChain internalChain;
  final List<Chain> chains;
  final List<Web3AccountAcitvity> activities;
  const Web3ApplicationPermissionData(
      {super.key,
      required this.request,
      required super.child,
      required this.internalChain,
      required this.chains,
      required this.activities});
  static Web3ApplicationPermissionData of(BuildContext context) {
    return context
        .dependOnInheritedWidgetOfExactType<Web3ApplicationPermissionData>()!;
  }

  @override
  bool updateShouldNotify(covariant InheritedWidget oldWidget) {
    return true;
  }
}

class _Web3ApplicationPermissionView extends StatefulWidget {
  final Web3UpdatePermissionRequest authenticated;
  final ONWEB3PERMISSIONUPDATED onPermissionUpdate;
  const _Web3ApplicationPermissionView(
      {required this.authenticated, required this.onPermissionUpdate});

  @override
  State<_Web3ApplicationPermissionView> createState() =>
      __Web3APPPermissionViewState();
}

class __Web3APPPermissionViewState extends State<_Web3ApplicationPermissionView>
    with SafeState<_Web3ApplicationPermissionView> {
  late final WalletProvider walletProvider;
  final GlobalKey<FormState> formKey = GlobalKey();

  Web3UpdatePermissionRequest get request => widget.authenticated;
  Web3ClientInfo? get client => request.client;
  late Web3ApplicationAuthentication application;
  Map<NetworkType, Web3InternalChain> internalChains = {};
  Map<NetworkType, Web3InternalChain> updatedChains = {};

  List<Chain> walletChains = [];
  List<Web3AccountAcitvity> activities = [];
  String applicationName = "";
  NetworkType chainType = NetworkType.bitcoinAndForked;
  bool showUpdateButton = false;
  int _selectedIndex = 1;
  bool active = true;
  final StreamPageProgressController controller =
      StreamPageProgressController(initialStatus: StreamWidgetStatus.progress);

  bool haveRequiredPermissions() {
    final networks = requiredNetworkPermissions();
    final chains = requiredChainPermissions();
    return networks.isEmpty && chains.isEmpty;
  }

  List<NetworkType> requiredNetworkPermissions() {
    if (!request.hasLockedNetwork) return [];
    List<NetworkType> requiredPermissions = [];
    for (final i in request.lockedNetworks) {
      final permission = updatedChains[i]?.hasAnyChainPermission() ?? false;
      if (permission) continue;
      requiredPermissions.add(i);
    }
    return requiredPermissions;
  }

  List<Chain> requiredChainPermissions() {
    if (!request.hasLockedChain) return [];
    List<Chain> requiredPermissions = [];
    for (final i in request.lockedChains) {
      final permission = updatedChains[i.network.type]
              ?.hasAnyNetworkPermission(i.network.value) ??
          false;
      if (permission) continue;
      requiredPermissions.add(i);
    }
    return requiredPermissions;
  }

  bool chainDisabled(NetworkType network) {
    if (!active) return true;
    return request.networkDisabled(network);
  }

  void onChangeName(String v) {
    applicationName = v;
  }

  void onChangeActivation(bool? _) {
    active = !active;
    updateState();
  }

  String? validateApplicationName(String? v) {
    if (v == null || v.trim().length < 3) {
      return "application_name_validator".tr;
    }
    return null;
  }

  Future<void> initApplication(Web3ApplicationAuthentication app) async {
    application = app;
    applicationName = application.name;
    active = application.active;
    final internalChains = await walletProvider.wallet.getWeb3InternalChains(
        application,
        networks: request.hasLockedNetwork ? request.lockedNetworks : null);
    if (internalChains.hasError) {
      controller.errorText(internalChains.localizationError, backToIdle: false);
      return;
    }
    if (walletChains.isEmpty) {
      walletChains = walletProvider.wallet.getChains();
    }
    this.internalChains = {for (final i in internalChains.result) i.type: i};
    updatedChains = this.internalChains.clone();
    if (request.hasLockedNetwork) {
      chainType = request.lockedNetworks.first;
      final lockedNetworkIndex = NetworkType.values.indexOf(chainType);
      _selectedIndex = lockedNetworkIndex + 1;
    }
    if (!app.active) {
      _selectedIndex = 0;
    }
    if (activities.isEmpty) {
      final activities =
          await walletProvider.wallet.getWeb3ApplicationActivities(application);
      assert(activities.hasResult, activities.localizationError);
      this.activities = activities.resultOrNull ?? [];
    }
    controller.backToIdle();
    showUpdateButton = true;
    updateState();
  }

  void updateCurrentStatePermission() {
    if (_selectedIndex == 0) return;
    final currentUpdate =
        permissionState[_selectedIndex]?.currentState?.updateApplication();
    assert(currentUpdate != null);
    if (currentUpdate != null) {
      updatedChains[chainType] = currentUpdate;
    }
  }

  Future<void> onUpdateChainPermission() async {
    updateCurrentStatePermission();
    // Web3ApplicationAuthentication permission = application;
    final requiredChains = requiredChainPermissions();
    if (requiredChains.isNotEmpty) {
      final accept = await context.openSliverDialog(
          widget: (context) => DialogTextView(
                text: "web3_dapp_update_permission_alert".tr.replaceOne(
                    requiredChains
                        .map((e) => e.network.networkName)
                        .join(", ")),
                buttonWidget: DialogDoubleButtonView(),
              ),
          label: 'update_permission'.tr);
      if (accept != true) return;
    }
    if (requiredChains.isEmpty) {
      final requiredNetworks = requiredNetworkPermissions();
      if (requiredNetworks.isNotEmpty) {
        final accept = await context.openSliverDialog(
            widget: (context) => DialogTextView(
                  text: "web3_dapp_update_permission_alert".tr.replaceOne(
                      requiredNetworks.map((e) => e.name).join(", ")),
                  buttonWidget: DialogDoubleButtonView(),
                ),
            label: 'update_permission'.tr);
        if (accept != true) return;
      }
    }
    final bool hasRequiredPermission = haveRequiredPermissions();

    Web3ApplicationAuthentication cp = application;
    if (cp.name != applicationName) {
      cp = cp.copyWith(name: applicationName);
    }
    List<Web3InternalChain> updatedNetwork = [];
    controller.progressText("updating_permission".tr);
    showUpdateButton = false;
    updateState();
    if (application.active != active) {
      cp = cp.copyWith(active: active);
      updatedNetwork = updatedChains.values.map((e) => e).toList();
    } else {
      for (final i in NetworkType.values) {
        final updatePermission = updatedChains[i];
        final oldPermission = internalChains[i];
        if (updatePermission == null) continue;
        assert(oldPermission != null);
        if (oldPermission == null) continue;
        if (updatePermission == oldPermission) continue;
        updatedNetwork.add(updatePermission);
      }
    }
    final update = await walletProvider.wallet
        .updateWeb3Application(application: cp, chains: updatedNetwork);
    if (update.hasError) {
      controller.errorText(
        update.localizationError,
        backToIdle: false,
        showBackButton: true,
        onTapBackButton: () => updateState(() {
          showUpdateButton = true;
        }),
      );
      return;
    }
    final response = Web3PermissionUpdateResponse(
        authentication: cp,
        hasRequiredPermission: hasRequiredPermission,
        appInfo: update.result,
        chains: updatedNetwork.map((e) => e.type).toList());
    final close = await widget.onPermissionUpdate(response);
    showUpdateButton = !close;
    if (close) {
      controller.success(backToIdle: false);
      return;
    }
    await initApplication(cp);
  }

  void changeChain(int index) {
    if (index == 0) {
      _selectedIndex = 0;
      updateState();
      return;
    }
    if (_selectedIndex != 0) updateCurrentStatePermission();
    chainType = NetworkType.values.elementAt(index - 1);
    _selectedIndex = index;
    updateState();
  }

  Future<void> clearActivities() async {
    final application = this.application;
    final r = await context.openSliverDialog<bool>(
        widget: (context) => DialogTextView(
            text: "delete_all_activities_desc2".tr,
            buttonWidget: DialogDoubleButtonView()),
        label: 'remove_activities'.tr);
    if (r != true) return;

    controller.progressText("updating_permission".tr);
    updateState();
    final result = await walletProvider.wallet
        .removeWeb3ApplicationActivities(application);
    assert(result.hasResult, result.localizationError);
    if (result.hasError) {
      controller.errorText(result.localizationError);
    } else {
      activities = [];
      controller.success();
    }
  }

  Map<int, GlobalKey<Web3PermissionState>> permissionState = {
    for (int i = 0; i < NetworkType.values.length; i++)
      i + 1: GlobalKey<Web3PermissionState>(
          debugLabel: "Web3PermissionState_${NetworkType.values[i].name}")
  };

  @override
  void onInitOnce() {
    super.onInitOnce();
    walletProvider = context.wallet;
    MethodUtils.after(() async => initApplication(request.authentication));
  }

  @override
  void safeDispose() {
    super.safeDispose();
    controller.dispose();
    permissionState = {};
    internalChains = {};
    updatedChains = {};
    walletChains = [];
    activities = [];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: false,
      floatingActionButton: APPAnimatedSwitcher<bool>(
          enable: showUpdateButton,
          duration: APPConst.animationDuraion,
          widgets: {
            true: (context) => FloatingActionButton.extended(
                onPressed: onUpdateChainPermission,
                label: Text("update_permission".tr),
                icon: const Icon(Icons.save)),
            false: (context) => WidgetConstant.sizedBox
          }),
      body: StreamPageProgress(
        // backToIdle: APPConst.oneSecoundDuration,
        // initialStatus: StreamWidgetStatus.progress,
        controller: controller,
        builder: (context) => Row(
          children: [
            Column(
              children: [
                Expanded(
                  child: SingleChildScrollView(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(
                          maxWidth: APPConst.naviationRailWidth),
                      child: IntrinsicHeight(
                        child: NavigationRail(
                          useIndicator: true,
                          onDestinationSelected: changeChain,
                          labelType: NavigationRailLabelType.none,
                          destinations: [
                            const NavigationRailDestination(
                                icon: Icon(Icons.settings),
                                label: WidgetConstant.sizedBox),
                            _NavigationRailDestination(
                                image: APPConst.btc,
                                disabled: chainDisabled(
                                    NetworkType.bitcoinAndForked)),
                            _NavigationRailDestination(
                                image: APPConst.bch,
                                disabled:
                                    chainDisabled(NetworkType.bitcoinCash)),
                          ],
                          selectedIndex: _selectedIndex,
                        ),
                      ),
                    ),
                  ),
                ),
                TappedTooltipView(
                  tooltipWidget: ToolTipView(
                      padding: WidgetConstant.padding5,
                      tooltipWidget: (context) => ConstrainedBox(
                          constraints: const BoxConstraints(
                              maxWidth: APPConst.tooltipConstrainedWidth),
                          child: Container(
                              decoration: BoxDecoration(
                                  color: context.colors.surface,
                                  borderRadius: WidgetConstant.border8),
                              padding: WidgetConstant.padding10,
                              child: Web3ApplicationView(
                                  permission: application, client: client))),
                      child: Padding(
                          padding: WidgetConstant.padding10,
                          child: CircleAPPImageView(application.icon,
                              radius: 20,
                              onError: (c) => const Icon(Icons.broken_image,
                                  size: APPConst.double40)))),
                ),
              ],
            ),
            Expanded(
                child: Web3ApplicationPermissionData(
                    request: request,
                    internalChain: updatedChains[chainType]!,
                    chains: walletChains,
                    activities: activities,
                    child: _APPPermissionWidget(state: this)))
          ],
        ),
      ),
    );
  }
}

class _APPPermissionWidget extends StatelessWidget {
  const _APPPermissionWidget({required this.state});
  final __Web3APPPermissionViewState state;

  @override
  Widget build(BuildContext context) {
    final application = state.application;
    int tabbarLength = switch (state.chainType) {
      _ => 2,
    };
    return DefaultTabController(
      key: ValueKey(tabbarLength),
      length: tabbarLength,
      child: CustomScrollView(
        slivers: [
          SliverPinnedHeaderSurface(
              child: ErrorTextContainer(
                  error:
                      application.active ? null : "client_disabled_desc".tr)),
          APPSliverAnimatedSwitcher<int>(
            enable: state._selectedIndex,
            widgets: {
              0: (context) => _APPSettingView(state),
              1: (context) => BitcoinWeb3PermissionView(
                  key: state.permissionState[1], application: application),
              2: (context) => BitcoinCashWeb3PermissionView(
                  key: state.permissionState[2], application: application),
            },
          ),
          WidgetConstant.sliverPaddingVertial40,
        ],
      ),
    );
  }
}

class _APPSettingView extends StatelessWidget {
  const _APPSettingView(this.state);
  final __Web3APPPermissionViewState state;
  @override
  Widget build(BuildContext context) {
    return SliverToBoxAdapter(
      child: Padding(
        padding: WidgetConstant.padding20,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Web3ApplicationView(
                permission: state.application, client: state.client),
            WidgetConstant.height20,
            Text("application_name".tr, style: context.textTheme.titleMedium),
            Text("edit_application_name_desc".tr),
            WidgetConstant.height8,
            AppTextField(
                label: "application_name".tr,
                onChanged: state.onChangeName,
                validator: state.validateApplicationName,
                hint: "application_name".tr,
                initialValue: state.applicationName),
            ConditionalWidget(
                enable: state.application.protocol.isInjected,
                onActive: (context) => Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          WidgetConstant.height20,
                          AppSwitchListTile(
                              contentPadding: EdgeInsets.zero,
                              title: Text("web3_activation".tr,
                                  style: context.textTheme.titleMedium),
                              subtitle: Text("web3_activation_desc".tr),
                              maxLine: 3,
                              value: state.active,
                              onChanged: state.onChangeActivation),
                        ])),
            AppListTile(
              contentPadding: EdgeInsets.zero,
              onTap: state.clearActivities,
              title: Text("remove_activities".tr,
                  style: context.textTheme.titleMedium),
              subtitle: Text("delete_all_activities_desc".tr),
              trailing: Icon(Icons.delete_forever, color: context.colors.error),
            )
          ],
        ),
      ),
    );
  }
}

mixin Web3DefaultPermissionState<ADDRESS extends ChainAccount> {
  NetworkType get type;
  Web3InternalDefaultNetworkAccount createWeb3Account(ADDRESS address) {
    return Web3InternalDefaultNetworkAccount(
        keyIndex: address.keyIndex, identifier: address.identifier);
  }

  Web3InternalDefaultNetwork createWeb3Network(
      List<Web3InternalDefaultNetworkAccount> accounts,
      Web3InternalDefaultNetworkAccount? defaultAccount,
      int networkId) {
    return Web3InternalDefaultNetwork(
        accounts: accounts,
        networkId: networkId,
        defaultAccount: defaultAccount);
  }

  Web3InternalDefaultChain createWeb3Chain(
      List<Web3InternalDefaultNetwork> networks, int defaultNetworkId) {
    return Web3InternalDefaultChain(
        networks: networks, type: type, defaultChain: defaultNetworkId);
  }
}
mixin Web3PermissionState<
    T extends StatefulWidget,
    NETWORKADDRESS,
    CHAIN extends APPCHAINNETWORK<NETWORKADDRESS>,
    ADDRESS extends NETWORKCHAINACCOUNT<NETWORKADDRESS>,
    WEB3ACCOUNT extends Web3InternalNetworkAccount,
    WEB3NETWORK extends Web3InternalNetwork<WEB3ACCOUNT>,
    WEB3 extends Web3InternalChain<WEB3NETWORK>> on SafeState<T> {
  StreamSubscription<ChainEvent>? _accountListener;
  void onAccountUpdated(ChainEvent event) {
    if (event.type == DefaultChainNotify.address &&
        event.status == ChainNotifyStatus.complete) {
      updateState();
    }
  }

  void listenOnAccount() {
    _accountListener?.cancel();
    _accountListener = null;
    _accountListener = chain.stream.listen(onAccountUpdated);
  }

  WEB3ACCOUNT? createWeb3Account(ADDRESS address);
  WEB3NETWORK createWeb3Network(
      List<WEB3ACCOUNT> address, WEB3ACCOUNT? defaultAccount, int networkId);
  WEB3 createWeb3Chain(List<WEB3NETWORK> networks, int defaultNetworkId);
  List<WEB3ACCOUNT> accounts = [];
  WEB3ACCOUNT? defaultAddress;
  late final Web3ApplicationPermissionData permissionData;
  late Web3UpdatePermissionRequest authenticated;
  Web3ApplicationAuthentication get application => authenticated.authentication;
  late CHAIN chain;
  List<CHAIN> chains = [];
  Map<int, WEB3NETWORK> permissions = {};
  WEB3NETWORK get permission => permissions[chain.network.value]!;

  List<Web3ActivityViewItem> activities = [];

  NetworkType get type;

  List<DropdownMenuItem<CHAIN>> menuItems = [];
  bool isDefaultAddress(ADDRESS address) {
    return address.identifier == defaultAddress?.identifier &&
        address.keyIndex == defaultAddress?.keyIndex;
  }

  void onChangeDefaultPermission(ADDRESS address) {
    final web3Account = accounts.firstWhereOrNull((e) =>
        e.identifier == address.identifier && e.keyIndex == address.keyIndex);
    assert(web3Account != null);
    if (web3Account == null) return;
    defaultAddress = web3Account;
    updateState();
  }

  bool chainDisabled(CHAIN chain) {
    return authenticated.chainDisabled(chain);
  }

  void updateActivities() {
    activities = permissionData.activities
        .where((e) => e.id == chain.network.value)
        .map((e) {
      return Web3ActivityViewItem(
          activity: e,
          address: e.address == null
              ? null
              : chain.getReceiptAddress(e.address!) ??
                  ReceiptAddress(view: e.address!, networkAddress: e),
          name: e.method.camelCase,
          url: e.path);
    }).toList();
  }

  bool hasPermission(ADDRESS address) {
    final web3Account = accounts.firstWhereOrNull((e) =>
        e.identifier == address.identifier && e.keyIndex == address.keyIndex);
    return web3Account != null;
  }

  void addAccount(ADDRESS address) {
    final web3Account = accounts.firstWhereOrNull((e) =>
        e.identifier == address.identifier && e.keyIndex == address.keyIndex);
    if (accounts.remove(web3Account)) {
      if (defaultAddress == web3Account) {
        defaultAddress = accounts.firstOrNull;
      }
    } else {
      final newAccount = createWeb3Account(address);
      if (newAccount == null) return;
      accounts.add(newAccount);
      defaultAddress ??= newAccount;
    }
    updateState();
  }

  void onChangeChain(CHAIN? updateChain, {bool notify = true}) {
    if (updateChain == null) return;
    permissions[chain.network.value] = createWeb3Network(
        accounts,
        accounts.contains(defaultAddress)
            ? defaultAddress
            : accounts.firstOrNull,
        chain.network.value);
    chain = updateChain;
    accounts = permission.accounts.clone();
    defaultAddress =
        accounts.firstWhereOrNull((e) => e == permission.defaultAccount) ??
            accounts.firstOrNull;
    updateActivities();
    if (notify) updateState();
    listenOnAccount();
  }

  WEB3 updateApplication() {
    permissions[chain.network.value] = createWeb3Network(
        accounts,
        accounts.contains(defaultAddress)
            ? defaultAddress
            : accounts.firstOrNull,
        chain.network.value);
    return createWeb3Chain(permissions.values.toList(), chain.network.value);
  }

  @override
  void onInitOnce() {
    super.onInitOnce();
    permissionData = Web3ApplicationPermissionData.of(context);
    authenticated = permissionData.request;
    chains = permissionData.chains
        .whereType<CHAIN>()
        .where((e) => e.network.type == type)
        .toList();
    menuItems = chains.map((e) {
      return _ChainDropDownItems(
          chain: e, disabled: authenticated.chainDisabled(e));
    }).toList();
    final chain = chains.firstWhere(
        (e) => e.network.value == permissionData.internalChain.defaultChain);
    if (authenticated.chainDisabled(chain)) {
      this.chain = authenticated.lockedChains.whereType<CHAIN>().first;
    } else {
      this.chain = chain.cast();
    }
    for (final i in permissionData.internalChain.networks) {
      permissions[i.networkId] = i as WEB3NETWORK;
    }
    accounts = permission.accounts.clone();
    defaultAddress =
        accounts.firstWhereOrNull((e) => e == permission.defaultAccount) ??
            accounts.firstOrNull;
    _accountListener = chain.stream.listen(onAccountUpdated);
    updateActivities();
    listenOnAccount();
  }

  @override
  void safeDispose() {
    super.safeDispose();
    _accountListener?.cancel();
    _accountListener = null;
  }
}

class _NavigationRailDestination extends NavigationRailDestination {
  _NavigationRailDestination({required APPImage image, required super.disabled})
      : super(
            label: WidgetConstant.sizedBox,
            icon: Opacity(
                opacity: disabled ? 0.3 : 1,
                child: CircleAssetsImageView(image, radius: 15)));
}

class _ChainDropDownItems<CHAIN extends Chain> extends DropdownMenuItem<CHAIN> {
  _ChainDropDownItems({required CHAIN chain, required bool disabled})
      : super(
            child: _ChainDropDownItemWidget(chain: chain, disabled: disabled),
            enabled: !disabled,
            value: chain);
}

class _ChainDropDownItemWidget extends StatelessWidget {
  final Chain chain;
  final bool disabled;
  const _ChainDropDownItemWidget({required this.chain, required this.disabled})
      : super();

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: disabled ? APPConst.disabledOpacity : 1,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAPPImageView(chain.network.token.assetLogo, radius: 15),
          WidgetConstant.width8,
          Flexible(
            child: OneLineTextWidget(chain.network.token.name,
                style: context.textTheme.labelLarge),
          )
        ],
      ),
    );
  }
}

class Web3ActivityViewItem {
  final String name;
  final Web3AccountAcitvity activity;
  final ReceiptAddress? address;
  final String? url;
  const Web3ActivityViewItem({
    required this.name,
    required this.activity,
    required this.url,
    this.address,
  });
}
