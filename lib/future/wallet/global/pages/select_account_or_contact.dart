import 'package:blockchain_utils/helper/extensions/extensions.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:on_chain_wallet/app/core.dart';
import 'package:on_chain_wallet/crypto/types/networks.dart';
import 'package:on_chain_wallet/crypto/utils/address/utils.dart';
import 'package:on_chain_wallet/future/state_managment/state_managment.dart';
import 'package:on_chain_wallet/future/wallet/global/global.dart';
import 'package:on_chain_wallet/future/wallet/global/pages/types.dart';
import 'package:on_chain_wallet/future/widgets/custom_widgets.dart';
import 'package:on_chain_wallet/wallet/wallet.dart';

typedef RecipientFilter<NETWORKADDRESS> = String? Function(
    NETWORKADDRESS address);
typedef OnSelectRecipients<NETWORKADDRESS>
    = Future<List<ReceiptAddress<NETWORKADDRESS>>?> Function(
        {required APPCHAINNETWORK<NETWORKADDRESS> account,
        RecipientFilter<NETWORKADDRESS>? onFilterAccount});

class SelectRecipientAccountView<NETWORKADDRESS> extends StatefulWidget {
  const SelectRecipientAccountView(
      {super.key,
      required this.account,
      required this.scrollController,
      this.title,
      this.multipleSelect = false,
      this.max,
      this.onFilterAccount});
  final APPCHAINNETWORK<NETWORKADDRESS> account;
  final ScrollController scrollController;
  final String? title;
  final int? max;
  final bool multipleSelect;
  final RecipientFilter<NETWORKADDRESS>? onFilterAccount;

  @override
  State<SelectRecipientAccountView<NETWORKADDRESS>> createState() =>
      _SelectRecipientAccountViewState<NETWORKADDRESS>();
}

class _SelectRecipientAccountViewState<NETWORKADDRESS>
    extends State<SelectRecipientAccountView<NETWORKADDRESS>>
    with SafeState<SelectRecipientAccountView<NETWORKADDRESS>> {
  List<ReceiptAddress<NETWORKADDRESS>> multipleReceipments = [];
  List<ReceiptAddress<NETWORKADDRESS>> existsAccounts = [];
  List<ReceiptAddress<NETWORKADDRESS>> filteredAccounts = [];
  bool get isDebug => kDebugMode;
  late final multipleSelect = widget.multipleSelect;
  bool showSubmit = false;
  final GlobalKey<AppTextFieldState> textFieldKey =
      GlobalKey(debugLabel: "SelectAddress");
  final GlobalKey<FormState> formKey = GlobalKey(debugLabel: "SelectAddress_1");
  late final WalletNetwork network = widget.account.network;
  late final bool isRippleNetwork = false;
  String _address = "";
  bool allowAddAddress = true;
  final StreamValue<ContactCore<NETWORKADDRESS>?> newContact =
      StreamValue(null);
  bool useRippleTag = false;
  int? rippleAddressTag;

  void checkAllowAddAddress() {
    final max = widget.max;
    allowAddAddress = max == null || multipleReceipments.length < max;
  }

  bool addReceipt(ReceiptAddress<NETWORKADDRESS>? receipt) {
    if (receipt == null) return false;
    final filter = widget.onFilterAccount;
    if (filter != null) {
      final validate = filter(receipt.networkAddress);
      if (validate != null) {
        context.showAlert(validate);
        return false;
      }
    }
    if (multipleSelect) {
      final r = multipleReceipments.remove(receipt);
      if (!r) {
        multipleReceipments.add(receipt);
      }
      checkAllowAddAddress();
      showSubmit = multipleReceipments.isNotEmpty;
      if (!existsAccounts.contains(receipt)) {
        existsAccounts = [receipt, ...existsAccounts];
      }

      rebuildFilterAccounts();
    } else {
      context.pop([receipt]);
      return false;
    }
    return true;
  }

  void rebuildFilterAccounts() {
    if (_address.trim().isEmpty) {
      filteredAccounts = existsAccounts.clone();
    } else {
      final lower = _address.toLowerCase();
      filteredAccounts = existsAccounts
          .where((e) => (e.view.toLowerCase().contains(lower) ||
              (e.contact?.name.contains(lower) ?? false)))
          .toList();
    }
    updateState();
  }

  void onChange(String v) {
    _address = v;
    rebuildFilterAccounts();
  }

  void onChangeTag(int v) {
    rippleAddressTag = v;
  }

  void onUseRippleTag(bool? v) {
    useRippleTag = !useRippleTag;
    rippleAddressTag = null;
    updateState();
  }

  ContactCore<NETWORKADDRESS>? _toNewContact(Object? addr) {
    return ContactCore.newContact(
        network: network, address: addr, name: "new_address".tr);
  }

  ContactCore<NETWORKADDRESS>? _validate(String? address) {
    final addr =
        BlockchainAddressUtils.validateNetworkAddress(address, network);
    if (addr == null) return null;
    return _toNewContact(addr as NETWORKADDRESS);
  }

  (ContactCore<NETWORKADDRESS>?, String? error) _validateRipple(
      String? address, int? tag) {
    if (address == null) return (null, null);
    final addr = MethodUtils.nullOnException(() {
      if (address.trim().isEmpty) return null;
      return BlockchainAddressUtils.toRippleAddress(
          address, network.toNetwork());
    });
    if (addr == null) return (null, null);
    if (tag != null) {
      if (addr.tag == tag) return (_toNewContact(addr), null);
      if (addr.tag != null && addr.tag != tag) {
        return (null, "ripple_xaddress_tag_validator".tr);
      }
      final newAddress = BlockchainAddressUtils.validateXAddressTag(
          addr: address, network: network.toNetwork(), tag: tag);
      return (_toNewContact(newAddress), null);
    }
    return (_toNewContact(addr), null);
  }

  void _setValidate(ContactCore<NETWORKADDRESS>? contact) {
    if (contact == null) {
      newContact.value = null;
    } else {
      final inContact = widget.account.getReceiptAddress(contact.address);

      if (inContact != null) {
        newContact.value = null;
      } else {
        newContact.value = contact;
      }
      if (isDebug) {
        newContact.value = contact;
      }
    }
    // MethodUtils.after(() async => updateState());
  }

  String? validatorTag(String? v) {
    final int? tag = int.tryParse(v ?? "");
    if (tag == null || tag != rippleAddressTag) {
      return "ripple_address_validator_desc".tr;
    }
    return null;
  }

  String? validator(String? v) {
    ContactCore<NETWORKADDRESS>? addr;
    String? error;
    if (isRippleNetwork) {
      final validate = _validateRipple(v, rippleAddressTag);
      addr = validate.$1;
      error = validate.$2;
    } else {
      addr = _validate(v);
    }
    _setValidate(addr);
    if (useRippleTag && rippleAddressTag == null) {
      return "ripple_address_validator_desc".tr;
    }
    if (addr == null) {
      return error ??
          "invalid_network_address"
              .tr
              .replaceOne(widget.account.network.networkName);
    }
    final filter = widget.onFilterAccount;
    if (filter != null) return filter(addr.addressObject);
    return null;
  }

  void onPaste(String v) {
    textFieldKey.currentState?.updateText(v);
  }

  ReceiptAddress<NETWORKADDRESS> _buildReceiptAddress(ContactCore addr) {
    return ReceiptAddress<NETWORKADDRESS>(
        view: addr.address,
        type: addr.type,
        networkAddress: addr.addressObject);
  }

  void onAddReceipt() {
    if (!formKey.ready()) return;
    ContactCore<NETWORKADDRESS>? addr;
    if (isRippleNetwork) {
      final validate = _validateRipple(_address, rippleAddressTag);
      addr = validate.$1;
    } else {
      addr = _validate(_address);
    }

    if (addr != null) {
      final ReceiptAddress<NETWORKADDRESS> receipt =
          widget.account.getReceiptAddress(addr.address) ??
              _buildReceiptAddress(addr);
      if (addReceipt(receipt)) {
        textFieldKey.currentState?.clear();
      }
    }
  }

  void onTapContact() {
    final contact = newContact.value;
    if (contact == null) return;
    context.openSliverBottomSheet(
      "new_contact".tr,
      child: AddToContactListView<NETWORKADDRESS>(
        contact: contact,
        chain: widget.account,
        callBack: (p0) {
          final contact = widget.account.getReceiptAddress(p0.address);
          if (contact != null) {
            existsAccounts.remove(contact);
            existsAccounts.add(contact);
            rebuildFilterAccounts();
          }
        },
      ),
    );
  }

  @override
  void onInitOnce() {
    super.onInitOnce();
    existsAccounts = [];
    final contacts = widget.account.contacts
        .map((e) => ReceiptAddress<NETWORKADDRESS>(
            view: e.address,
            networkAddress: e.addressObject,
            contact: e as ContactCore<NETWORKADDRESS>,
            type: e.type))
        .toList();
    final accounts = widget.account.addresses
        .map((e) => ReceiptAddress<NETWORKADDRESS>(
            view: e.address.address,
            networkAddress: e.networkAddress,
            type: e.type,
            account: e))
        .toList();
    contacts.removeWhere((e) => accounts.contains(e));
    existsAccounts
        .removeWhere((e) => accounts.contains(e) || contacts.contains(e));

    existsAccounts = {...existsAccounts, ...accounts, ...contacts}.toList();
    final filter = widget.onFilterAccount;
    if (filter != null) {
      existsAccounts = existsAccounts
          .where((e) => filter(e.networkAddress) == null)
          .toList();
    }
    filteredAccounts = existsAccounts.clone();
    checkAllowAddAddress();
  }

  @override
  void safeDispose() {
    super.safeDispose();
    newContact.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title?.tr ?? "recipient".tr),
        actions: [
          CircleTokenImageView(widget.account.network.token,
              radius: APPConst.circleRadius12),
          WidgetConstant.width8,
        ],
      ),
      floatingActionButton: APPAnimatedSize(
          isActive: showSubmit,
          onActive: (context) => Badge.count(
                count: multipleReceipments.length,
                child: FloatingActionButton.extended(
                  onPressed: () => context.pop(multipleReceipments),
                  icon: Icon(Icons.check_circle),
                  label: Text("setup_addresses".tr),
                ),
              ),
          onDeactive: (context) => null),
      body: switch (isRippleNetwork) {
        false => _WriteAddress(state: this),
        true => _WriteRippleAddress(state: this)
      },
    );
  }
}

class _SelectFromAccounts extends StatelessWidget {
  const _SelectFromAccounts({required this.state});
  final _SelectRecipientAccountViewState state;
  @override
  Widget build(BuildContext context) {
    return EmptyItemSliverWidgetView(
      isEmpty: state.filteredAccounts.isEmpty,
      itemBuilder: (context) => SliverList.builder(
          itemCount: state.filteredAccounts.length,
          itemBuilder: (context, index) {
            final addr = state.filteredAccounts[index];
            return ContainerWithBorder(
              onRemove: () {
                state.addReceipt(addr);
              },
              onRemoveWidget:
                  ConditionalWidgets(enable: state.multipleSelect, widgets: {
                true: (context) => IgnorePointer(
                      child: Checkbox(
                          value: state.multipleReceipments.contains(addr),
                          onChanged: (v) {}),
                    )
              }),
              child: ReceiptAddressDetailsView(
                  address: addr, color: context.onPrimaryContainer),
            );
          }),
      icon: Icons.account_box_rounded,
    );
  }
}

class _WriteAddress extends StatelessWidget {
  const _WriteAddress({required this.state});
  final _SelectRecipientAccountViewState state;
  @override
  Widget build(BuildContext context) {
    return CustomScrollView(
        controller: state.widget.scrollController,
        slivers: [
          SliverConstraintsBoxView(
              padding: WidgetConstant.paddingHorizontal20,
              sliver: MultiSliver(children: [
                SliverToBoxAdapter(
                  child: Form(
                    key: state.formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        AppTextField(
                          key: state.textFieldKey,
                          label: "address".tr,
                          minlines: 1,
                          initialValue: state._address,
                          maxLines: 2,
                          suffixIcon: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              APPStreamBuilder(
                                value: state.newContact,
                                builder: (context, value) =>
                                    APPAnimatedSwitcher(
                                  widgets: {
                                    true: (c) => IconButton(
                                          onPressed: () {
                                            state.onTapContact();
                                          },
                                          icon:
                                              const Icon(Icons.account_circle),
                                        ),
                                    false: (c) => PasteTextIcon(
                                          onPaste: state.onPaste,
                                          isSensitive: false,
                                        )
                                  },
                                  enable: value != null,
                                ),
                              ),
                              BarcodeScannerIconView(state.onPaste),
                            ],
                          ),
                          validator: state.validator,
                          onChanged: state.onChange,
                        ),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            FixedElevatedButton(
                                padding: WidgetConstant.paddingVertical40,
                                onPressed: state.onAddReceipt,
                                child: ConditionalWidgets(
                                    enable: state.multipleSelect,
                                    widgets: {
                                      false: (context) =>
                                          Text("setup_address".tr),
                                      true: (context) =>
                                          Text("add_to_address".tr)
                                    }))
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                _SelectFromAccounts(state: state),
                WidgetConstant.sliverPaddingVertial40
              ])),
        ]);
  }
}

class _WriteRippleAddress extends StatelessWidget {
  const _WriteRippleAddress({required this.state});
  final _SelectRecipientAccountViewState state;
  @override
  Widget build(BuildContext context) {
    return CustomScrollView(
        controller: state.widget.scrollController,
        slivers: [
          SliverConstraintsBoxView(
              padding: WidgetConstant.paddingHorizontal20,
              sliver: MultiSliver(children: [
                SliverToBoxAdapter(
                  child: Form(
                    key: state.formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        AppTextField(
                          key: state.textFieldKey,
                          label: "address".tr,
                          minlines: 1,
                          initialValue: state._address,
                          maxLines: 2,
                          suffixIcon: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              APPStreamBuilder(
                                value: state.newContact,
                                builder: (context, value) {
                                  return APPAnimatedSwitcher(
                                    widgets: {
                                      true: (c) => IconButton(
                                            onPressed: () {
                                              state.onTapContact();
                                            },
                                            icon: const Icon(
                                                Icons.account_circle),
                                          ),
                                      false: (c) => PasteTextIcon(
                                            onPaste: state.onPaste,
                                            isSensitive: false,
                                          )
                                    },
                                    enable: value != null,
                                  );
                                },
                              ),
                              BarcodeScannerIconView(state.onPaste),
                            ],
                          ),
                          validator: state.validator,
                          onChanged: state.onChange,
                        ),
                        WidgetConstant.height20,
                        AppCheckListTile(
                          contentPadding: EdgeInsets.zero,
                          title: Text("insert_address_tag".tr,
                              style: context.textTheme.titleMedium),
                          subtitle: Text("ripple_xaddress_feature".tr),
                          onChanged: state.onUseRippleTag,
                          value: state.useRippleTag,
                        ),
                        APPAnimatedSize(
                            isActive: state.useRippleTag,
                            onActive: (c) => Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    WidgetConstant.height8,
                                    NumberTextField(
                                        label: "tag".tr,
                                        onChange: state.onChangeTag,
                                        max: RippleConst.maxRippleTag,
                                        defaultValue: state.rippleAddressTag,
                                        validator: state.validatorTag,
                                        min: 0),
                                  ],
                                ),
                            onDeactive: (c) => WidgetConstant.sizedBox),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            FixedElevatedButton(
                                padding: WidgetConstant.paddingVertical40,
                                onPressed: state.onAddReceipt,
                                child: ConditionalWidgets(
                                    enable: state.multipleSelect,
                                    widgets: {
                                      false: (context) =>
                                          Text("setup_address".tr),
                                      true: (context) =>
                                          Text("add_to_address".tr)
                                    }))
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                _SelectFromAccounts(state: state),
                WidgetConstant.sliverPaddingVertial40
              ])),
        ]);
  }
}
