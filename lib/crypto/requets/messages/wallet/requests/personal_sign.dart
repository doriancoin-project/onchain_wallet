import 'package:blockchain_utils/blockchain_utils.dart';
import 'package:on_chain_wallet/app/core.dart';
import 'package:on_chain_wallet/crypto/keys/access/crypto_keys/crypto_keys.dart';
import 'package:on_chain_wallet/crypto/types/networks.dart';
import 'package:on_chain_wallet/crypto/requets/argruments/argruments.dart';
import 'package:on_chain_wallet/crypto/requets/messages/core/message.dart';
import 'package:on_chain_wallet/crypto/requets/messages/models/models/personal_sign_response.dart';

final class WalletRequestSignMessage
    extends WalletRequest<CryptoPersonalSignResponse, MessageArgsOneBytes> {
  final List<int> message;
  final Bip32AddressIndex index;
  final int? payloadLength;
  final NetworkType network;
  const WalletRequestSignMessage._({
    required this.message,
    required this.index,
    this.payloadLength,
    required this.network,
  });

  factory WalletRequestSignMessage(
      {required List<int> message,
      required Bip32AddressIndex index,
      NetworkType network = NetworkType.bitcoinAndForked,
      int? payloadLength}) {
    return WalletRequestSignMessage._(
      message: message.asImmutableBytes,
      index: index,
      network: network,
      payloadLength: payloadLength,
    );
  }
  factory WalletRequestSignMessage.deserialize(
      {List<int>? bytes, CborObject? object, String? hex}) {
    final CborListValue values = CborSerializable.cborTagValue(
        cborBytes: bytes,
        object: object,
        hex: hex,
        tags: WalletRequestMethod.signMessage.tag);
    return WalletRequestSignMessage(
        message: values.elementAs(0),
        index: Bip32AddressIndex.deserialize(obj: values.elementAsCborTag(1)),
        payloadLength: values.elementAs(2),
        network: NetworkType.fromTag(values.elementAs(3)));
  }

  @override
  CborTagValue toCbor() {
    return CborTagValue(
        CborSerializable.fromDynamic([
          CborBytesValue(message),
          index.toCbor(),
          payloadLength,
          network.tag
        ]),
        method.tag);
  }

  @override
  WalletRequestMethod get method => WalletRequestMethod.signMessage;
  static List<int> sign(
      {required WalletMasterKeys wallet,
      required Bip32AddressIndex index,
      required List<int> message,
      required NetworkType network,
      int? payloadLength}) {
    switch (network) {
      default:
        throw WalletExceptionConst.unsuportedFeature;
    }
  }

  @override
  Future<MessageArgsOneBytes> getResult(WalletInMemory wallet) async {
    final signature = sign(
        wallet: wallet.masterKey,
        index: index,
        message: message,
        network: network);
    return MessageArgsOneBytes(keyOne: signature);
  }

  @override
  Future<CryptoPersonalSignResponse> parsResult(
      MessageArgsOneBytes result) async {
    return CryptoPersonalSignResponse(
        signatureHex: BytesUtils.toHexString(result.keyOne, prefix: "0x"),
        signature: result.keyOne);
  }

  @override
  Future<CryptoPersonalSignResponse> result(WalletInMemory wallet) async {
    final signature = sign(
        wallet: wallet.masterKey,
        index: index,
        message: message,
        network: network);
    return CryptoPersonalSignResponse(
        signatureHex: BytesUtils.toHexString(signature, prefix: "0x"),
        signature: signature);
  }
}
