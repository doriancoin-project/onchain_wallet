import 'dart:ffi';
import 'dart:io';
import 'package:on_chain_wallet/app/core.dart';
import 'package:on_chain_wallet/crypto/crypto/cross/constants/constants.dart';

class AppCryptoNative {
  final DynamicLibrary library;
  AppCryptoNative({required this.library});
  static AppCryptoNative? findLiberary() {
    try {
      if (Platform.isMacOS) {
        return AppCryptoNative(
            library: DynamicLibrary.open(AppCryptoConst.cryptoLibNameMacos));
      } else if (Platform.isWindows) {
        return AppCryptoNative(
            library: DynamicLibrary.open(AppCryptoConst.cryptoLibNameWindows));
      } else if (Platform.isAndroid) {
        return AppCryptoNative(
            library: DynamicLibrary.open(AppCryptoConst.cryptoLibNameAndroid));
      } else if (Platform.isLinux) {
        return AppCryptoNative(
            library: DynamicLibrary.open(AppCryptoConst.cryptoLibNameAndroid));
      }
      return null;
    } catch (e, s) {
      appLogger.error(
          runtime: "AppCryptoNative",
          functionName: "findLiberary",
          msg: e,
          trace: s);
      return null;
    }
  }

  void close() {
    library.close();
  }
}
