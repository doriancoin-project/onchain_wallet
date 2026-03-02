import 'package:blockchain_utils/blockchain_utils.dart';
import 'package:on_chain_wallet/app/core.dart';
import 'package:on_chain_wallet/crypto/keys/keys.dart';
import 'package:on_chain_wallet/wallet/chain/account.dart';
import 'package:on_chain_wallet/wallet/models/networks/cardano/models/address_details.dart';
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
  static CryptoDeriveAddressResponse _deriveCardanoAddress(
      CardanoNewAddressParams params, WalletMasterKeys wallet) {
    final bool byronLegacy = params.coin.proposal == CustomProposal.cip0019;
    AccessCryptoPrivateKeyRequest keyRequest = AccessCryptoPrivateKeyRequest(
        index: params.deriveIndex.cast(),
        maxLevel: (byronLegacy ? Bip44Levels.master : Bip44Levels.addressIndex)
            .value);
    final bip = wallet.readPublicKeys([keyRequest]).keys.first;
    final CardanoAddrDetails addrDetails;
    switch (params.addressType) {
      case ADAAddressType.base:
        keyRequest =
            AccessCryptoPrivateKeyRequest(index: params.rewardKeyIndex!);
        final stake = wallet.readPublicKeys([keyRequest]).keys.first;
        addrDetails = CardanoAddrDetails.shelley(
            publicKey: bip.keyBytes(),
            stakePubkey: stake.keyBytes(),
            addressType: params.addressType,
            seedGeneration: params.deriveIndex.seedGeneration);
        break;
      case ADAAddressType.enterprise:
      case ADAAddressType.reward:
        addrDetails = CardanoAddrDetails.shelley(
            publicKey: bip.keyBytes(),
            addressType: params.addressType,
            seedGeneration: params.deriveIndex.seedGeneration);
        break;
      case ADAAddressType.byron:
        if (byronLegacy) {
          final adaPubKey = (bip as AdaLegacyPublicKeyData);
          addrDetails = CardanoAddrDetails.byron(
              publicKey: bip.keyBytes(),
              chainCode: adaPubKey.chainCodeBytes(),
              seedGeneration: params.deriveIndex.seedGeneration,
              hdPathKey: params.customHdPathKey ?? adaPubKey.hdPathKeyBytes(),
              hdPath: params.customHdPath ?? params.deriveIndex.hdPath);
          break;
        }

        addrDetails = CardanoAddrDetails.byron(
            publicKey: bip.keyBytes(),
            chainCode: bip.chainCodeBytes()!,
            seedGeneration: params.deriveIndex.seedGeneration);
        break;
      default:
        throw UnimplementedError();
    }
    return CryptoDeriveAddressResponse(
        accountParams:
            params.copyWith(addressDetails: addrDetails) as NewAccountParams,
        publicKey: bip);
  }

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
    switch (addressParams.type) {
      case NewAccountParamsType.cardanoNewAddressParams:
        return _deriveCardanoAddress(
            addressParams as CardanoNewAddressParams, wallet);
      default:
        return _deriveAddress(addressParams, wallet);
    }
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
