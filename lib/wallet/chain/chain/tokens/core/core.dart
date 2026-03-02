part of 'package:on_chain_wallet/wallet/chain/chain/chain.dart';

enum TokenCoreType {
  ripple(CborTagsConst.rippleIssueToken);

  final List<int> tag;
  const TokenCoreType(this.tag);
  static TokenCoreType fromTag(List<int>? tag) {
    return values.firstWhere((e) => BytesUtils.bytesEqual(e.tag, tag),
        orElse: () =>
            throw AppSerializationException(objectName: "TokenCoreType"));
  }
}

abstract class TokenCore<T extends BalanceCore, TOKEN extends APPToken>
    with CborSerializable, Equality {
  static String toIdentifier(String data) {
    final hash = QuickCrypto.sha256Hash(StringUtils.encode(data));
    return StringUtils.decode(hash, type: StringEncoding.base64UrlSafe);
  }

  final TOKEN token;
  final InternalStreamValue<T> streamBalance;
  DateTime _updated;
  DateTime get updated => _updated;
  TokenCore._(
      {required this.token, required T balance, required DateTime updated})
      : _updated = updated,
        streamBalance =
            InternalStreamValue<T>.immutable(balance, allowDispose: true);
  T get balance => streamBalance.value;
  String? get issuer;
  String? get type;
  TokenCore clone();
  TokenCore updateToken(Token updateToken);
  TokenCoreType get tokenType;
  String get identifier;

  static T deserialize<T extends TokenCore>(
      {List<int>? bytes, CborObject? obj}) {
    final CborTagValue tag =
        CborSerializable.decode(cborBytes: bytes, object: obj);
    final type = TokenCoreType.fromTag(tag.tags);
    final TokenCore tokenCore = switch (type) {
      TokenCoreType.ripple =>
        RippleIssueToken.deserialize(bytes: bytes, obj: obj),
    };
    if (tokenCore is! T) {
      throw WalletExceptionConst.internalError("TokenCore");
    }
    return tokenCore;
  }
}
