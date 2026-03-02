import 'dart:async';

import 'package:flutter/material.dart';
import 'package:on_chain_wallet/app/core.dart';
import 'package:on_chain_wallet/crypto/types/networks.dart';
import 'package:on_chain_wallet/future/future.dart';
import 'package:on_chain_wallet/future/state_managment/state_managment.dart';
import 'package:on_chain_wallet/future/wallet/global/pages/types.dart';

import 'package:on_chain_wallet/wallet/api/client/core/client.dart';
import 'package:on_chain_wallet/wallet/chain/account.dart';
import 'package:on_chain_wallet/wallet/models/nfts/core/core.dart';
import 'package:on_chain_wallet/wallet/models/token/network/token.dart';
import 'package:on_chain_wallet/wallet/models/token/token/token.dart';
import 'package:on_chain_wallet/wallet/models/transaction/core/transaction.dart';

class ManageAccountTokenView extends StatefulWidget {
  const ManageAccountTokenView({super.key});

  @override
  State<ManageAccountTokenView> createState() => _ManageAccountTokenViewState();
}

class _ManageAccountTokenViewState extends State<ManageAccountTokenView> {
  @override
  Widget build(BuildContext context) {
    return NetworkAccountControllerView<NetworkClient, ChainAccount, Chain>(
        childBulder: (wallet, account, client, address, onAccountChanged) {
          switch (account.network.type) {
            default:
              return _ManageAccountToken(
                  account: account, client: client, address: address);
          }
        },
        addressRequired: true,
        clientRequired: true);
  }
}

class _ManageAccountToken extends StatefulWidget {
  final NetworkClient client;
  final Chain account;
  final ChainAccount address;
  const _ManageAccountToken(
      {required this.client, required this.account, required this.address});

  @override
  State<_ManageAccountToken> createState() => __ManageAccountTokenState();
}

class __ManageAccountTokenState extends State<_ManageAccountToken>
    with
        SafeState<_ManageAccountToken>,
        ManageAccountTokenState<
            _ManageAccountToken,
            NetworkClient,
            TokenCore,
            ChainAccount<dynamic, TokenCore, NFTCore, ChainTransaction>,
            Chain> {
  @override
  Chain get account => widget.account;

  @override
  NetworkClient get client => widget.client;
}

mixin ManageAccountTokenState<
        W extends StatefulWidget,
        CL extends NetworkClient,
        TOKEN extends TokenCore,
        ACCOUNT extends ChainAccount<dynamic, TOKEN, NFTCore, ChainTransaction>,
        CHAIN extends APPCHAINNETWORKTOKENACCOUNT<TOKEN, CL, ACCOUNT>>
    on SafeState<W> {
  CHAIN get account;
  CL get client;
  late WalletProvider wallet;
  StreamSubscription<List<BaseNetworkToken>>? listener;
  ACCOUNT get address => account.address;
  List<BaseNetworkToken> tokens = [];
  final StreamPageProgressController progressKey =
      StreamPageProgressController(initialStatus: StreamWidgetStatus.progress);

  void onNewToken(List<BaseNetworkToken> token) {
    tokens.addAll(token);
    updateState();
    if (progressKey.inProgress) progressKey.backToIdle();
  }

  void onError(Object e) {
    final error = MethodResult.findErrorMessage(e);
    if (progressKey.inProgress) {
      progressKey.errorText(error.tr, backToIdle: false);
    }
  }

  void onDone() {
    if (progressKey.inProgress) progressKey.backToIdle();
  }

  Future<void> onTap(BaseNetworkToken token) async {
    if (address.tokens.contains(token.token)) {
      await account.removeToken(token: token.token as TOKEN, address: address);
      return;
    }

    if (token.status.isFailed) {
      Token? updated;
      await context.openSliverBottomSheet<bool>("update_token".tr,
          bodyBuilder: (scrollController) => UpdateTokenDetailsView(
              token: token.token.token,
              account: account,
              title: PageTitleSubtitle(
                  title: "update_token_information".tr,
                  body: AlertTextContainer(
                      message: "update_unknown_token_metadata_desc".tr,
                      enableTap: false)),
              address: account.address,
              onUpdateToken: (context, updatedToken) {
                context.pop();
                updated = updatedToken;
              },
              scrollController: scrollController),
          centerContent: false);
      if (updated != null) {
        token.updaetTokenMetadata(updated!);
      }
    }
    await account.addNewToken(token: token.token as TOKEN, address: address);
  }

  void init() {
    listener = client.getAccountTokensStream(address.networkAddress).listen(
        onNewToken,
        onError: onError,
        onDone: onDone,
        cancelOnError: true);
    wallet = context.wallet;
  }

  @override
  void onInitOnce() {
    super.onInitOnce();
    init();
  }

  @override
  void safeDispose() {
    super.safeDispose();
    progressKey.dispose();
    listener?.cancel();
    listener = null;
    for (final i in tokens) {
      i.dispose();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("manage_tokens".tr)),
      body: StreamPageProgress(
        controller: progressKey,
        initialWidget:
            ProgressWithTextView(text: 'fetching_account_token_please_wait'.tr),
        builder: (context) => ChainStreamBuilder(
          account: account,
          allowNotify: [DefaultChainNotify.token],
          builder: (context, value, _) => CustomScrollView(
            slivers: [
              EmptyItemSliverWidgetView(
                isEmpty: tokens.isEmpty,
                itemBuilder: (context) => SliverConstraintsBoxView(
                  padding: WidgetConstant.paddingHorizontal20,
                  sliver: SliverList.separated(
                      separatorBuilder: (context, index) =>
                          WidgetConstant.divider,
                      itemBuilder: (context, index) {
                        final token = tokens.elementAt(index);
                        final bool exist = address.tokens.contains(token.token);
                        return APPStreamBuilder(
                          value: token.notifier,
                          builder: (context, value) => Shimmer(
                              onActive: (enable, context) =>
                                  AccountTokenDetailsView(
                                      error: token.status.isFailed
                                          ? "update_unknown_token_metadata_desc"
                                              .tr
                                          : null,
                                      onTapError: () {},
                                      onSelect: () {
                                        context.openSliverDialog(
                                            widget: (ctx) => DialogTextView(
                                                buttonWidget:
                                                    AsyncDialogDoubleButtonView(
                                                  firstButtonPressed: () =>
                                                      onTap(token),
                                                ),
                                                text: exist
                                                    ? "remove_token_from_account"
                                                        .tr
                                                    : "add_token_to_your_account"
                                                        .tr),
                                            label: exist
                                                ? "remove_token".tr
                                                : "add_token".tr);
                                      },
                                      onSelectIcon: APPCheckBox(
                                          value: exist,
                                          ignoring: true,
                                          onChanged: (value) {}),
                                      token: token.token),
                              enable: !token.status.isPending),
                        );
                      },
                      addAutomaticKeepAlives: false,
                      addRepaintBoundaries: false,
                      itemCount: tokens.length),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
