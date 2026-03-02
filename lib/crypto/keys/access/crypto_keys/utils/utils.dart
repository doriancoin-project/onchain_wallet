part of 'package:on_chain_wallet/crypto/keys/access/crypto_keys/crypto_keys.dart';

class CryptoKeyUtils {
  static List<int> privateKeyToBytes(
      {required String privateKey, required CryptoCoins coin}) {
    return IPrivateKey.fromBytes(
            BytesUtils.fromHexString(privateKey), coin.conf.type)
        .raw;
  }

  static List<int> _toSecretKeyBytes(
      {required List<int> keypair, required EllipticCurveTypes type}) {
    const int ed25519KeyPairLength =
        Ed25519KeysConst.privKeyByteLen + Ed25519KeysConst.pubKeyByteLen;
    if (keypair.length != ed25519KeyPairLength) return keypair;
    switch (type) {
      case EllipticCurveTypes.ed25519:
      case EllipticCurveTypes.ed25519Blake2b:
        return keypair.sublist(0, Ed25519KeysConst.privKeyByteLen);
      default:
        return keypair;
    }
  }

  static ImportedKeyStorage extendeKeyToStorage(
      {required String extendedKey,
      required CryptoCoins coin,
      String? keyName}) {
    if (coin.conf is! BipCoinConfig) {
      throw AppCryptoExceptionConst.invalidCoin;
    }
    final key = extendedKeyToBip32Key(extendedKey: extendedKey, coin: coin);
    return ImportedKeyStorage._(
      checksum: _createCustomKeyChecksum(
          pubkeyBytes: key.publicKey.compressed,
          chainCode: key.chainCode.toBytes(),
          coin: coin),
      extendedPrivateKey: key.privateKey.toExtended,
      coin: coin,
      publicKey: key.publicKey.toHex(),
      name: keyName,
      keyType: CustomKeyType.extendedKey,
    );
  }

  static ImportedKeyStorage privateKeyToStorage(
      {required String privateKey,
      required CryptoCoins coin,
      String? keyName}) {
    return _privateKeyToStorage(
        keyBytes: BytesUtils.fromHexString(privateKey),
        coin: coin,
        keyName: keyName);
  }

  static IPrivateKey _validatePrivateKey(
      {required List<int> keyBytes, required CryptoCoins coin}) {
    return IPrivateKey.fromBytes(keyBytes, coin.conf.type);
  }

  static ImportedKeyStorage _privateKeyToStorage(
      {required List<int> keyBytes,
      required CryptoCoins coin,
      String? keyName}) {
    final secretKeyBytes =
        _toSecretKeyBytes(keypair: keyBytes, type: coin.conf.type);
    final key = _validatePrivateKey(keyBytes: secretKeyBytes, coin: coin);
    return ImportedKeyStorage._(
        checksum: _createCustomKeyChecksum(
            pubkeyBytes: key.publicKey.compressed, coin: coin),
        extendedPrivateKey: key.toHex(),
        coin: coin,
        publicKey: key.publicKey.toHex(),
        name: keyName,
        keyType: CustomKeyType.privateKey);
  }

  static ImportedKeyStorage wifToStorage(
      {required String wifKey, required CryptoCoins coin, String? keyName}) {
    if (!coin.conf.hasWif) {
      throw AppCryptoExceptionConst.invalidCoin;
    }
    try {
      final keyBytes =
          WifDecoder.decode(wifKey, netVer: coin.conf.wifNetVer!).item1;
      return _privateKeyToStorage(
          keyBytes: keyBytes, coin: coin, keyName: keyName);
    } catch (e) {
      throw AppCryptoExceptionConst.invalidWifKey;
    }
  }

  static Bip32Base privteKeyToBip32(
      {required String privateKey, required CryptoCoins coin}) {
    try {
      if (coin is! BipCoins) {
        throw AppCryptoExceptionConst.invalidCoin;
      }
      final privateKeyBytes = BytesUtils.fromHexString(privateKey);
      if (coin.proposal == CustomProposal.cip0019) {
        return CardanoByronLegacyBip32.fromPrivateKey(privateKeyBytes);
      }
      switch (coin.conf.type) {
        case EllipticCurveTypes.secp256k1:
          return Bip32Slip10Secp256k1.fromPrivateKey(privateKeyBytes);
        case EllipticCurveTypes.ed25519:
          return Bip32Slip10Ed25519.fromPrivateKey(privateKeyBytes);
        case EllipticCurveTypes.ed25519Kholaw:
          final bool icarus = coin.conf.addrParams["is_icarus"] ?? false;
          if (icarus) {
            return CardanoIcarusBip32.fromPrivateKey(privateKeyBytes);
          }
          return Bip32KholawEd25519.fromPrivateKey(privateKeyBytes);
        case EllipticCurveTypes.ed25519Blake2b:
          return Bip32Slip10Ed25519Blake2b.fromPrivateKey(privateKeyBytes);
        case EllipticCurveTypes.nist256p1:
          return Bip32Slip10Nist256p1.fromPrivateKey(privateKeyBytes);
        case EllipticCurveTypes.nist256p1Hybrid:
          return Bip32Slip10Nist256p1Hybrid.fromPrivateKey(privateKeyBytes);
        default:
          throw AppCryptoExceptionConst.invalidPrivateKey;
      }
    } catch (e) {
      throw AppCryptoExceptionConst.invalidPrivateKey;
    }
  }

  static Bip32Base extendedKeyToBip32Key(
      {required String extendedKey, required CryptoCoins coin}) {
    try {
      final conf = coin.conf;
      if (!coin.conf.hasExtendedKeys) {
        throw AppCryptoExceptionConst.invalidExtendedKey;
      }
      if (coin.proposal == CustomProposal.cip0019) {
        return CardanoByronLegacyBip32.fromExtendedKey(
            extendedKey, conf.keyNetVer);
      }

      switch (conf.type) {
        case EllipticCurveTypes.secp256k1:
          return Bip32Slip10Secp256k1.fromExtendedKey(
              extendedKey, conf.keyNetVer);
        case EllipticCurveTypes.ed25519:
          return Bip32Slip10Ed25519.fromExtendedKey(
              extendedKey, conf.keyNetVer);
        case EllipticCurveTypes.ed25519Kholaw:
          if (conf.addrParams["is_icarus"] == true) {
            return CardanoIcarusBip32.fromExtendedKey(
                extendedKey, conf.keyNetVer);
          }
          return Bip32KholawEd25519.fromExtendedKey(
              extendedKey, conf.keyNetVer);
        case EllipticCurveTypes.ed25519Blake2b:
          return Bip32Slip10Ed25519Blake2b.fromExtendedKey(
              extendedKey, conf.keyNetVer);
        case EllipticCurveTypes.nist256p1:
          return Bip32Slip10Nist256p1.fromExtendedKey(
              extendedKey, conf.keyNetVer);
        case EllipticCurveTypes.nist256p1Hybrid:
          return Bip32Slip10Nist256p1Hybrid.fromExtendedKey(
              extendedKey, conf.keyNetVer);
        default:
          throw AppCryptoExceptionConst.invalidExtendedKey;
      }
    } catch (e) {
      throw AppCryptoExceptionConst.invalidExtendedKey;
    }
  }

  static void validateMnemonic(String mnemonic) {
    if (!isValidMenemonic(mnemonic)) {
      throw AppCryptoExceptionConst.invalidMnemonic;
    }
  }

  static bool isValidMenemonic(String mnemonic) {
    final validator = Bip39MnemonicValidator();
    return validator.isValid(mnemonic);
  }

  static void validateMnemonicWords(List<String> mnemonic) {
    try {
      final isValid = Bip39MnemonicValidator();
      if (!isValid.validateWords(mnemonic.join(" "))) {
        throw AppCryptoExceptionConst.invalidBip39MnemonicWords;
      }
    } catch (e) {
      throw AppCryptoExceptionConst.invalidBip39MnemonicWords;
    }
  }

  static List<String> normalizeMnemonic(String mnemonic) {
    return Mnemonic.fromString(mnemonic).toList();
  }

  static Bip32Base seedToBipKey(
      {required List<int> seedBytes, required BipCoins coin}) {
    Bip32Base validate(Bip32Base bip32Obj) {
      final depth = bip32Obj.depth.depth;
      if (bip32Obj.isPublicOnly) {
        if (depth < Bip44Levels.account.value ||
            depth > Bip44Levels.addressIndex.value) {
          throw AppCryptoExceptionConst.invalidKeyDerivationPath;
        }
      } else {
        if (depth < 0 || depth > Bip44Levels.addressIndex.value) {
          throw AppCryptoExceptionConst.invalidKeyDerivationPath;
        }
      }

      return bip32Obj;
    }

    Bip32Base bip;
    final conf = coin.conf;
    Bip32KeyNetVersions? keyNetVar;
    bool isIcarus = false;
    keyNetVar = coin.conf.keyNetVer;
    isIcarus = coin.conf.addrParams["is_icarus"] ?? false;
    switch (conf.type) {
      case EllipticCurveTypes.secp256k1:
        bip = Bip32Slip10Secp256k1.fromSeed(seedBytes, keyNetVar);
        break;
      case EllipticCurveTypes.ed25519:
        bip = Bip32Slip10Ed25519.fromSeed(seedBytes, keyNetVar);
        break;
      case EllipticCurveTypes.ed25519Kholaw:
        if (coin.proposal == CustomProposal.cip0019) {
          bip = CardanoByronLegacyBip32.fromSeed(seedBytes, keyNetVar);
          break;
        }
        if (isIcarus) {
          bip = CardanoIcarusBip32.fromSeed(seedBytes, keyNetVar);
          break;
        }
        bip = Bip32KholawEd25519.fromSeed(seedBytes, keyNetVar);
        break;
      case EllipticCurveTypes.ed25519Blake2b:
        bip = Bip32Slip10Ed25519Blake2b.fromSeed(seedBytes, keyNetVar);
        break;
      case EllipticCurveTypes.nist256p1:
        bip = Bip32Slip10Nist256p1.fromSeed(seedBytes, keyNetVar);
        break;
      case EllipticCurveTypes.nist256p1Hybrid:
        bip = Bip32Slip10Nist256p1Hybrid.fromSeed(seedBytes, keyNetVar);
        break;
      default:
        throw AppCryptoExceptionConst.invalidCoin;
    }

    return validate(bip);
  }

  static IPrivateKey seedToSubstratePrivateKey(
      {required List<int> seedBytes, required CryptoCoins coin}) {
    if (coin.proposal != SubstratePropoosal.substrate) {
      throw AppCryptoExceptionConst.invalidCoin;
    }
    final substrate = Substrate.fromSeed(seedBytes, coin as SubstrateCoins);
    return substrate.priveKey.privKey;
  }

  static String _createCustomKeyChecksum(
      {required List<int> pubkeyBytes,
      List<int>? chainCode,
      required CryptoCoins coin}) {
    chainCode ??= List<int>.filled(32, 0);
    return BytesUtils.toHexString(MD5.hash(<int>[
      ...pubkeyBytes,
      ...chainCode,
      ...coin.proposal.specName.codeUnits,
      ...coin.coinName.codeUnits
    ]));
  }

  static String? validateHdPathKey(String path, {int? maxIndex}) {
    try {
      final parser = Bip32PathParser.parse(path);
      if (maxIndex != null && parser.length() != maxIndex) {
        return null;
      }
      return path;
    } catch (e) {
      return null;
    }
  }

  static String? toWif(
      {required List<int> privateKey, required CryptoCoins coin}) {
    if (coin is BipCoins) {
      final wif = coin.conf.wifNetVer;
      if (wif != null) {
        return WifEncoder.encode(privateKey, netVer: wif);
      }
    }
    return null;
  }

  static String generateRandomString(int length) {
    const String chars =
        'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    return List.generate(
            length, (index) => chars[QuickCrypto.prng.nextInt(chars.length)])
        .join('');
  }

  static String generateStringIndentifier(String str) {
    return BytesUtils.toHexString(MD4.hash(StringUtils.encode(str)));
  }

  static String generateCrc32Identifier(String str, int prefix) {
    final id = Crc32.quickIntDigest(StringUtils.encode(str));
    return "$id$prefix";
  }

  static String toPublicKeyHex(List<int> keyBytes, EllipticCurveTypes type) {
    List<int> bytes = toPublicBytes(keyBytes, type);
    return BytesUtils.toHexString(bytes, prefix: "0x");
  }

  static String normalizePublicKeyHex(
      String keyBytes, EllipticCurveTypes type) {
    final key = BytesUtils.fromHexString(keyBytes);
    return BytesUtils.toHexString(normalizePublicKeyBytes(key, type));
  }

  static List<int> normalizePublicKeyBytes(
      List<int> keyBytes, EllipticCurveTypes type) {
    // final key = StringUtils.normalizeHex(keyBytes);
    switch (type) {
      case EllipticCurveTypes.ed25519:
      case EllipticCurveTypes.ed25519Kholaw:
        if (keyBytes.length == Ed25519KeysConst.pubKeyByteLen) {
          return keyBytes;
        }
        if (keyBytes.length !=
            Ed25519KeysConst.pubKeyByteLen +
                Ed25519KeysConst.pubKeyPrefix.length) {
          throw AppCryptoExceptionConst.invalidPublicKey;
        }
        return keyBytes.sublist(Ed25519KeysConst.pubKeyPrefix.length);
      default:
        return keyBytes;
    }
  }

  static List<int> toPublicBytes(List<int> publicKey, EllipticCurveTypes type) {
    final key = IPublicKey.fromBytes(publicKey, type);
    List<int> bytes = key.compressed;
    switch (key.curve) {
      case EllipticCurveTypes.ed25519:
      case EllipticCurveTypes.ed25519Kholaw:
        if (bytes.length ==
            Ed25519KeysConst.pubKeyByteLen +
                Ed25519KeysConst.pubKeyPrefix.length) {
          bytes = bytes.sublist(1);
        }
        break;
      default:
    }
    return bytes;
  }

  static List<int> bip39MnemonicToBinary(Mnemonic mnemonic) {
    final decoder = Bip39MnemonicDecoder();
    final language = decoder.findLanguage(mnemonic);
    final decode =
        Bip39MnemonicDecoder().mnemonicToBinaryStr(mnemonic, language.item1);
    return BytesUtils.fromBinary(decode);
  }

  static List<int> bip39MnemonicToBytes(Mnemonic mnemonic) {
    if (mnemonic.wordsCount() > 127) {
      throw AppCryptoExceptionConst.invalidMnemonic;
    }
    final decoder = Bip39MnemonicDecoder();
    final language = decoder.findLanguage(mnemonic);
    final mnemonicBinStr =
        decoder.mnemonicToBinaryStr(mnemonic, language.item1);
    final mnemonicBitLen = mnemonicBinStr.length;
    final padBitLen = mnemonicBitLen % 8 == 0
        ? mnemonicBitLen
        : mnemonicBitLen + (8 - mnemonicBitLen % 8);
    final result =
        BytesUtils.fromBinary(mnemonicBinStr, zeroPadByteLen: padBitLen);
    return [mnemonic.wordsCount(), ...result];
  }

// Bytes → Mnemonic
  static Mnemonic bytesToBip39Mnemonic(
      {required List<int> bytes, required MnemonicLanguages language}) {
    if (bytes.isEmpty || bytes[0] > 127) {
      throw AppCryptoExceptionConst.invalidMnemonic;
    }
    int length = bytes[0];
    bytes = bytes.sublist(1);
    final toBinary = BytesUtils.toBinary(bytes,
        zeroPadBitLen: length * Bip39MnemonicConst.wordBitLen);
    bytes = bytes.sublist(1);
    final words = <String>[];
    for (var i = 0;
        i + Bip39MnemonicConst.wordBitLen <= toBinary.length;
        i += Bip39MnemonicConst.wordBitLen) {
      final wordBinStr =
          toBinary.substring(i, i + Bip39MnemonicConst.wordBitLen);
      final wordIdx = int.parse(wordBinStr, radix: 2);
      words.add(language.wordList[wordIdx]);
    }
    return Mnemonic.fromList(words);
  }

  static List<int>? tryDecodeWebAuthPublicKeyCredential(String publicKey) {
    final pubKeyBytes = BytesUtils.tryFromHexString(publicKey);
    if (pubKeyBytes == null ||
        pubKeyBytes.length < EcdsaKeysConst.pubKeyUncompressedByteLen) {
      return null;
    }
    final rawKey = pubKeyBytes
        .sublist(pubKeyBytes.length - EcdsaKeysConst.pubKeyUncompressedByteLen);
    if (IPublicKey.isValidBytes(rawKey, EllipticCurveTypes.nist256p1)) {
      return rawKey;
    }
    return null;
  }

  static bool validateWebAuthSecp256p1DerSignature(
      {required List<int> authenticatorData,
      required List<int> clientDataJSON,
      required List<int> signature,
      required List<int> pubKeyBytes}) {
    final digest = QuickCrypto.sha256Hash(
        [...authenticatorData, ...QuickCrypto.sha256Hash(clientDataJSON)]);
    final derSignature = Secp256k1EcdsaSignature.fromDer(signature);
    final pk = Nist256p1PublicKey.fromBytes(pubKeyBytes);
    return pk.publicKey.verifies(
        BigintUtils.fromBytes(digest), derSignature.toEcdsaSignature());
  }
}
