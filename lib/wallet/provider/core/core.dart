part of 'package:on_chain_wallet/wallet/provider/wallet_provider.dart';

abstract class WalletStateController {
  List<String> coinIds();
  Future<bool> onWeb3Request(Web3Request request);
}

abstract class _WalletCore extends WalletStateController
    with CryptoWokerImpl, WalletsStoragesManger {}

abstract class WalletCore extends _WalletCore with WalletsManager {
  int get storageVersion;

  bool get useMemoryStorage => false;
  bool get isJsWallet => false;

  Chain get currentChain => _controller._appChains.chain;
  WalletNetwork get network => _controller.network;
  MainWallet get wallet => _controller._wallet;
  List<MainWallet> get wallets => _wallets.wallets.values.toList()
    ..sort((a, b) => b.created.compareTo(a.created));
  Web3WalletConnectHandler get walletConnect =>
      _controller.walletConnectHandler;

  bool get hasWalletKey => _controller.hasWalletKey;

  int? get reminingWalletTime => _timeout.remining;

  @override
  List<String> coinIds() =>
      homePageStatus.isOpen ? _controller._appChains.coinIds() : [];

  Future<MethodResult<void>> setup(
      {required MainWallet hdWallet,
      required String password,
      required WalletUpdateInfosData walletInfos}) async {
    final result = await _callSynchronized(() async {
      return await _setup(
          hdWallet: hdWallet, password: password, walletInfos: walletInfos);
    }, action: () => WalletActionEventType.setup);
    return result;
  }

  Future<MethodResult<void>> setupBackup(
      {required WalletRestoreV2 backup,
      required String password,
      required WalletUpdateInfosData walletInfos}) async {
    return await _callSynchronized(() async {
      await _setup(
          hdWallet: backup.wallet,
          password: password,
          walletInfos: walletInfos,
          backup: backup);
    }, action: () => WalletActionEventType.setup);
  }

  Future<MethodResult<void>> setupSubWallet(
      {required WalletImportSubWalletData subWalletData}) async {
    final result = await _callSynchronized(() async {
      return await _controller._setupSubWallet(subWalletData);
    }, action: () => WalletActionEventType.importSubWallet);
    return result;
  }

  Future<MethodResult<Web3MessageCore>> web3Request(
      Web3RequestApplicationInformation request) async {
    final result = await _callSynchronized(
      () async {
        return await _controller._web3Request(request);
      },
      lockId: LockId.two,
      action: () => WalletActionEventType.web3Request,
    );
    return result;
  }

  Future<MethodResult<List<Web3InternalChain>>> getWeb3InternalChains(
      Web3ApplicationAuthentication authenticated,
      {List<NetworkType>? networks}) async {
    final result = await _callSynchronized(() async {
      return await _controller._getWeb3InternalChains(authenticated,
          networks: networks);
    }, lockId: LockId.three, action: () => WalletActionEventType.web3Auth);
    return result;
  }

  Future<MethodResult<List<Web3AccountAcitvity>>> getWeb3ApplicationActivities(
      Web3ApplicationAuthentication permission) async {
    final result = await _callSynchronized(() async {
      return await _controller._getWeb3ApplicationActivities(permission);
    }, lockId: LockId.three, action: () => WalletActionEventType.web3Auth);
    return result;
  }

  Future<MethodResult<void>> removeWeb3ApplicationActivities(
      Web3ApplicationAuthentication permission) async {
    return await _callSynchronized(() async {
      return await _controller._removeWeb3ApplicationActivities(permission);
    }, lockId: LockId.three, action: () => WalletActionEventType.web3Auth);
  }

  Future<MethodResult<List<Web3DappInfo>>> getAllWeb3Applications() async {
    return await _callSynchronized(() async {
      return await _controller._getAllWeb3Applications();
    }, lockId: LockId.two, action: () => WalletActionEventType.web3Auth);
  }

  Future<RESPONSE> localWeb3Request<RESPONSE>(
      WEB3REQUESTPARAMSRESPONSE<RESPONSE> params) async {
    final result = await _callSynchronized(() async {
      return await _controller._localWeb3Request(params);
    }, lockId: LockId.two, action: () => WalletActionEventType.web3Request);
    return result.result;
  }

  Future<MethodResult<Web3DappInfo>> getWeb3Dapp(
      Web3ClientInfo clientInfo) async {
    final result = await _callSynchronized(() async {
      return await _controller._getWeb3Dapp(clientInfo);
    }, lockId: LockId.two, action: () => WalletActionEventType.web3Auth);
    return result;
  }

  Future<MethodResult<Web3ApplicationAuthentication>> getDappApplication(
      Web3ClientInfo clientInfo) async {
    final result = await _callSynchronized(() async {
      return await _controller._getDappApplication(clientInfo);
    }, lockId: LockId.two, action: () => WalletActionEventType.web3Auth);
    return result;
  }

  Future<MethodResult<T>> walletRequest<T, A extends CborMessageResponseArgs>(
      WalletArgsCompleter<T, A> message) async {
    final result = await _callSynchronized(() async {
      return await _controller._walletRequest(message: message);
    }, action: () => WalletActionEventType.walletRequest);
    return result;
  }

  Future<MethodResult<Web3DappInfo>> updateWeb3Application({
    required Web3ApplicationAuthentication application,
    required List<Web3InternalChain> chains,
  }) async {
    return _callSynchronized(
        () async => _controller._updateWeb3Application(
            application: application, chains: chains),
        action: () => WalletActionEventType.updateWeb3Auth);
  }

  Future<MethodResult<Web3APPData?>> disconnectWeb3Application(
      Web3ApplicationAuthentication application,
      {bool removeApplication = false}) async {
    return _callSynchronized(
        () async => _controller._disconnectWeb3Application(application,
            removeApplication: removeApplication),
        action: () => WalletActionEventType.updateWeb3Auth);
  }

  Future<MethodResult<void>> changePassword(
      WalletCredentialResponseVerify credential, String newPassword) async {
    return await _callSynchronized(() async {
      await _controller._changePassword(credential, newPassword);
    }, action: () => WalletActionEventType.changePassword);
  }

  Future<MethodResult<void>> expireCredential(
      WalletCredentialResponseVerify credential) async {
    return await _walletAction(() async {
      _wallet?._expireCredential(credential);
    });
  }

  Future<MethodResult<NETWORKCHAINACCOUNT<NETWORKADDRESS>>>
      deriveNewAccount<NETWORKADDRESS>(
          {required NewAccountParams newAccountParams,
          required APPCHAINNETWORK<NETWORKADDRESS> chain}) async {
    return await _callSynchronized(
        () async => await _controller._deriveNewAccount(
            newAccountParams: newAccountParams, chain: chain),
        conditionStatus: () => newAccountParams.isMultiSig ? isOpen : isUnlock,
        delay: APPConst.milliseconds100,
        action: () => WalletActionEventType.deriveAddress);
  }

  Future<MethodResult<void>> importAccount(ImportedKeyStorage newAccountParams,
      WalletCredentialResponseVerify credential) async {
    final result = await _callSynchronized(
        () async =>
            await _controller._importNewKey(newAccountParams, credential),
        action: () => WalletActionEventType.importKey);
    return result;
  }

  Future<MethodResult<bool>> switchWallet(MainWallet wallet) async {
    return await _callSynchronized(() async {
      return await _switchWallet(wallet);
    }, action: () => WalletActionEventType.switchWallet);
  }

  Future<MethodResult<List<EncryptedCustomKey>>> getImportedAccounts() {
    final result = _callSynchronized(() async {
      return _controller._getImportedAccounts();
    }, action: () => WalletActionEventType.exportKey);
    return result;
  }

  List<T> getChains<T extends Chain>() {
    if (isOpen) {
      return _controller._appChains.chains().whereType<T>().toList();
    }
    return [];
  }

  T? chainController<T extends NetworkController>(NetworkType type) {
    if (isOpen) {
      return _controller._appChains.controller<T>(type);
    }
    return null;
  }

  Future<MethodResult<void>> removeImportedKey(
      EncryptedCustomKey key, WalletCredentialResponseVerify credential) {
    return _callSynchronized(() async {
      return await _controller._removeKey(key, credential);
    }, action: () => WalletActionEventType.removeKey);
  }

  Future<void> switchNetwork(Chain? network) async {
    if (network == null) return;
    final result = await _callSynchronized(
        () async => await _controller._switchNetwork(network),
        action: () => WalletActionEventType.switchNetwork);
    assert(!result.hasError,
        "failed to switch network ${result.message} ${result.trace}");
  }

  Future<MethodResult<List<PublicKeyDerivationResult>>> getAccountPubKys(
      {required ChainAccount account}) async {
    final result = await _callSynchronized(
        () async => _controller._getAccountPubKys(account: account),
        action: () => WalletActionEventType.exportAccountKey);
    return result;
  }

  Future<MethodResult<PublicKeyDerivationResult>> getKeyDerivationPublicKey(
      AddressDerivationIndex index) async {
    final result = await _callSynchronized(
        () async => _controller._getKeyDerivationPublicKey(index),
        action: () => WalletActionEventType.exportAccountKey);
    return result;
  }

  Future<void> updateNetwork(WalletNetwork network) async {
    final result = await _callSynchronized(
        () async => await _controller._updateNetwork(network),
        action: () => WalletActionEventType.updateAccount,
        conditionStatus: () =>
            network.isWalletNetwork && network.value == this.network.value);
    return result.result;
  }

  Future<void> importNewNetwork(
      {required WalletNetwork network,
      required List<APIProvider> providers}) async {
    final result = await _callSynchronized(
        () async => await _controller._importNewNetwork(network, providers),
        action: () => WalletActionEventType.importNetwork,
        conditionStatus: () => !network.isWalletNetwork);
    return result.result;
  }

  // Future<void> updateImportNetwork(WalletNetwork network) async {
  //   final result = await _callSynchronized(
  //       () async => await _controller._updateImportNetwork(network),
  //       action: () => network.isWalletNetwork
  //           ? WalletActionEventType.updateAccount
  //           : WalletActionEventType.importNetwork,
  //       conditionStatus: () =>
  //           !network.isWalletNetwork || network.value == this.network.value);
  //   return result.result;
  // }

  Future<MethodResult<void>> removeChain(Chain chain) async {
    final result = await _callSynchronized(
      () async => await _controller._removeChain(chain),
      action: () => WalletActionEventType.removeAccount,
      conditionStatus: () => chain == _controller._chain,
    );
    return result;
  }

  Future<MethodResult<String>> generateWalletBackup(
      {required WalletCredentialResponseVerify credential,
      required GenerateWalletBackupOptions options}) async {
    final result = await _callSynchronized(() async {
      return await _controller._generateWalletBackup(
          options: options, credential: credential);
    }, action: () => WalletActionEventType.backupWallet);
    return result;
  }

  Future<MethodResult<void>> eraseWallet(
      WalletCredentialResponseVerify credential) async {
    return await _callSynchronized(() async {
      await _eraseWallet(credential);
    }, action: () => WalletActionEventType.eraseWallet);
  }

  Future<MethodResult<void>> removeSubWallet(
      {required WalletCredentialResponseVerify credential,
      required int subWalletId}) async {
    return await _callSynchronized(() async {
      await _controller._removeSubWallet(
          credential: credential, subWalletId: subWalletId);
    }, action: () => WalletActionEventType.removeSubWallet);
  }

  Future<MethodResult<T>> signRequest<T>(
      {required WalletSigningRequest<T> request,
      WalletCredentialResponseVerify? credential,
      Duration? timeout}) async {
    final result = await _callSynchronized(() async {
      final Set<ChainAccount> addresses = request.addresses.toSet();
      final Set<AddressDerivationIndex> keys =
          addresses.map((e) => e.signerKeyIndexes()).expand((e) => e).toSet();
      return await _controller._signTransaction(
          request: request,
          credential: credential,
          signers: keys,
          timeout: timeout);
    }, action: () => WalletActionEventType.walletRequest);

    return result;
  }

  Future<MethodResult<void>> updateWalletInfos(
      {required WalletUpdateInfosData walletInfos,
      required WalletCredentialResponseVerify credential}) async {
    return await _callSynchronized(() async {
      return await _controller._updateWalletInfos(
          credential: credential, walletInfos: walletInfos);
    }, action: () => WalletActionEventType.updateWallet);
  }

  Future<void> _validateCredential(WalletCredentialRequest request) async {}

  Future<MethodResult<RESPONSE>>
      login_<RESPONSE extends WalletCredentialResponse>(
          WalletCredentialRequest<RESPONSE> request) async {
    final duration = isUnlock &&
            (request.password == null && request.platformCredential != true)
        ? null
        : APPConst.animationDuraion;
    final result = await _callSynchronized(
      () async {
        if (!isUnlock ||
            request.credential.type != WalletCredentialType.login) {
          await _controller._login(
              password: request.password,
              platformCredential: request.platformCredential);
        }
        await _validateCredential(request);
        return _controller._accsess(request, password: request.password);
      },
      delay: duration,
      action: () {
        if (isUnlock) return WalletActionEventType.accessKey;
        return WalletActionEventType.login;
      },
    );
    return result;
  }

  Future<MethodResult<void>> updateCurrentAccountBalance() async {
    return await _walletAction(() async {
      final chain = _wallet?._chain;
      if (chain != null && chain.haveAddress) {
        return await _controller._updateAddressBalance(
            account: chain, address: chain.address);
      }
    });
  }

  Future<List<EncryptedCustomKey>> getCustomKeysForCoin(
      CryptoCoins coin) async {
    if (!isOpen) return const [];
    final result = await _callSynchronized(() async {
      return _controller._getCustomKeysForCoin(coin);
    },
        delay: Duration.zero,
        action: () => WalletActionEventType.exportKeyInfos);
    return result.result;
  }

  Future<MethodResult<List<int>>> restoreKeysBackup(
      {required String backup,
      required String password,
      required SecretWalletEncoding encoding}) async {
    return _walletAction(() async => await crypto.cryptoIsolateRequest(
          CryptoRequestDecodeBackup(
              password: password, backup: backup, encoding: encoding),
        ));
  }

  Future<T> cryptoMainRequest<T, A extends CborMessageResponseArgs,
      E extends CryptoArgsCompleter<T, A>>(E request) async {
    return crypto.cryptoMainRequest(request);
  }

  Future<T> cryptoIsolateRequest<T, A extends CborMessageResponseArgs>(
      CryptoArgsCompleter<T, A> message,
      {Duration? timeout}) async {
    return crypto.cryptoIsolateRequest<T, A>(message, timeout: timeout);
  }

  Future<T> nonEncryptedRequest<T, A extends CborMessageResponseArgs>(
      NoneEncryptedArgsCompleter<T, A> message,
      {List<int>? encryptedPart,
      WorkerMode mode = WorkerMode.main,
      bool isolate = true}) async {
    return crypto.nonEncryptedRequest<T, A>(message,
        mode: mode, encryptedPart: encryptedPart, isolate: isolate);
  }

  Future<void> initWallet(
      {bool useIsolate = true, String? initialPassword}) async {
    await _callSynchronized(
        () async => await _initWallet(
            useIsolate: useIsolate, initialPassword: initialPassword),
        delay: null,
        action: () => WalletActionEventType.init);
  }

  Future<WalletBackupCore> restoreWalletBackup(
      {required String backup, required String password}) async {
    WalletBackupCore walletBackup;
    final toBytes = BytesUtils.tryFromHexString(backup);
    if (toBytes != null) {
      walletBackup = WalletBackupCore.deserialize(bytes: toBytes);
    } else {
      walletBackup =
          WalletKeyBackup(key: backup, type: WalletBackupTypes.keystore);
    }
    final decodeBytes = await restoreKeysBackup(
        backup: walletBackup.key,
        password: password,
        encoding: walletBackup.type.encoding);
    return walletBackup.decrypt(decodeBytes.result);
  }

  Future<MethodResult<String>> generateWalletKeyBackup(
      {required String data,
      required WalletBackupTypes type,
      required WalletCredentialResponseVerify credential}) async {
    return _callSynchronized(
        () async => await _controller._generateWalletKeyBackup(
            data: data, credential: credential, type: type),
        action: () => WalletActionEventType.backup);
  }

  Future<MainWallet> createWallet(
      {required String mnemonic,
      required String? passphrase,
      required String password}) async {
    if (passphrase?.isEmpty ?? false) {
      throw AppCryptoExceptionConst.invalidMnemonicPassphrase;
    }
    final newWallet = _wallets.createNewMainWallet(
        name: StrUtils.addNumberToMakeUnique(
            _wallets.walletNames, HDWalletsConst.initializeName));
    final encrypt = await crypto.cryptoIsolateRequest(
        CryptoRequestCreateHDWallet(
            mnemonic: mnemonic,
            passphrase: passphrase,
            password: password,
            checksum: newWallet.checkSumBytes));
    return newWallet.updateData(encrypt.masterKey.storageDataB64());
  }

  Future<WalletRestoreV2> restoreWalletBackupV3(
      {required WalletBackup backup,
      required String? passhphrase,
      required String password,
      LivePercentProgressBar? progress,
      bool verify = true}) async {
    try {
      if (backup.type != WalletBackupTypes.walletV3) {
        throw WalletExceptionConst.invalidBackupData;
      }
      if (passhphrase?.isEmpty ?? false) {
        throw AppCryptoExceptionConst.invalidMnemonicPassphrase;
      }
      final newWallet = backup.wallet
          .updateId(_wallets.generateNewWalletId())
          .updateKey(_wallets.generateNewWalletChecksum());
      final memoryKey = QuickCrypto.generateRandom();
      final resotreKey = await crypto.cryptoIsolateRequest(
          CryptoRequestRestoreBackupMasterKey(
              rawKey: StringUtils.encode(password),
              checksum: newWallet.checkSumBytes,
              backup: BytesUtils.fromHexString(backup.key),
              passphrase: passhphrase,
              memoryKey: memoryKey));

      return await _validateBackupAccounts(
          backup: backup,
          wallet:
              newWallet.updateData(resotreKey.encryptedKey.storageDataB64()),
          resotreKey: resotreKey,
          memoryKey: memoryKey,
          progress: progress,
          verify: verify);

      ///
    } catch (_) {
      throw WalletExceptionConst.invalidBackupData;
    }
  }

  Future<WalletRestoreV2> _validateBackupAccounts(
      {required WalletBackup backup,
      required CryptoRestoreBackupMasterKeyResponse resotreKey,
      required MainWallet wallet,
      required List<int> memoryKey,
      LivePercentProgressBar? progress,
      bool verify = false}) async {
    final setupKey = resotreKey.masterKey;
    final bool validChekcsum =
        BytesUtils.bytesEqual(backup.checksum, resotreKey.checksum);
    if (!resotreKey.isValid || !validChekcsum) {
      return WalletRestoreV2(
          masterKeys: resotreKey.masterKey,
          chains: const [],
          dapps: const [],
          networks: const [],
          invalidAddresses: const [],
          verifiedChecksum: false,
          wallet: wallet);
    }

    final List<WalletNetworkBackup> validateChains = [];
    List<ChainAccount> invalidAddresses = [];
    List<String> validateImportedKeys = [];
    List<int> validateSubwallets = [];
    bool validateMainWallet = false;
    bool isValidKeyIndex({int? subId, String? importedKey}) {
      if (subId == null && importedKey == null) return true;
      if (subId != null) {
        return (resotreKey.encryptedKey.hasSubwallet(subId) &&
            wallet.hasSubwallet(subId));
      }
      return resotreKey.encryptedKey.hasImportedKey(importedKey!);
    }

    Future<bool> isValidAddress(
        {required Chain chain,
        required ChainAccount address,
        int? subId,
        String? imported,
        bool verify = false}) async {
      if (!verify) {
        if (subId != null) {
          if (validateSubwallets.contains(subId)) return true;
          if (!isValidKeyIndex(subId: subId)) return false;
        } else if (imported != null) {
          if (validateImportedKeys.contains(imported)) return true;
          if (!isValidKeyIndex(importedKey: imported)) return false;
        } else {
          if (validateMainWallet) {
            return true;
          }
        }
      }
      final addr = await crypto.walletArgs(
          memoryKey: memoryKey,
          message: WalletRequestDeriveAddress(
              addressParams: address.toAccountParams()),
          masterKey: resotreKey.encryptedKey.masterKey);
      final account =
          addr.accountParams.toAccount(chain.network, addr.publicKey);
      final valid = address.identifier == account.identifier;
      if (!verify) {}
      if (valid) {
        if (subId != null) {
          validateSubwallets.add(subId);
        } else if (imported != null) {
          validateImportedKeys.add(imported);
        } else {
          validateMainWallet = true;
        }
      }

      return valid;
    }

    Future<ChainAccount?> reGenerateAddress(
        {required Chain chain,
        required ChainAccount address,
        bool verify = false}) async {
      final network = chain.network;
      final keyIndexes = address.signerKeyIndexes();
      for (final i in keyIndexes) {
        if (!isValidKeyIndex(subId: i.subId, importedKey: i.importedKeyId)) {
          return null;
        }
      }
      if (address.multiSigAccount) {
        final multiSigAccount =
            address.toAccountParams().toAccount(network, null);
        final isValid = address.identifier == multiSigAccount.identifier;
        if (isValid) return multiSigAccount;
      } else {
        final keyIndexs = address.signerKeyIndexes();
        ChainAccount? validAddress;
        for (final i in keyIndexs) {
          final isValid = await isValidAddress(
              chain: chain,
              address: address,
              imported: i.importedKeyId,
              subId: i.subId,
              verify: verify);
          if (!isValid) return null;
          validAddress = address;
        }
        return validAddress;
      }
      return null;
    }

    final totalAccount =
        backup.networks.fold(0, (p, c) => p + c.chain.addresses.length);
    progress?.init(totalAccount);
    for (final c in backup.networks) {
      final List<ChainAccount> addresses = [];
      for (final address in c.chain.addresses) {
        try {
          final validAddress = await reGenerateAddress(
              chain: c.chain, address: address, verify: verify);
          if (validAddress != null) {
            addresses.add(validAddress);
          } else {
            invalidAddresses.add(address);
          }
        } catch (_) {
          invalidAddresses.add(address);
        } finally {
          progress?.counter();
        }
      }
      final chain = WalletNetworkBackup(
          chain: c.chain.copyWith(addresses: addresses, id: wallet.key),
          repositories: c.repositories);

      validateChains.add(chain);
    }

    for (final i in backup.networks) {
      i.chain.dispose();
    }
    return WalletRestoreV2(
        masterKeys: setupKey,
        dapps: backup.dapps,
        networks: validateChains,
        invalidAddresses: invalidAddresses,
        chains: backup.chains,
        wallet: wallet,
        verifiedChecksum: validChekcsum);
  }
}
