import 'package:blockchain_utils/blockchain_utils.dart';
import 'package:on_chain_wallet/app/core.dart';
import 'package:on_chain_wallet/crypto/keys/keys.dart';
import 'package:on_chain_wallet/wallet/chain/account.dart';
import 'package:on_chain_wallet/crypto/coins/custom_coins/coins.dart';
import 'package:on_chain_wallet/crypto/requets/argruments/argruments.dart';
import 'package:on_chain_wallet/crypto/requets/messages/core/message.dart';
import 'package:on_chain_wallet/crypto/requets/messages/models/models/derive_address_response.dart';

final class WalletRequestDeriveAddress
    extends WalletRequest<CryptoDeriveAddressResponse, MessageArgsTwoBytes> {
  final NewAccountParams addressParams;
  const WalletRequestDeriveAddress._({required this.addressParams});

  factory WalletRequestDeriveAddress({
    required NewAccountParams addressParams,
  }) {
    return WalletRequestDeriveAddress._(addressParams: addressParams);
  }
  factory WalletRequestDeriveAddress.deserialize(
      {List<int>? bytes, CborObject? object, String? hex}) {
    final CborListValue values = CborSerializable.cborTagValue(
        cborBytes: bytes,
        object: object,
        hex: hex,
        tags: WalletRequestMethod.deriveAddress.tag);
    final addrParams =
        NewAccountParams.deserialize(object: values.elementAsCborTag(0));

    return WalletRequestDeriveAddress(addressParams: addrParams);
  }

  @override
  CborTagValue toCbor() {
    return CborTagValue(
        CborSerializable.fromDynamic([addressParams.toCbor()]), method.tag);
  }

  @override
  WalletRequestMethod get method => WalletRequestMethod.deriveAddress;
  static CryptoDeriveAddressResponse _deriveAddress(
      NewAccountParams addressParams, WalletMasterKeys wallet) {
    final keyRequest =
        AccessCryptoPrivateKeyRequest(index: addressParams.deriveIndex);
    final pubKey = wallet.readPublicKeys([keyRequest]).keys.first;
    return CryptoDeriveAddressResponse(
        accountParams: addressParams, publicKey: pubKey);
  }

  static CryptoDeriveAddressResponse deriveAddress(
      NewAccountParams addressParams, WalletMasterKeys wallet) {
    return _deriveAddress(addressParams, wallet);
  }

  @override
  Future<MessageArgsTwoBytes> getResult(WalletInMemory wallet) async {
    final deriveAddr = deriveAddress(addressParams, wallet.masterKey);
    return MessageArgsTwoBytes(
        keyOne: deriveAddr.accountParams.toCbor().encode(),
        keyTwo: deriveAddr.publicKey.toCbor().encode());
  }

  @override
  Future<CryptoDeriveAddressResponse> parsResult(
      MessageArgsTwoBytes result) async {
    return CryptoDeriveAddressResponse(
        accountParams: NewAccountParams.deserialize(bytes: result.keyOne),
        publicKey:
            CryptoPublicKeyData.fromCborBytesOrObject(bytes: result.keyTwo));
  }

  @override
  Future<CryptoDeriveAddressResponse> result(WalletInMemory wallet) async {
    return deriveAddress(addressParams, wallet.masterKey);
  }
}
