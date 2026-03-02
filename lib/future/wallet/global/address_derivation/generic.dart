import 'package:flutter/material.dart';
import 'package:on_chain_wallet/crypto/types/networks.dart';
import 'controller.dart';

class SetupGenericAddressView extends StatelessWidget {
  const SetupGenericAddressView({super.key, required this.controller});
  final AddressDerivationController controller;

  @override
  Widget build(BuildContext context) {
    switch (controller.network.type) {
      default:
        throw UnimplementedError("invalid network");
    }
  }
}
