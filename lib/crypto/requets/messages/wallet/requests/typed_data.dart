import 'package:blockchain_utils/blockchain_utils.dart';
import 'package:on_chain_wallet/app/core.dart';
import 'package:on_chain_wallet/crypto/keys/keys.dart';
import 'package:on_chain_wallet/crypto/requets/argruments/argruments.dart';
import 'package:on_chain_wallet/crypto/requets/messages/core/message.dart';
final class WalletRequestEthereumTypedDataSign
    extends WalletRequest<String, MessageArgsOneBytes> {
  final EIP712Base message;
  final Bip32AddressIndex index;

  const WalletRequestEthereumTypedDataSign._(
      {required this.message, required this.index});

  factory WalletRequestEthereumTypedDataSign({
    required EIP712Base message,
    required Bip32AddressIndex index,
  }) {
    return WalletRequestEthereumTypedDataSign._(message: message, index: index);
  }
  factory WalletRequestEthereumTypedDataSign.deserialize(
      {List<int>? bytes, CborObject? object, String? hex}) {
    final CborListValue values = CborSerializable.cborTagValue(
        cborBytes: bytes,
        object: object,
        hex: hex,
        tags: WalletRequestMethod.ethereumTypedDataSign.tag);
    return WalletRequestEthereumTypedDataSign(
        message: EIP712Base.fromJson(StringUtils.toJson(values.elementAs(0))),
        index: Bip32AddressIndex.deserialize(obj: values.elementAsCborTag(1)));
  }

  @override
  CborTagValue toCbor() {
    return CborTagValue(
        CborSerializable.fromDynamic(
            [StringUtils.fromJson(message.toJson()), index.toCbor()]),
        method.tag);
  }

  @override
  WalletRequestMethod get method => WalletRequestMethod.ethereumTypedDataSign;

  static List<int> sign(
      {required WalletMasterKeys wallet,
      required Bip32AddressIndex index,
      required EIP712Base message,
      int? payloadLength}) {
    final responseKeys = wallet
        .readKeys([AccessCryptoPrivateKeyRequest(index: index)])
        .keys
        .first;
    final signer = ETHSigner.fromKeyBytes(responseKeys.privateKeyBytes());
    final sign = signer.signConst(message.encode(hash: false));
    return sign.toBytes();
  }

  @override
  Future<MessageArgsOneBytes> getResult(WalletInMemory wallet) async {
    final signature =
        sign(wallet: wallet.masterKey, index: index, message: message);
    return MessageArgsOneBytes(keyOne: signature);
  }

  @override
  Future<String> parsResult(MessageArgsOneBytes result) async {
    return BytesUtils.toHexString(result.keyOne, prefix: "0x");
  }

  @override
  Future<String> result(WalletInMemory wallet) async {
    final signature =
        sign(wallet: wallet.masterKey, index: index, message: message);
    return BytesUtils.toHexString(signature, prefix: "0x");
  }
}
