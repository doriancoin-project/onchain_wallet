import 'package:blockchain_utils/cbor/cbor.dart';
import 'package:blockchain_utils/utils/binary/utils.dart';
import 'package:on_chain_wallet/app/error/exception/wallet_ex.dart';
import 'package:on_chain_wallet/app/serialization/cbor/cbor.dart';
import 'package:on_chain_wallet/wallet/constant/tags/constant.dart';

enum NFTType {
  ;

  final List<int> tag;
  const NFTType(this.tag);

  static NFTType fromTag(List<int>? tag) {
    return values.firstWhere(
      (e) => BytesUtils.bytesEqual(e.tag, tag),
      orElse: () => throw WalletExceptionConst.invalidNftInformation,
    );
  }
}

abstract class NFTCore with CborSerializable {
  abstract final String? uri;
  NFTType get type;
  String get identifier;

  static T deserialize<T extends NFTCore>({List<int>? bytes, CborObject? obj}) {
    throw WalletExceptionConst.invalidNftInformation;
  }
}
