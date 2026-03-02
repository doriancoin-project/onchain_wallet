import 'package:bitcoin_base/bitcoin_base.dart' show TaprootUtils;
import 'package:blockchain_utils/blockchain_utils.dart';
import 'package:on_chain_wallet/app/core.dart';
import 'package:on_chain_wallet/crypto/keys/access/crypto_keys/crypto_keys.dart';
import 'package:on_chain_wallet/crypto/requets/argruments/argruments.dart';
import 'package:on_chain_wallet/crypto/requets/messages/core/message.dart';
import 'package:on_chain_wallet/crypto/requets/messages/models/models/signing.dart';
import 'package:on_chain_wallet/crypto/requets/messages/models/models/signing_response.dart';

final class WalletRequestSign
    extends WalletRequest<GlobalSignResponse, MessageArgsOneBytes> {
  final SignRequest request;
  const WalletRequestSign._(this.request);

  factory WalletRequestSign(SignRequest request) {
    return WalletRequestSign._(request);
  }
  factory WalletRequestSign.deserialize(
      {List<int>? bytes, CborObject? object, String? hex}) {
    final CborListValue values = CborSerializable.cborTagValue(
        cborBytes: bytes,
        object: object,
        hex: hex,
        tags: WalletRequestMethod.sign.tag);
    return WalletRequestSign(
        SignRequest.deserialize(object: values.elementAsCborTag(0)));
  }

  @override
  CborTagValue toCbor() {
    return CborTagValue(
        CborSerializable.fromDynamic([request.toCbor()]), method.tag);
  }

  @override
  WalletRequestMethod get method => WalletRequestMethod.sign;

  static GlobalSignResponse globalSigning(
      {required CryptoPrivateKeyData key, required GlobalSignRequest request}) {
    final List<int> digest = request.digest;
    final index = request.index;
    switch (request.network) {
      case SigningRequestMode.bitcoinCash:
        final BitcoinSigning bitcoinRequest = request.cast();
        final btcSigner = BitcoinKeySigner.fromKeyBytes(key.privateKeyBytes());
        List<int> sig;
        if (bitcoinRequest.useBchSchnorr) {
          sig = btcSigner.signSchnorrConst(digest);
        } else {
          sig = btcSigner.signECDSADerConst(digest);
        }
        final sighash = bitcoinRequest.sighash;
        final signature = [...sig, if (sighash != null) sighash];

        return GlobalSignResponse(
            signature: signature, index: index, signerPubKey: key.publicKey);
      case SigningRequestMode.bitcoin:
        final BitcoinSigning bitcoinRequest = request.cast();
        final btcSigner = BitcoinKeySigner.fromKeyBytes(key.privateKeyBytes());
        final sighash = bitcoinRequest.sighash;
        if (bitcoinRequest.useTaproot) {
          final taptweak = TaprootUtils.calculateTweek(
              btcSigner.verifierKey.publicKeyPoint().toXonly());
          List<int> schnorrSignature =
              btcSigner.signBip340Const(digest: digest, tapTweakHash: taptweak);
          if (bitcoinRequest.sighash != 0x00) {
            schnorrSignature = [
              ...schnorrSignature,
              if (sighash != null) sighash
            ];
          }
          return GlobalSignResponse(
              signature: schnorrSignature,
              index: index,
              signerPubKey: key.publicKey);
        } else {
          final sig = btcSigner.signECDSADerConst(digest);
          final signature = [...sig, if (sighash != null) sighash];
          return GlobalSignResponse(
              signature: signature, index: index, signerPubKey: key.publicKey);
        }
    }
  }

  @override
  Future<MessageArgsOneBytes> getResult(WalletInMemory wallet) async {
    final sign = await result(wallet);
    return MessageArgsOneBytes(keyOne: sign.toCbor().encode());
  }

  @override
  Future<GlobalSignResponse> parsResult(MessageArgsOneBytes result) async {
    return GlobalSignResponse.deserialize(result.keyOne);
  }

  @override
  Future<GlobalSignResponse> result(WalletInMemory wallet) async {
    final key = wallet.masterKey
        .readKeys([AccessCryptoPrivateKeyRequest(index: request.index)])
        .keys
        .first;
    return globalSigning(key: key, request: request.cast());
  }
}
