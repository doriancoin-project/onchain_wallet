import 'package:on_chain_wallet/crypto/crypto/core/app_crypto.dart';
import 'package:on_chain_wallet/crypto/crypto/cross/io/native/native_crypto.dart';

AppCrypto getAppCrypto() => AppCryptoIo._();

class AppCryptoIo extends AppCrypto {
  AppCryptoIo._();

  AppCryptoNative? _lib = AppCryptoNative.findLiberary();

  @override
  void close() {
    final lib = _lib;
    _lib = null;
    lib?.close();
  }
}
