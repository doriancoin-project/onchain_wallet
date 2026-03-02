import 'package:blockchain_utils/bip/bip.dart';
import 'package:blockchain_utils/cbor/cbor.dart';
import 'package:blockchain_utils/helper/helper.dart';

import 'package:blockchain_utils/utils/binary/utils.dart';
import 'package:on_chain_wallet/app/error/exception/app_exception.dart';
import 'package:on_chain_wallet/app/error/exception/wallet_ex.dart';
import 'package:on_chain_wallet/app/serialization/serialization.dart';
import 'package:on_chain_wallet/crypto/keys/access/crypto_keys/crypto_keys.dart';
import 'signing_response.dart';

typedef OnSignRequest = Future<GlobalSignResponse> Function(SignRequest);

abstract final class SignRequest with CborSerializable {
  final AddressDerivationIndex index;
  final SigningRequestMode network;
  const SignRequest({required this.index, required this.network});
  factory SignRequest.deserialize(
      {List<int>? bytes, CborObject? object, String? hex}) {
    final CborTagValue tag =
        CborSerializable.decode(cborBytes: bytes, hex: hex, object: object);
    final network = SigningRequestMode.fromTag(tag.tags);
    return switch (network) {
      SigningRequestMode.bitcoin ||
      SigningRequestMode.bitcoinCash =>
        BitcoinSigning.deserialize(object: tag),
      _ => GlobalSignRequest.deserialize(object: tag)
    };
  }
  T cast<T extends SignRequest>() {
    if (this is! T) {
      throw AppCryptoExceptionConst.internalError("SignRequest");
    }
    return this as T;
  }
}

enum SigningRequestMode {
  bitcoin([32, 100]),
  bitcoinCash([32, 111]);

  final List<int> tag;
  const SigningRequestMode(this.tag);
  static SigningRequestMode fromTag(List<int> tag) {
    return values.firstWhere(
        (element) => BytesUtils.bytesEqual(tag, element.tag),
        orElse: () =>
            throw AppSerializationException(objectName: "SigningRequestMode"));
  }
}

final class BitcoinSigning extends GlobalSignRequest {
  final int? sighash;
  final bool useTaproot;
  final bool useBchSchnorr;
  BitcoinSigning(
      {required super.digest,
      this.sighash,
      required this.useTaproot,
      required Bip32AddressIndex super.index,
      required super.network,
      required this.useBchSchnorr})
      : assert(
            network == SigningRequestMode.bitcoin ||
                network == SigningRequestMode.bitcoinCash,
            "invalid bitcoin network."),
        super._();

  factory BitcoinSigning.deserialize({
    List<int>? bytes,
    CborObject? object,
    String? hex,
  }) {
    final CborTagValue tag =
        CborSerializable.decode(cborBytes: bytes, object: object, hex: hex);
    final network = SigningRequestMode.fromTag(tag.tags);
    if (network != SigningRequestMode.bitcoin &&
        network != SigningRequestMode.bitcoinCash) {
      throw AppCryptoExceptionConst.internalError("BitcoinSigning");
    }
    final CborListValue values = tag.valueAs();
    return BitcoinSigning(
        digest: values.elementAs(1),
        sighash: values.elementAs(2),
        useTaproot: values.elementAs(3),
        index: Bip32AddressIndex.deserialize(obj: values.elementAsCborTag(0)),
        network: network,
        useBchSchnorr: values.elementAs(4));
  }
  @override
  CborTagValue toCbor() {
    return CborTagValue(
        CborSerializable.fromDynamic(
            [index.toCbor(), digest, sighash, useTaproot, useBchSchnorr]),
        network.tag);
  }
}

final class GlobalSignRequest extends SignRequest {
  final List<int> digest;
  GlobalSignRequest._({
    required List<int> digest,
    required super.network,
    required super.index,
  }) : digest = digest.asImmutableBytes;

  factory GlobalSignRequest.deserialize({
    List<int>? bytes,
    CborObject? object,
    String? hex,
  }) {
    final CborTagValue tag =
        CborSerializable.decode(cborBytes: bytes, hex: hex, object: object);
    final CborListValue values = tag.valueAs();
    final index =
        AddressDerivationIndex.deserialize(obj: values.elementAsCborTag(0));
    final List<int> digest = values.elementAs(1);
    final network = SigningRequestMode.fromTag(tag.tags);
    return GlobalSignRequest._(digest: digest, network: network, index: index);
  }

  @override
  CborTagValue toCbor() {
    return CborTagValue(
        CborSerializable.fromDynamic([index.toCbor(), digest]), network.tag);
  }
}

