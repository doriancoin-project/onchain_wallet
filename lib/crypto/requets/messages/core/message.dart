import 'dart:async';
import 'package:blockchain_utils/blockchain_utils.dart';
import 'package:on_chain_wallet/app/core.dart';
import 'package:on_chain_wallet/crypto/constant/tags.dart';
import 'package:on_chain_wallet/crypto/requets/argruments/argruments.dart';
import 'package:on_chain_wallet/crypto/requets/messages/crypto/crypto.dart';
import 'package:on_chain_wallet/crypto/requets/messages/non_encrypted/requests.dart';
import 'package:on_chain_wallet/crypto/requets/messages/wallet/wallet.dart';

class WorkerMessageConst {
  static const List<int> workerMessagResponse = [2, 24, 4, 26];
  static const List<int> encryptedMessage = [0, 1, 2, 3];
  static const List<int> workerMessageRequest = [104, 0, 0, 0];
  static const List<int> noneEncryptedMessage = [0, 3, 2, 1];
  static const List<int> cborMessage = [0, 3, 2, 2];
}

enum CryptoRequestMethod {
  encryptChacha(CryptoKeyConst.encryptChacha),
  decryptChacha(CryptoKeyConst.decryptChacha),
  generateMnemonic(CryptoKeyConst.generateToneMenemonic),
  tonMnemonicToPrivateKey(CryptoKeyConst.tonMnemonicToPrivateKey),
  tonMnemonicValidate(CryptoKeyConst.tonMnemonicValidate),
  generateMasterKey(CryptoKeyConst.generateMasterKey),
  readMasterKey(CryptoKeyConst.readEncryptedMasterKey),
  createMasterKey(CryptoKeyConst.createMasterKey),
  createWallet(CryptoKeyConst.createWallet),
  decodeBackup(CryptoKeyConst.decodeBackup),
  generateBip39Mnemonic(CryptoKeyConst.generateBip39Mnemonic),
  walletKey(CryptoKeyConst.walletKey),
  randomGenerator(CryptoKeyConst.randomGenerator),
  jwt(CryptoKeyConst.jwt),
  hashing(CryptoKeyConst.hashing),
  symkey(CryptoKeyConst.generateSymKey),
  x25519(CryptoKeyConst.x25519);

  final List<int> _tag;
  const CryptoRequestMethod(this._tag);
  List<int> get tag => [...CryptoArgsType.crypto.tag, ..._tag];
  static CryptoRequestMethod fromTag(List<int>? tag) {
    return values.firstWhere(
        (e) => BytesUtils.bytesEqual(
            e._tag, tag?.sublist(CryptoArgsType.tagLength)),
        orElse: () =>
            throw AppSerializationException(objectName: "CryptoRequestMethod"));
  }
}

enum NoneEncryptedCryptoRequestMethod {
  hexToBytes(CryptoKeyConst.hexToBytes),
  hashing(CryptoKeyConst.hashing);

  final List<int> _tag;
  List<int> get tag => [...CryptoArgsType.nonEncrypted.tag, ..._tag];
  const NoneEncryptedCryptoRequestMethod(this._tag);
  static NoneEncryptedCryptoRequestMethod fromTag(List<int>? tag) {
    return values.firstWhere(
        (e) => BytesUtils.bytesEqual(
            e._tag, tag?.sublist(CryptoArgsType.tagLength)),
        orElse: () => throw AppSerializationException(
            objectName: "NoneEncryptedCryptoRequestMethod"));
  }
}

enum StreamIsolateMethod {
  placeholder([]); // placeholder - no stream methods currently used

  final List<int> _tag;
  List<int> get tag => [...StreamCryptoArgsType.streamRequest.tag, ..._tag];
  const StreamIsolateMethod(this._tag);
  static StreamIsolateMethod fromTag(List<int>? tag) {
    return values.firstWhere(
        (e) => BytesUtils.bytesEqual(
            e._tag, tag?.sublist(CryptoArgsType.tagLength)),
        orElse: () =>
            throw AppSerializationException(objectName: "StreamIsolateMethod"));
  }
}

enum WalletRequestMethod {
  signMessage(CryptoKeyConst.ethereumPersonalSign),
  bitcoinSignMessage(CryptoKeyConst.bitcoinPersonalSign),
  ethereumTypedDataSign(CryptoKeyConst.ethereumTypedDataSign),
  deriveAddress(CryptoKeyConst.deriveAddress),
  readPublicKeys(CryptoKeyConst.readPublicKeys),
  readPrivateKeys(CryptoKeyConst.readPrivateKeys),
  readImportKey(CryptoKeyConst.readImportKey),
  readMnemonic(CryptoKeyConst.readMnemonic),
  updateWalletKeys(CryptoKeyConst.updateWalletKeys),
  removeWalletKeys(CryptoKeyConst.removeWalletKeys),
  walletBackup(CryptoKeyConst.walletBackup),
  encodeBackup(CryptoKeyConst.encodeBackup),
  sign(CryptoKeyConst.sign),
  importSubWallet(CryptoKeyConst.importSubWallet),
  removeSubWallet(CryptoKeyConst.removeSubWallet),
  changeWalletPassword(CryptoKeyConst.changeWalletPassword);

  final List<int> tag;
  const WalletRequestMethod(this.tag);
  static WalletRequestMethod fromTag(List<int>? tag) {
    return values.firstWhere((e) => BytesUtils.bytesEqual(e.tag, tag),
        orElse: () =>
            throw AppSerializationException(objectName: "StreamIsolateMethod"));
  }
}

abstract class CryptoRequest<T, A extends CborMessageResponseArgs>
    extends CryptoArgsCompleter<T, A> {
  const CryptoRequest();
  abstract final CryptoRequestMethod method;

  @override
  CryptoArgsType get type => CryptoArgsType.crypto;

  factory CryptoRequest.deserialize({List<int>? bytes, CborObject? object}) {
    final CborTagValue decode =
        CborSerializable.decode(cborBytes: bytes, object: object);

    final request = CryptoRequestMethod.fromTag(decode.tags);
    final CryptoRequest args;
    switch (request) {
      case CryptoRequestMethod.encryptChacha:
        args = CryptoRequestEncryptChacha.deserialize(object: decode);
        break;
      case CryptoRequestMethod.decryptChacha:
        args = CryptoRequestDecryptChacha.deserialize(object: decode);
        break;
      case CryptoRequestMethod.generateMnemonic:
      case CryptoRequestMethod.tonMnemonicToPrivateKey:
      case CryptoRequestMethod.tonMnemonicValidate:
        throw AppCryptoExceptionConst.internalError("UnsupportedCryptoRequest");
      case CryptoRequestMethod.generateMasterKey:
        args = CryptoRequestGenerateMasterKey.deserialize(object: decode);
        break;
      case CryptoRequestMethod.readMasterKey:
        args = CryptoRequestReadMasterKey.deserialize(object: decode);
        break;
      case CryptoRequestMethod.createMasterKey:
        args = CryptoRequestRestoreBackupMasterKey.deserialize(object: decode);
        break;
      case CryptoRequestMethod.createWallet:
        args = CryptoRequestCreateHDWallet.deserialize(object: decode);
        break;
      case CryptoRequestMethod.decodeBackup:
        args = CryptoRequestDecodeBackup.deserialize(object: decode);
        break;
      case CryptoRequestMethod.generateBip39Mnemonic:
        args = CryptoRequestGenerateBip39Mnemonic.deserialize(object: decode);
        break;
      case CryptoRequestMethod.walletKey:
        args = CryptoRequestWalletKey.deserialize(object: decode);
        break;
      case CryptoRequestMethod.randomGenerator:
        args = CryptoRequestRandomGenerator.deserialize(object: decode);
        break;
      case CryptoRequestMethod.hashing:
        args = CryptoRequestHashing.deserialize(object: decode);
        break;
      case CryptoRequestMethod.symkey:
        args = CryptoRequestGenerateWalletConnectSymKeyInfo.deserialize(
            object: decode);
        break;
      case CryptoRequestMethod.x25519:
        args = CryptoRequestGenerateX25519Key.deserialize(object: decode);
        break;
      case CryptoRequestMethod.jwt:
        args = CryptoRequestGenerateJwt.deserialize(object: decode);
        break;
    }
    if (args is! CryptoRequest<T, A>) {
      throw AppCryptoExceptionConst.internalError("CryptoRequest");
    }
    return args;
  }
}

abstract class WalletRequest<T, A extends CborMessageResponseArgs>
    extends WalletArgsCompleter<T, A> {
  abstract final WalletRequestMethod method;
  const WalletRequest();

  factory WalletRequest.deserialize({List<int>? bytes, CborObject? object}) {
    final CborTagValue decode =
        CborSerializable.decode(cborBytes: bytes, object: object);

    final request = WalletRequestMethod.fromTag(decode.tags);
    final WalletRequest args;
    switch (request) {
      case WalletRequestMethod.signMessage:
        args = WalletRequestSignMessage.deserialize(object: decode);
        break;
      case WalletRequestMethod.bitcoinSignMessage:
        args = WalletRequestBitcoinSignMessage.deserialize(object: decode);
        break;
      case WalletRequestMethod.ethereumTypedDataSign:
        throw AppCryptoExceptionConst.internalError("UnsupportedWalletRequest");
      case WalletRequestMethod.deriveAddress:
        args = WalletRequestDeriveAddress.deserialize(object: decode);
        break;
      case WalletRequestMethod.readPublicKeys:
        args = WalletRequestReadPublicKeys.deserialize(object: decode);
        break;
      case WalletRequestMethod.readPrivateKeys:
        args = WalletRequestReadPrivateKeys.deserialize(object: decode);
        break;
      case WalletRequestMethod.readMnemonic:
        args = WalletRequestReadMnemonic.deserialize(object: decode);
        break;
      case WalletRequestMethod.updateWalletKeys:
        args = WalletRequestImportNewKey.deserialize(object: decode);
        break;
      case WalletRequestMethod.removeWalletKeys:
        args = WalletRequestRemoveKey.deserialize(object: decode);
        break;
      case WalletRequestMethod.sign:
        args = WalletRequestSign.deserialize(object: decode);
        break;
      case WalletRequestMethod.readImportKey:
        args = WalletRequestReadImportedKey.deserialize(object: decode);
        break;
      case WalletRequestMethod.walletBackup:
        args = WalletRequestBackupWallet.deserialize(object: decode);
        break;
      case WalletRequestMethod.importSubWallet:
        args = WalletRequestImportSubWallet.deserialize(object: decode);
        break;
      case WalletRequestMethod.removeSubWallet:
        args = WalletRequestRemoveSubWallet.deserialize(object: decode);
        break;
      case WalletRequestMethod.encodeBackup:
        args = WalletRequestBackupKey.deserialize(object: decode);
        break;
      case WalletRequestMethod.changeWalletPassword:
        args = WalletRequestChangePassword.deserialize(object: decode);
        break;
    }
    if (args is! WalletRequest<T, A>) {
      throw AppCryptoExceptionConst.internalError("WalletRequest");
    }
    return args;
  }
}

abstract class NoneEncryptedCryptoRequest<T, A extends CborMessageResponseArgs>
    extends NoneEncryptedArgsCompleter<T, A> {
  abstract final NoneEncryptedCryptoRequestMethod method;
  const NoneEncryptedCryptoRequest();
  factory NoneEncryptedCryptoRequest.deserialize(
      {List<int>? bytes, CborObject? object}) {
    final CborTagValue decode =
        CborSerializable.decode(cborBytes: bytes, object: object);
    final request = NoneEncryptedCryptoRequestMethod.fromTag(decode.tags);
    final NoneEncryptedCryptoRequest args;
    switch (request) {
      case NoneEncryptedCryptoRequestMethod.hexToBytes:
        args = NoneEncryptedRequestHexToBytes.deserialize(object: decode);
        break;
      case NoneEncryptedCryptoRequestMethod.hashing:
        args = NoneEncryptedRequestHashing.deserialize(object: decode);
        break;
    }
    if (args is! NoneEncryptedCryptoRequest<T, A>) {
      throw AppCryptoExceptionConst.internalError("NoneEncryptedCryptoRequest");
    }
    return args;
  }

  @override
  CryptoArgsType get type => CryptoArgsType.nonEncrypted;
}

abstract class IsolateStreamRequest<T, S>
    extends StreamArgsCompleter<T, MessageArgsStreamResponse, S> {
  StreamController<S>? _streamController = StreamController();
  StreamController<S>? get streamController => _streamController;
  bool _closed = false;
  bool get closed => _closed;
  abstract final StreamIsolateMethod method;

  @override
  StreamCryptoArgsType get type => StreamCryptoArgsType.streamRequest;

  IsolateStreamRequest();
  factory IsolateStreamRequest.deserialize(
      {List<int>? bytes, CborObject? object}) {
    final CborTagValue decode =
        CborSerializable.decode(cborBytes: bytes, object: object);
    final request = StreamIsolateMethod.fromTag(decode.tags);
    switch (request) {
      default:
        throw AppCryptoExceptionConst.internalError("IsolateStreamRequest");
    }
  }

  void handleIsolateData(
      {required S param,
      required EventSink<MessageArgsStreamResponse> sink,
      required String streamId,
      List<int>? encryptedPart});
  void handleData(
      {required S param,
      required EventSink<T> sink,
      required String streamId,
      List<int>? encryptedPart});

  @override
  Stream<MessageArgsStreamResponse> getIsolateResult(
      {required String streamId, List<int>? encryptedPart}) {
    if (_streamController == null) {
      throw AppCryptoException("stream_closed_desc");
    }
    return _streamController!.stream.transform(
        StreamTransformer<S, MessageArgsStreamResponse>.fromHandlers(
            handleData: (data, sink) => handleIsolateData(
                param: data,
                sink: sink,
                streamId: streamId,
                encryptedPart: encryptedPart)));
  }

  @override
  Stream<T> result({List<int>? encryptedPart}) {
    if (_streamController == null) {
      throw AppCryptoException("stream_closed_desc");
    }
    return _streamController!.stream.transform(
        StreamTransformer<S, T>.fromHandlers(
            handleData: (data, sink) => handleData(
                param: data,
                sink: sink,
                streamId: 'main',
                encryptedPart: encryptedPart)));
  }

  void close() {
    if (_closed) return;
    _closed = true;
    _streamController?.close();
    _streamController = null;
  }

  @override
  void add(MessageArgsStream args) {
    switch (args.method) {
      case MessageArgsStreamMethod.close:
      case MessageArgsStreamMethod.done:
        close();
        break;
      default:
    }
  }
}
