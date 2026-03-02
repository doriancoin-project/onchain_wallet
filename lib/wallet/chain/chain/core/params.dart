part of 'package:on_chain_wallet/wallet/chain/chain/chain.dart';

enum NewAccountParamsType {
  bitcoinCashNewAddressParams(CborTagsConst.bitcoinCashNewAddressParams),
  bitcoinCashMultiSigNewAddressParams(
      CborTagsConst.bitcoinCashMultiSigNewAddressParams),
  bitcoinNewAddressParams(CborTagsConst.bitcoinNewAddressParams),
  bitcoinMultiSigNewAddressParams(
      CborTagsConst.bitcoinMultiSigNewAddressParams);

  final List<int> tag;
  const NewAccountParamsType(this.tag);
  static NewAccountParamsType fromTag(List<int>? tag) {
    return values.firstWhere((e) => BytesUtils.bytesEqual(e.tag, tag),
        orElse: () => throw AppSerializationException(
            objectName: "NewAccountParamsType"));
  }
}

abstract final class NewAccountParams<ACCOUNT extends ChainAccount>
    with CborSerializable {
  const NewAccountParams._();
  abstract final CryptoCoins coin;
  abstract final AddressDerivationIndex deriveIndex;
  abstract final NewAccountParamsType type;
  bool get isMultiSig;
  ACCOUNT toAccount(WalletNetwork network, CryptoPublicKeyData? publicKey);

  static String toIdentifier(String address,
      {List<int> multisigAddress = const []}) {
    final hash = QuickCrypto.sha256Hash(
        [...StringUtils.encode(address), ...multisigAddress]);
    return StringUtils.decode(hash, type: StringEncoding.base64UrlSafe);
  }

  factory NewAccountParams.deserialize(
      {List<int>? bytes, CborObject? object, String? hex}) {
    final CborTagValue decode =
        CborSerializable.decode(cborBytes: bytes, object: object, hex: hex);
    final type = NewAccountParamsType.fromTag(decode.tags);
    final NewAccountParams params;
    switch (type) {
      case NewAccountParamsType.bitcoinCashNewAddressParams:
        params = BitcoinCashNewAddressParams.deserialize(object: decode);
        break;
      case NewAccountParamsType.bitcoinCashMultiSigNewAddressParams:
        params =
            BitcoinCashMultiSigNewAddressParams.deserialize(object: decode);
        break;
      case NewAccountParamsType.bitcoinNewAddressParams:
        params = BitcoinNewAddressParams.deserialize(object: decode);
        break;
      case NewAccountParamsType.bitcoinMultiSigNewAddressParams:
        params = BitcoinMultiSigNewAddressParams.deserialize(object: decode);
        break;
    }
    if (params is! NewAccountParams<ACCOUNT>) {
      throw WalletExceptionConst.internalError("NewAccountParams.deserialize");
    }
    return params;
  }
}
