import '../cross/cross.dart'
    if (dart.library.js_interop) '../cross/web/crypto.dart'
    if (dart.library.io) '../cross/io/crypto.dart';

abstract class AppCrypto {
  const AppCrypto();
  factory AppCrypto.instance() {
    return getAppCrypto();
  }

  void close();
}
