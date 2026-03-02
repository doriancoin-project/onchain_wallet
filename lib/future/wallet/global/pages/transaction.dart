import 'package:flutter/material.dart';

import 'package:on_chain_wallet/app/constant/constant.dart';
import 'package:on_chain_wallet/crypto/types/networks.dart';
import 'package:on_chain_wallet/future/router/page_router.dart';
import 'package:on_chain_wallet/future/state_managment/state_managment.dart';
import 'package:on_chain_wallet/future/wallet/global/pages/receipt_address_view.dart';
import 'package:on_chain_wallet/future/wallet/global/pages/types.dart';
import 'package:on_chain_wallet/future/widgets/custom_widgets.dart';
import 'package:on_chain_wallet/wallet/chain/account.dart';
import 'package:on_chain_wallet/wallet/models/others/models/receipt_address.dart';
import 'package:on_chain_wallet/wallet/models/transaction/transaction.dart';

class TransactionView<CHAINACCOUNT extends ChainAccount,
    TRANSACTION extends ChainTransaction> extends StatelessWidget {
  final TRANSACTION transaction;
  final APPCHAINACCOUNTTX<CHAINACCOUNT, TRANSACTION> account;
  final CHAINACCOUNT address;
  const TransactionView(
      {required this.transaction,
      required this.account,
      required this.address,
      super.key});

  @override
  Widget build(BuildContext context) {
    return ContainerWithBorder(
      onRemove: () {
        context.openSliverDialog(
            widget: (context) {
              return TransactionModalView<CHAINACCOUNT, TRANSACTION>(
                  transaction: transaction, account: account, address: address);
            },
            label: "transaction".tr,
            content: (c) => [
                  IconButton(
                      onPressed: () {
                        context.openSliverDialog(
                            widget: (ctx) => DialogTextView(
                                buttonWidget: AsyncDialogDoubleButtonView(
                                    firstButtonPressed: () => account
                                            .removeTransaction(
                                                address: address,
                                                transaction: transaction)
                                            .then((e) {
                                          ctx.pop();
                                        })),
                                text: "remove_transaction_from_account".tr),
                            label: 'remove_transaction'.tr);
                      },
                      icon: Icon(Icons.delete))
                ]);
      },
      onRemoveIcon: ConditionalWidgets(
        enable: transaction.type,
        widgets: {
          WalletTransactionType.send: (context) =>
              Icon(Icons.upload, color: context.onPrimaryContainer),
          WalletTransactionType.receive: (context) =>
              Icon(Icons.download, color: context.onPrimaryContainer),
          WalletTransactionType.web3: (context) =>
              Icon(CustomIcons.web3, color: context.onPrimaryContainer),
          WalletTransactionType.web3Tx: (context) =>
              Icon(CustomIcons.web3, color: context.onPrimaryContainer),
        },
      ),
      child: Row(
        children: [
          Expanded(
            child: ConditionalWidget(
              enable: transaction.totalOutput != null,
              onActive: (context) => CoinAndMarketPriceView(
                balance: transaction.totalOutput!.amount,
                showTokenImage: true,
                style: context.onPrimaryTextTheme.titleMedium,
                symbolColor: context.onPrimaryContainer,
              ),
              onDeactive: (context) => Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  OneLineTextWidget(transaction.txId,
                      style: context.onPrimaryTextTheme.bodyMedium),
                  ConditionalWidget(
                      enable: transaction.web3Client != null,
                      onActive: (context) => OneLineTextWidget(
                          transaction.web3Client!.name,
                          style: context.onPrimaryTextTheme.bodySmall)),
                ],
              ),
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(transaction.status.name.tr,
                  style: context.onPrimaryTextTheme.labelMedium),
              Text(transaction.time.toDateAndTime(),
                  style: context.onPrimaryTextTheme.bodySmall),
            ],
          )
        ],
      ),
    );
  }
}

class TransactionModalView<CHAINACCOUNT extends ChainAccount,
    TRANSACTION extends ChainTransaction> extends StatelessWidget {
  final TRANSACTION transaction;
  final APPCHAINACCOUNTTX<CHAINACCOUNT, TRANSACTION> account;
  final CHAINACCOUNT address;
  const TransactionModalView(
      {required this.transaction,
      required this.account,
      required this.address,
      super.key});

  @override
  Widget build(BuildContext context) {
    final txUrl = account.network.getTransactionExplorer(transaction.txId);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text("transaction_id".tr,
            style: context.onPrimaryTextTheme.titleMedium),
        WidgetConstant.height8,
        ContainerWithBorder(
          onRemove: () {},
          enableTap: false,
          onRemoveIcon:
              LaunchBrowserIcon(url: txUrl, color: context.onPrimaryContainer),
          child: CopyableTextWidget(
              text: transaction.txId, color: context.onPrimaryContainer),
        ),
        ConditionalWidget(
            enable: transaction.web3Client != null,
            onActive: (context) =>
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  WidgetConstant.height20,
                  Text("client".tr,
                      style: context.onPrimaryTextTheme.titleMedium),
                  WidgetConstant.height8,
                  ContainerWithBorder(
                    onRemove: () {},
                    enableTap: false,
                    onRemoveIcon: Icon(CustomIcons.web3,
                        color: context.onPrimaryContainer),
                    child: Row(children: [
                      CircleAPPImageView(transaction.web3Client!.image,
                          radius: APPConst.circleRadius25),
                      WidgetConstant.width8,
                      Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(transaction.web3Client!.name,
                                style: context.onPrimaryTextTheme.bodyMedium),
                            Text(transaction.web3Client!.applicationId,
                                style: context.onPrimaryTextTheme.bodySmall),
                          ]),
                    ]),
                  ),
                ])),
        WidgetConstant.height20,
        Text("status".tr, style: context.onPrimaryTextTheme.titleMedium),
        WidgetConstant.height8,
        ContainerWithBorder(
          child: Text(transaction.status.name.tr,
              style: context.onPrimaryTextTheme.bodyMedium),
        ),
        WidgetConstant.height20,
        ConditionalWidget(
            enable: transaction.totalOutput != null,
            onActive: (context) => Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text("total_amount".tr,
                        style: context.onPrimaryTextTheme.titleMedium),
                    WidgetConstant.height8,
                    ContainerWithBorder(
                      onRemoveIcon: ConditionalWidgets(
                        enable: transaction.type,
                        widgets: {
                          WalletTransactionType.send: (context) => Icon(
                                Icons.upload,
                                color: context.onPrimaryContainer,
                              ),
                          WalletTransactionType.web3: (context) => Icon(
                                Icons.upload,
                                color: context.onPrimaryContainer,
                              ),
                        },
                      ),
                      child: CoinAndMarketPriceView(
                          balance: transaction.totalOutput!.amount,
                          showTokenImage: true,
                          style: context.onPrimaryTextTheme.titleMedium,
                          symbolColor: context.onPrimaryContainer),
                    ),
                    WidgetConstant.height20,
                  ],
                )),
        ConditionalWidget(
            enable: transaction.outputs.isNotEmpty,
            onActive: (context) => Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    WidgetConstant.height20,
                    Text("outputs".tr,
                        style: context.onPrimaryTextTheme.titleMedium),
                    WidgetConstant.height8,
                    ListView.separated(
                        itemBuilder: (context, index) {
                          final output = transaction.outputs[index];
                          return switch (output.type) {
                            WalletTransactionOutputType.transfer =>
                              TransactionTransferOutputView(
                                  output:
                                      output as WalletTransactionTransferOutput,
                                  transaction: transaction),
                            WalletTransactionOutputType.operation =>
                              TransactionOperationOutputView(
                                  output: output
                                      as WalletTransactionOperationOutput),
                            _ => WidgetConstant.sizedBox
                          };
                        },
                        separatorBuilder: (context, index) =>
                            WidgetConstant.divider,
                        itemCount: transaction.outputs.length,
                        shrinkWrap: true,
                        physics: WidgetConstant.noScrollPhysics),
                  ],
                )),
        ConditionalWidget(
            enable: transaction.inputs.isNotEmpty,
            onActive: (context) => Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    WidgetConstant.height20,
                    Text("sources".tr,
                        style: context.onPrimaryTextTheme.titleMedium),
                    WidgetConstant.height8,
                    ListView.separated(
                        itemBuilder: (context, index) {
                          final input = transaction.inputs[index];
                          return switch (input.type) {
                            WalletTransactionInputType.operation =>
                              TransactionOperationInputView(
                                  input:
                                      input as WalletTransactionOperationInput,
                                  account: account),
                          };
                        },
                        separatorBuilder: (context, index) =>
                            WidgetConstant.divider,
                        itemCount: transaction.inputs.length,
                        shrinkWrap: true,
                        physics: WidgetConstant.noScrollPhysics),
                  ],
                ))
      ],
    );
  }
}

class TransactionOperationOutputView extends StatelessWidget {
  const TransactionOperationOutputView({required this.output, super.key});
  final WalletTransactionOperationOutput output;

  @override
  Widget build(BuildContext context) {
    return ContainerWithBorder(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ContainerWithBorder(
              backgroundColor: context.onPrimaryContainer,
              child: Text('operation'.tr,
                  style: context.primaryTextTheme.bodyMedium)),
          ContainerWithBorder(
              backgroundColor: context.onPrimaryContainer,
              child: Text(output.name,
                  style: context.primaryTextTheme.bodyMedium)),
          ConditionalWidget(
            enable: output.content != null,
            onActive: (context) => ContainerWithBorder(
              backgroundColor: context.onPrimaryContainer,
              child: LargeTextContainer(
                  text: output.content!, color: context.primaryContainer),
            ),
          )
        ],
      ),
    );
  }
}

class TransactionTransferOutputView extends StatelessWidget {
  const TransactionTransferOutputView(
      {required this.output, required this.transaction, super.key});
  final WalletTransactionTransferOutput output;
  final ChainTransaction transaction;

  @override
  Widget build(BuildContext context) {
    return ContainerWithBorder(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ContainerWithBorder(
              backgroundColor: context.onPrimaryContainer,
              child: Text('transfer'.tr,
                  style: context.primaryTextTheme.bodyMedium)),
          ContainerWithBorder(
              backgroundColor: context.onPrimaryContainer,
              child: CopyableTextWidget(
                  text: output.address, color: context.primaryContainer)),
          ContainerWithBorder(
            backgroundColor: context.onPrimaryContainer,
            child: CoinAndMarketPriceView(
              balance: output.amount.amount,
              showTokenImage: true,
              style: context.primaryTextTheme.titleMedium,
              symbolColor: context.primaryContainer,
            ),
          ),
          WidgetConstant.sizedBox
        ],
      ),
    );
  }
}

class TransactionOperationInputView extends StatefulWidget {
  const TransactionOperationInputView(
      {required this.input, required this.account, super.key});
  final WalletTransactionOperationInput input;
  final Chain account;

  @override
  State<TransactionOperationInputView> createState() =>
      _TransactionOperationInputViewState();
}

class _TransactionOperationInputViewState
    extends State<TransactionOperationInputView>
    with SafeState<TransactionOperationInputView> {
  late ReceiptAddress address;

  @override
  void initState() {
    super.initState();
    address = widget.account.getReceiptAddress(widget.input.addressStr) ??
        ReceiptAddress(
            view: widget.input.addressStr,
            networkAddress: widget.input.address);
  }

  @override
  Widget build(BuildContext context) {
    return ContainerWithBorder(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ContainerWithBorder(
              backgroundColor: context.onPrimaryContainer,
              child: Text(widget.input.operation,
                  style: context.primaryTextTheme.bodyMedium)),
          ContainerWithBorder(
              backgroundColor: context.onPrimaryContainer,
              child: CopyableTextWidget(
                color: context.primaryContainer,
                text: address.view,
                widget: ReceiptAddressDetailsView(
                    address: address, color: context.primaryContainer),
              )),
        ],
      ),
    );
  }
}
