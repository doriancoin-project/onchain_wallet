import 'package:blockchain_utils/blockchain_utils.dart';
import 'package:flutter/material.dart';
import 'package:on_chain_wallet/app/core.dart';
import 'package:on_chain_wallet/app/live_listener/progress_bar.dart';
import 'package:on_chain_wallet/crypto/keys/access/crypto_keys/crypto_keys.dart';
import 'package:on_chain_wallet/crypto/requets/messages/crypto/requests/generate_mnemonic.dart';
import 'package:on_chain_wallet/future/state_managment/state_managment.dart';
import 'package:on_chain_wallet/future/wallet/controller/controller.dart';
import 'package:on_chain_wallet/future/wallet/setup/types/types.dart';
import 'package:on_chain_wallet/future/widgets/widgets/progress_bar/widgets/stream_page_progress.dart';
import 'package:on_chain_wallet/future/widgets/widgets/text_field.dart';
import 'package:on_chain_wallet/future/widgets/widgets/text_or_file_picker.dart';
import 'package:on_chain_wallet/wallet/models/wallet/models/backup.dart';

class MnemonicStateController with DisposableMixin, StreamStateController {
  final WalletProvider walletProvider;
  SetupMnemonicPage page = SetupMnemonicPage.generate;
  MnemonicStateController(
      {required this.walletProvider, this.allowMnemonicType});
  GeneratedMnemonic? _mnemonic;
  GeneratedMnemonic? get mnemonic => _mnemonic;
  late MnemonicType type = allowMnemonicType ?? MnemonicType.bip39;
  final MnemonicType? allowMnemonicType;
  bool isEnabled(MnemonicType type) {
    if (allowMnemonicType == null) return true;
    return allowMnemonicType == type;
  }

  final FocusNode nextFocus = FocusNode();
  final StreamPageProgressController pageController =
      StreamPageProgressController();
  final GlobalKey<FormState> formKey =
      GlobalKey(debugLabel: "MnemonicStateController_formKey");

  bool _usePassphrase = false;
  bool get usePassphrase => _usePassphrase;
  MnemonicWordCountView? _wordCount;
  MnemonicWordCountView get wordCounts => _wordCount!;
  List<MnemonicWordCountView> _wordsCounts = [];
  List<MnemonicWordCountView> get wordsCounts => _wordsCounts;
  List<MenemonicLanguageView> _languages = [];
  List<MenemonicLanguageView> get languages => _languages;
  MenemonicLanguageView? _language;
  MenemonicLanguageView get language => _language!;

  String _passphrase = "";
  String _confirmPassphrase = "";
  String get passhrase => _passphrase;
  String get confirmPassphrase => _confirmPassphrase;

  List<MenemonicLanguageView> _buildLanguages() {
    switch (type) {
      case MnemonicType.bip39:
        return Bip39Languages.values
            .map((e) => MenemonicLanguageView(
                language: e, name: e.name.camelCase, identifier: e.name))
            .toList();
      case MnemonicType.monero:
        return [];
      case MnemonicType.ton:
        return [];
    }
  }

  List<MnemonicWordCountView> _buildWordNumbers() {
    switch (type) {
      case MnemonicType.bip39:
        return Bip39WordsNum.values
            .map((e) => MnemonicWordCountView(
                number: e.value,
                name: "n_word".tr.replaceOne(e.value.toString())))
            .toList();
      case MnemonicType.monero:
        return [];
      case MnemonicType.ton:
        return [];
    }
  }

  void _buildState() {
    _languages = _buildLanguages();
    _language = _languages
        .firstWhere((e) => e.identifier == Bip39Languages.english.name);
    _wordsCounts = _buildWordNumbers();
    _wordCount = wordsCounts.first;
  }

  void onStateUpdated() {
    notify();
    // MnemonicLanguages languages =
  }

  void onChangeMnemonicType(final MnemonicType? type) {
    if (type == null) return;
    this.type = type;
    _buildState();
    onStateUpdated();
  }

  void onChangeLanguage(final MenemonicLanguageView? language) {
    if (language == null) return;
    _language = language;
    onStateUpdated();
  }

  void onChangeWordsNumber(final MnemonicWordCountView? wordCount) {
    if (wordCount == null) return;
    _wordCount = wordCount;
    onStateUpdated();
  }

  void onChangeUsePassphrase(bool? v) {
    _usePassphrase = v ?? usePassphrase;
    _passphrase = "";
    onStateUpdated();
  }

  void onChangePassphrase(String v) {
    _passphrase = v;
  }

  void onChangeConfrimPassphrase(String v) {
    _confirmPassphrase = v;
  }

  String? onValidatePassphrase(String? v) {
    // if (!usePassphrase) return null;
    if (v?.isEmpty ?? true) {
      return "password_should_not_be_empty".tr;
    }
    return null;
  }

  String? onValidateConfirmPassphrase(String? v) {
    if (_passphrase == v) return null;
    return "p_does_not_match".tr;
  }

  Future<GeneratedMnemonic> _generateMnemonic({
    required String? passphrase,
    required String? languageIdentifier,
    required int wordCounts,
    required MnemonicType type,
  }) async {
    final language = switch (type) {
      MnemonicType.bip39 =>
        Bip39Languages.values.firstWhere((e) => e.name == languageIdentifier),
      _ => null
    };
    Mnemonic mnemonic;
    switch (type) {
      case MnemonicType.bip39:
        final wNum = Bip39WordsNum.fromValue(wordCounts);
        mnemonic = await walletProvider.wallet.crypto.cryptoIsolateRequest(
            CryptoRequestGenerateBip39Mnemonic(
                language: language as Bip39Languages, wordNums: wNum!));
        break;
      case MnemonicType.ton:
        throw WalletExceptionConst.unsuportedFeature;
      case MnemonicType.monero:
        throw WalletExceptionConst.unsuportedFeature;
    }
    return GeneratedMnemonic(
        mnemonic: mnemonic,
        passphrase: passphrase,
        language: language,
        languageIdentifer: languageIdentifier,
        type: type);
  }

  Future<void> generateMnemonic() async {
    if (page == SetupMnemonicPage.generate && !formKey.ready()) return;
    pageController.progressText("generating_mnemonic_please_wait".tr);
    page = SetupMnemonicPage.generate;
    final result = await MethodUtils.call(() async {
      return _generateMnemonic(
          passphrase: mnemonic?.passphrase ??
              (usePassphrase && type.supportPassPhrase ? _passphrase : null),
          languageIdentifier:
              mnemonic?.languageIdentifer ?? language.identifier,
          wordCounts: mnemonic?.mnemonicWords.length ?? wordCounts.number,
          type: type);
    }, delay: type == MnemonicType.bip39 ? APPConst.oneSecoundDuration : null);
    if (result.hasResult) {
      _mnemonic = result.result;
      page = SetupMnemonicPage.review;
      pageController.success();
    } else {
      pageController.errorText(result.localizationError);
    }
    notify();
  }

  void goToVerifyPage() {
    if (_mnemonic == null) return;
    page = SetupMnemonicPage.verify;
    onStateUpdated();
  }

  void onValidateMnemonic(List<String> mnemonic, ONMNEMONICREADY onReady) {
    final generatedMnemonic = this.mnemonic;
    if (generatedMnemonic == null) return;
    if (CompareUtils.iterableIsEqual(
        mnemonic, generatedMnemonic.mnemonicWords)) {
      onReady(generatedMnemonic);
    }
  }

  void init() {
    _buildState();
  }

  @override
  void dispose() {
    super.dispose();
    pageController.dispose();
    nextFocus.dispose();
    _passphrase = '';
    _mnemonic = null;
    _wordsCounts = [];
    _languages = [];
  }
}

class ExistsMnemonicStateController
    with DisposableMixin, StreamStateController {
  final WalletProvider walletProvider;
  ExistsMnemonicStateController(
      {required this.walletProvider, this.allowMnemonicType});

  late MnemonicType type = allowMnemonicType ?? MnemonicType.bip39;
  final MnemonicType? allowMnemonicType;
  bool isEnabled(MnemonicType type) {
    if (allowMnemonicType == null) return true;
    return allowMnemonicType == type;
  }

  final FocusNode nextFocus = FocusNode();
  final StreamPageProgressController pageController =
      StreamPageProgressController();
  final GlobalKey<FormState> formKey =
      GlobalKey(debugLabel: "MnemonicStateController_formKey");
  final GlobalKey<AppTextFieldState> mnemonicTextFieldKey = GlobalKey();
  bool _usePassphrase = false;
  bool get usePassphrase => _usePassphrase;

  String _passphrase = "";
  String _confirmPassphrase = "";
  String get passhrase => _passphrase;
  String get confirmPassphrase => _confirmPassphrase;

  String mnemonic = "";

  void onChangeMnemonicType(final MnemonicType? type) {
    if (type == null) return;
    this.type = type;
    onStateUpdated();
  }

  void onStateUpdated() {
    notify();
    // MnemonicLanguages languages =
  }

  void onChangeUsePassphrase(bool? v) {
    if (!type.supportPassPhrase) return;
    _usePassphrase = v ?? usePassphrase;
    _passphrase = "";
    _confirmPassphrase = "";
    onStateUpdated();
  }

  void onChangePassphrase(String v) {
    _passphrase = v;
  }

  void onChangeConfrimPassphrase(String v) {
    _confirmPassphrase = v;
  }

  void onChangeMnemonic(String v) {
    mnemonic = v;
  }

  void onPasteMnemonic(String? v) {
    if (v == null) return;
    mnemonicTextFieldKey.currentState?.updateText(v);
  }

  String? onValidatePassphrase(String? v) {
    // if (!usePassphrase) return null;
    if (v?.isEmpty ?? true) {
      return "password_should_not_be_empty".tr;
    }
    return null;
  }

  String? onValidateConfirmPassphrase(String? v) {
    if (_passphrase == v) return null;
    return "p_does_not_match".tr;
  }

  String? onValidateMnemonicLength(int length) {
    return switch (type) {
      MnemonicType.bip39 => () {
          if (Bip39WordsNum.values.any((e) => e.value == length)) return null;
          return "invalid_bip39_mnemonic_words_length".tr;
        }(),
      MnemonicType.monero => "unsuported_feature".tr,
      MnemonicType.ton => "unsuported_feature".tr,
    };
  }

  MenemonicLanguageView? findMnemonicLanguage(Mnemonic mnemonic) {
    return switch (type) {
      MnemonicType.bip39 => () {
          try {
            final language = Bip39WordsListFinder().findLanguage(mnemonic).item2
                as Bip39Languages;
            return MenemonicLanguageView(
                language: language,
                name: language.name.camelCase,
                identifier: language.name);
          } catch (_) {
            return null;
          }
        }(),
      MnemonicType.monero => null,
      MnemonicType.ton => null,
    };
  }

  String? onValidateMnemonic(String? v) {
    final Mnemonic mnemonic = Mnemonic.fromString(v ?? '');
    final lengthError = onValidateMnemonicLength(mnemonic.wordsCount());
    if (lengthError != null) return lengthError;
    final language = findMnemonicLanguage(mnemonic);
    if (language == null) return "invalid_mnemonic_desc".tr;
    return null;
  }

  Future<void> validate(ONMNEMONICREADY onReady) async {
    if (!formKey.ready()) return;

    final Mnemonic mnemonic = Mnemonic.fromString(this.mnemonic);
    final lengthValidator = onValidateMnemonicLength(mnemonic.wordsCount());
    final language = findMnemonicLanguage(mnemonic);
    if (lengthValidator != null || language == null) return;
    pageController.progressText("verifying_mnemonic_please_wait".tr);
    final passphrase =
        (usePassphrase && type.supportPassPhrase ? _passphrase : null);
    final result = await MethodUtils.call(() async {
      switch (type) {
        case MnemonicType.bip39:
          CryptoKeyUtils.validateMnemonic(mnemonic.toStr());
          return GeneratedMnemonic(
              mnemonic: mnemonic,
              passphrase: passphrase,
              language: language.language,
              languageIdentifer: language.identifier,
              type: type);

        case MnemonicType.ton:
          throw WalletExceptionConst.unsuportedFeature;

        case MnemonicType.monero:
          throw WalletExceptionConst.unsuportedFeature;
      }
    }, delay: APPConst.oneSecoundDuration);
    if (result.hasResult) {
      pageController.backToIdle();
      onReady(result.result);
    } else {
      pageController.errorText(result.localizationError);
    }
    onStateUpdated();
  }

  @override
  void dispose() {
    super.dispose();
    pageController.dispose();
    nextFocus.dispose();
    mnemonic = '';
    _passphrase = '';
    _confirmPassphrase = '';
  }
}

class WalletBackupStateController with DisposableMixin, StreamStateController {
  final WalletProvider walletProvider;
  final String password;
  WalletBackupStateController(
      {required this.walletProvider, required this.password});
  final FocusNode nextFocus = FocusNode();
  final StreamPageProgressController pageController =
      StreamPageProgressController();
  final GlobalKey<FormState> formKey =
      GlobalKey(debugLabel: "MnemonicStateController_formKey");
  final GlobalKey<BackupDataPickerViewState> backupKey =
      GlobalKey(debugLabel: "MnemonicStateController_backupKey");
  WalletBackupPage page = WalletBackupPage.backup;
  WalletRestoreV2? backupData;
  bool _usePassphrase = false;
  bool get usePassphrase => _usePassphrase;

  String _passphrase = "";
  String _confirmPassphrase = "";
  String get passhrase => _passphrase;
  String get confirmPassphrase => _confirmPassphrase;
  String _backupPassword = "";
  String get backupPassword => _backupPassword;
  bool verifyBackupContent = false;
  void onStateUpdated() {
    notify();
  }

  void onChangeVerifyBackup(bool? _) {
    verifyBackupContent = !verifyBackupContent;
    onStateUpdated();
  }

  void onChangeUsePassphrase(bool? v) {
    _usePassphrase = v ?? usePassphrase;
    _passphrase = "";
    onStateUpdated();
  }

  void onChangeBackupPassword(String v) {
    _backupPassword = v;
  }

  String? onValidateBackupPassword(String? v) {
    if (v?.isEmpty ?? true) {
      return "backup_password_validator".tr;
    }
    return null;
  }

  void onChangePassphrase(String v) {
    _passphrase = v;
  }

  void onChangeConfrimPassphrase(String v) {
    _confirmPassphrase = v;
  }

  String? onValidatePassphrase(String? v) {
    if (v?.isEmpty ?? true) {
      return "password_should_not_be_empty".tr;
    }
    return null;
  }

  String? onValidateConfirmPassphrase(String? v) {
    if (_passphrase == v) return null;
    return "p_does_not_match".tr;
  }

  Future<void> validateBackup() async {
    if (!formKey.ready()) return;
    final backup = backupKey.currentState?.getData();
    if (backup == null) return;
    pageController.progressText("validate_backup_content".tr);
    final result = await MethodUtils.call(() async {
      WalletBackup walletBackup;
      try {
        final b = WalletBackupCore.deserialize(bytes: backup);
        if (b.type != WalletBackupTypes.walletV3) {
          throw WalletExceptionConst.invalidBackupData;
        }
        walletBackup = b as WalletBackup;
      } catch (e) {
        throw WalletExceptionConst.invalidBackupData;
      }

      final decodeBytes = await walletProvider.wallet.restoreKeysBackup(
        backup: walletBackup.key,
        password: backupPassword,
        encoding: walletBackup.type.encoding,
      );
      return walletBackup.decrypt(decodeBytes.result);
    });
    if (result.hasError) {
      pageController.errorText(result.localizationError,
          backToIdle: false, showBackButton: true);
      return;
    }

    final progressBar = LivePercentProgressBar();
    pageController.progressText("verifying_backup_please_wait".tr,
        progressBar: progressBar);
    final backupData = await MethodUtils.call(() async {
      final String? passPhrase = usePassphrase ? _passphrase : null;
      return await walletProvider.wallet.restoreWalletBackupV3(
          backup: result.result,
          passhphrase: passPhrase,
          password: password,
          progress: progressBar,
          verify: verifyBackupContent);
    });
    if (backupData.hasError) {
      pageController.errorText(backupData.localizationError,
          backToIdle: false, showBackButton: true);
      return;
    }
    this.backupData = backupData.result;
    page = WalletBackupPage.review;
    pageController.backToIdle();
    onStateUpdated();
    progressBar.dispose();
  }

  @override
  void dispose() {
    super.dispose();
    pageController.dispose();
    nextFocus.dispose();
    _passphrase = '';
    _backupPassword = '';
    backupData = null;
  }
}
