import 'package:blockchain_utils/cbor/core/cbor.dart';
import 'package:on_chain_wallet/app/error/exception/wallet_ex.dart';
import 'package:blockchain_utils/utils/equatable/equatable.dart';
import 'package:on_chain_wallet/app/serialization/serialization.dart';
import 'package:on_chain_wallet/wallet/models/contact/networks/bitcoin.dart';
import 'package:on_chain_wallet/wallet/models/network/core/network.dart';
import 'package:on_chain_wallet/crypto/types/networks.dart';

abstract class ContactCore<T> with CborSerializable, Equality {
  final T addressObject;
  String get address;
  final String name;
  final DateTime created;
  String? get type;

  String get identifier => address;
  @override
  List get variabels => [address];

  const ContactCore(
      {required this.addressObject, required this.name, required this.created});

  static T deserialize<T extends ContactCore>(WalletNetwork network,
      {List<int>? bytes, CborObject? obj}) {
    ContactCore contact;
    switch (network.type) {
      case NetworkType.bitcoinAndForked:
      case NetworkType.bitcoinCash:
        contact = BitcoinContact.deserialize(network.toNetwork(),
            bytes: bytes, obj: obj);
        break;
      default:
        throw WalletExceptionConst.networkDoesNotExist;
    }
    if (contact is! T) {
      throw WalletExceptionConst.internalError("ContactCore");
    }
    return contact;
  }

  static T newContact<T extends ContactCore>(
      {required WalletNetwork network,
      required dynamic address,
      required String name}) {
    ContactCore contact;
    switch (network.type) {
      case NetworkType.bitcoinAndForked:
      case NetworkType.bitcoinCash:
        contact = BitcoinContact.newContact(
            address: address, network: network.toNetwork(), name: name);
      default:
        throw WalletExceptionConst.networkDoesNotExist;
    }
    if (contact is! T) {
      throw WalletExceptionConst.internalError("ContactCore");
    }
    return contact;
  }
}
