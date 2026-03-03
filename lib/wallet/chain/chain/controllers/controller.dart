part of 'package:on_chain_wallet/wallet/chain/chain/chain.dart';

base mixin BaseChainController<
        PROVIDER extends APIProvider,
        NETWORKPARAMS extends NetworkCoinParams,
        NETWORKADDRESS,
        TOKEN extends TokenCore,
        NFT extends NFTCore,
        ADDRESS extends ChainAccount,
        NETWORK extends WalletNetwork,
        CLIENT extends NetworkClient,
        CONFIG extends DefaultNetworkConfig,
        TRANSACTION extends ChainTransaction,
        CONTACT extends ContactCore,
        ADDRESSPARAM extends NewAccountParams>
    on
        BaseChain<PROVIDER, NETWORKPARAMS, NETWORKADDRESS, TOKEN, NFT, ADDRESS,
            NETWORK, CLIENT, CONFIG, TRANSACTION, CONTACT, ADDRESSPARAM>,
        ChainRepository<PROVIDER, ADDRESS, NETWORK, CLIENT, CONFIG, TOKEN, NFT,
            TRANSACTION, CONTACT, ADDRESSPARAM> {
  StreamSubscription<void>? txSub;
  bool _isOnline = true;
  int _currentWalletChainId = -1;
  bool get _isCurrentWalletChain => _currentWalletChainId == network.value;
  bool get isCurrentWalletChain => _isCurrentWalletChain;
  late final List<String> _services = ChainConst.services(network);
  final CachedObject<void> _onUpdateAccountBalance =
      CachedObject<void>(interval: const Duration(seconds: 30));

  final OnceRunner<List<ADDRESS>> _loadAddresses = OnceRunner<List<ADDRESS>>();

  Future<List<ADDRESS>> getAccountAddresses() async {
    return await _loadAddresses.get(
        onFetch: () async {
          _addresses = await _getAddresses();
          for (final i in _addresses) {
            i._setStorage(_storage);
          }
          return _addresses;
        },
        onFetched: () => _addresses);
  }

  @override
  List<String> get services => _services;
  Future<void> _onWalletPing() async {
    await _onUpdateAccountBalance.get(onFetch: () async {
      await updateAccountBalance();
      _trackTxes();
    });
  }

  Future<void> _onConnectionStatusChange(bool isOnline) async {
    _isOnline = isOnline;
    if (!isOnline) {
      txSub?.cancel();
      txSub = null;
    }
  }

  Future<void> _onWalletChainChanged(ChainWalletChainChangeEvent evnet) async {
    if (evnet.current.network.value == network.value) {
      _onWalletPing();
    }
  }

  Future<void> _onWalletEvent(ChainWalletEvent event) async {
    switch (event.type) {
      case ChainWalletEventType.ping:
        await _onWalletPing();
        break;
      case ChainWalletEventType.connection:
        _isOnline = event.cast<ChainWalletConnectionEvent>().isOnline;
        await _onConnectionStatusChange(_isOnline);
        break;
      case ChainWalletEventType.chainChanged:
        final changed = event.cast<ChainWalletChainChangeEvent>();
        _currentWalletChainId = changed.current.network.value;
        await _onWalletChainChanged(changed);
        break;
    }
  }

  void _isAccountAddress(ADDRESS address) {
    if (!_addresses.contains(address)) {
      throw WalletExceptionConst.accountDoesNotFound;
    }
  }

  Future<T> _callSynchronized<T extends Object?>({
    required Future<T> Function() t,
    DefaultChainNotify? type,
    _WalletChainStatus? allowStatus = _WalletChainStatus.ready,
    // bool saveAccount = false,
    bool Function(T result)? saveAccount,
    bool notifyProgress = false,
    bool notifyComplete = true,
    bool wait = false,
    LockId lockId = LockId.two,
  }) async {
    return await _lock.run(() async {
      if (allowStatus != null && allowStatus != _status) {
        if (allowStatus == _WalletChainStatus.ready) {
          await _initInternal(client: false);
        }
        if (allowStatus != _status) {
          throw WalletExceptionConst.invalidChainState;
        }
      }
      if (notifyProgress && type != null) {
        _controller.add(ChainEvent.progress(type));
        if (wait) await Future.delayed(Duration(milliseconds: 600));
      }
      try {
        final r = await t();
        if (saveAccount != null && saveAccount(r)) await _saveAccountInternal();
        return r;
      } finally {
        if (notifyComplete && type != null) {
          appLogger.debug(
              runtime: runtimeType,
              functionName: "_callSynchronized",
              msg: "notify $type");
          _controller.add(ChainEvent.complete(type));
        }
      }
    }, lockId: lockId);
  }

  Future<void> updateConfig(CONFIG status) async {
    await _callSynchronized(
        t: () async {
          _config = status;
        },
        type: DefaultChainNotify.config,
        saveAccount: (_) => true);
  }

  AddressDerivationIndex nextDerive(
      {required CryptoCoins coin,
      required SeedTypes seedGeneration,
      required int? subId}) {
    return BipDerivationUtils.generateAccountNextKeyIndex(
        coin: coin,
        addresses: _addresses,
        seedGenerationType: seedGeneration,
        coinType: network.coinParam.bip32CoinType,
        subId: subId);
  }

  Future<ADDRESS> addNewAddress(
      CryptoPublicKeyData? publicKey, ADDRESSPARAM accountParams) async {
    return _callSynchronized(
        t: () async {
          if (!network.coins.contains(accountParams.coin)) {
            throw AppCryptoExceptionConst.invalidCoin;
          }
          final ADDRESS newAddress =
              accountParams.toAccount(network, publicKey).cast();
          final any = _addresses
              .any((element) => element.identifier == newAddress.identifier);
          if (any) {
            throw WalletExceptionConst.addressAlreadyExist;
          }
          _addresses = List.unmodifiable([..._addresses, newAddress]);
          updateAddressBalance(newAddress);
          newAddress._setStorage(_storage);
          await newAddress.init();
          await newAddress._saveAddress();
          return newAddress;
        },
        type: DefaultChainNotify.address,
        notifyProgress: _addresses.isEmpty);
  }

  ADDRESS? getAddress(String address) {
    return _addresses
        .firstWhereOrNull((element) => element.viewAddress == address);
  }

  ADDRESS? fromNetworkAddress(NETWORKADDRESS address) {
    return _addresses
        .firstWhereOrNull((element) => element.networkAddress == address);
  }

  CONTACT? getContact(String address) {
    return _contacts.firstWhereOrNull((element) {
      return element.address == address;
    });
  }

  ReceiptAddress<NETWORKADDRESS>? getReceiptAddress(String address) {
    final isAccount = getAddress(address);
    final contact = getContact(address);
    if (isAccount != null) {
      return ReceiptAddress<NETWORKADDRESS>(
          account: isAccount as NETWORKCHAINACCOUNT<NETWORKADDRESS>,
          view: isAccount.address.toAddress,
          type: isAccount.type,
          networkAddress: isAccount.networkAddress,
          contact: contact as ContactCore<NETWORKADDRESS>?);
    }

    if (contact != null) {
      return ReceiptAddress<NETWORKADDRESS>(
          contact: contact as ContactCore<NETWORKADDRESS>,
          view: contact.address,
          type: contact.type,
          networkAddress: contact.addressObject);
    }
    return null;
  }

  static BigInt _totalBalance(List<ChainAccount> addresses) {
    final Map<String, BigInt> total = {
      for (final i in addresses) i.baseAddress: i.address.currencyBalance
    };
    return total.values
        .fold(BigInt.zero, (previousValue, element) => previousValue + element);
  }

  Future<void> _refreshTotalBalance() async {
    final totalBalances = _totalBalance(_addresses);
    if (totalBalance.value._internalUpdateBalance(totalBalances)) {
      await _saveAccountInternal();
    }
  }

  List<TOKEN> tokens() {
    return _addresses.map((e) => e.tokens).expand((e) => e).toList().cast();
  }

  Future<CLIENT> client() async {
    final cl = _service;
    if (_clientStatus.isConnect && cl != null && config.enableProvider) {
      return cl;
    }
    final serviceIdentifier = _serviceIdentifier;
    final CLIENT? client = await _callSynchronized<CLIENT?>(
        allowStatus: null,
        notifyProgress: true,
        t: () async {
          final cl = _service;
          if (_clientStatus.isConnect && cl != null && config.enableProvider) {
            return cl;
          }
          _clientStatus = NodeClientStatus.pending;
          final service = await () async {
            if (!config.enableProvider) {
              return null;
            }
            ProviderIdentifier? identifier = _serviceIdentifier;
            final client = _service;
            if (client != null && client.serviceIdentifier == identifier) {
              final init = await client.init();
              return (client, init);
            }
            client?.dispose();
            final providers = await _getProviders();
            if (identifier != null) {
              final client = APIUtils.findClient<CLIENT>(
                  network: network,
                  providers: providers,
                  identifier: identifier);
              final init = await client?.init();
              return (client, init);
            } else {
              final clients = APIUtils.getClients<CLIENT>(
                      network: network, providers: providers) ??
                  [];
              for (final i in clients) {
                final init = await i.init();
                if (init) {
                  return (i, true);
                }
              }
            }
            return null;
          }();
          final client = service?.$1;
          final connect = service?.$2 ?? false;
          _serviceIdentifier = client?.serviceIdentifier;
          _service = client;
          if (!connect) {
            if (!config.enableProvider) {
              _clientStatus = NodeClientStatus.disabled;
            } else {
              _clientStatus = NodeClientStatus.disconnect;
            }
            return null;
          }
          _clientStatus = NodeClientStatus.connect;
          return _service;
        },
        type: DefaultChainNotify.client,
        lockId: LockId.one,
        saveAccount: (result) => serviceIdentifier != _serviceIdentifier);

    if (client == null) {
      throw ApiProviderException.message("node_connection_error");
    }
    return client;
  }

  @override
  Future<CLIENT?> clientOrNull() async {
    try {
      final client = await this.client();
      return client;
    } catch (e) {
      return null;
    }
  }

  Future<T> onClient<T extends Object?>(
      {required Future<T> Function(CLIENT client) onConnect,
      Future<T> Function(Object err)? onError}) async {
    try {
      final client = await this.client();
      return await onConnect(client);
    } catch (e, s) {
      appLogger.error(
          runtime: runtimeType, functionName: "onClient", msg: e, trace: s);
      if (onError != null) {
        return onError(e);
      }
      if (null is T) return null as T;
      rethrow;
    }
  }

  Future<void> removeContact(CONTACT contact) async {
    await _callSynchronized(
        t: () async {
          final findContact = getContact(contact.address);
          if (findContact == null) return;
          final newContacts =
              _contacts.where((element) => element != findContact).toList();
          _contacts = List.unmodifiable(newContacts);
          await _removeContact(contact);
        },
        type: DefaultChainNotify.contacts);
  }

  Future<void> switchAccount(ADDRESS address) async {
    _isAccountAddress(address);
    await _callSynchronized(
        t: () async {
          final index = _addresses.indexOf(address);
          if (index < 0 || index == _addressIndex) return;
          _addressIndex = index;
          await _initAddress(address);
          updateAddressBalance(address);
        },
        saveAccount: (_) => true,
        notifyProgress: true,
        wait: true,
        type: DefaultChainNotify.address);
  }

  Future<bool> removeAccount(ADDRESS address) async {
    _isAccountAddress(address);
    return _callSynchronized(
        notifyProgress: true,
        wait: true,
        t: () async {
          await address._removeAddress();
          final currentAddress = this.address;
          final currentAccounts = List<ADDRESS>.from(_addresses);
          currentAccounts.remove(address);
          _addresses = currentAccounts;
          _addressIndex = _addresses.indexOf(currentAddress);
          if (_addressIndex < 0) {
            _addressIndex = 0;
          }
          _refreshTotalBalance();
          await _initAddress(_addresses.elementAtOrNull(_addressIndex));
          return true;
        },
        type: DefaultChainNotify.address,
        saveAccount: (_) => true);
  }

  // CLIENT? _getProviderInternal(ProviderIdentifier service) {
  //   if (!service.status.isEnable) {
  //     return null;
  //   }
  //   return APIUtils.createApiClient<CLIENT>(
  //       network: network,
  //       providers: providers,
  //       identifier: service,
  //       requestTimeut: requestTimeout);
  // }

  Future<void> setProvider(ProviderIdentifier service,
      {Duration? requestTimeout}) async {
    assert(service.network == network.type, "invalid service identifier");
    if (service.network != network.type) return;
    await _callSynchronized(
        lockId: LockId.one,
        notifyProgress: true,
        t: () async {
          final currentProvider = _service;
          _serviceIdentifier = service;
          _service = null;
          if (config.enableProvider) {
            _service = APIUtils.findClient(
                network: network,
                providers: await _getProviders(),
                identifier: service);
          }
          currentProvider?.dispose();
          _clientStatus = NodeClientStatus.disconnect;
          clientOrNull();
        },
        type: DefaultChainNotify.client,
        saveAccount: (_) => true);
  }

  Future<void> _saveAccountInternal() async {
    await _storage.saveAccount(this as Chain);
  }

  Future<void> _removeAccount() async {
    await _storage.removeAccount(this as Chain);
  }

  Future<void> toggleServiceProvider(bool enable) async {
    if (enable == _config.enableProvider) return;
    await updateConfig(_config.copyWith(enableProvider: enable) as CONFIG);
    clientOrNull();
  }

  Future<void> removeNFT({required NFT nft, required ADDRESS address}) async {
    _isAccountAddress(address);
    await _callSynchronized(
        t: () async {
          await address._removeNFT(nft);
        },
        type: DefaultChainNotify.nft);
  }

  Future<void> addNewNFT({required NFT nft, required ADDRESS address}) async {
    _isAccountAddress(address);
    await _callSynchronized(
        t: () async {
          await address._addNFT(nft);
        },
        type: DefaultChainNotify.nft);
  }

  /// set or update address name.
  /// -[name]: for update or remove if null.
  /// -[address]: address for updating name.
  Future<void> setupAccountName(
      {String? name, required ADDRESS address}) async {
    _isAccountAddress(address);
    await _callSynchronized(
        t: () async {
          if (name == null || !APPConst.accountNameRegExp.hasMatch(name)) {
            return;
          }
          await address._setAccountName(name);
        },
        type: DefaultChainNotify.address);
  }

  Future<void> addNewContact(CONTACT newContact) async {
    await _callSynchronized(
        wait: true,
        t: () async {
          if (contacts.contains(newContact) ||
              contacts.any((e) => e.name == newContact.name)) {
            throw WalletExceptionConst.contactExists;
          }
          if (newContact.name.length < 3) {
            throw WalletExceptionConst.invalidContactDetails;
          }
          _contacts = List.unmodifiable([newContact, ..._contacts]);
          await _saveContact(newContact);
        },
        type: DefaultChainNotify.contacts);
  }

  /// add new token to address
  /// -[address]: address for importing token
  Future<void> addNewToken(
      {required TOKEN token, required ADDRESS address}) async {
    _isAccountAddress(address);
    await _callSynchronized(
        t: () async {
          final newToken = await address._addToken(token);
          updateTokenBalance(address: address, tokens: [newToken as TOKEN]);
        },
        type: DefaultChainNotify.token);
  }

  /// remove token from address
  /// -[token]: token for remove
  /// -[address]: owner address of token
  Future<void> removeToken(
      {required TOKEN token, required ADDRESS address}) async {
    _isAccountAddress(address);

    /// before remove the asset must be exsits in asset list
    await _callSynchronized(
        t: () async {
          await address._removeToken(token);
        },
        type: DefaultChainNotify.token);
  }

  /// update address token information like name, decimal and etc ...
  /// -[updatedToken]: updated token
  /// -[token]: token form update
  /// -[address]: owner address of token
  Future<void> updateToken(
      {required TOKEN token,
      required ADDRESS address,
      required Token updatedToken}) async {
    _isAccountAddress(address);
    await _callSynchronized(
        wait: true,
        t: () async {
          await address._updateToken(updatedToken, token);
        },
        type: DefaultChainNotify.token);
  }

  Future<void> _trackTxes() async {
    await onClient(onConnect: (client) async {
      _callSynchronized(
          allowStatus: null,
          t: () async {
            if (txSub != null) return;
            final List<TrackTransactionRequest<TRANSACTION, ADDRESS>>
                unCofirmTxes = [];
            for (final i in _addresses) {
              final addressTxes = await i._getTransactions();
              if (!addressTxes.havePendingTxes) continue;
              final pendingTxes =
                  addressTxes.pendingTxes.whereType<TRANSACTION>().toList();
              final txes = TrackTransactionRequest<TRANSACTION, ADDRESS>(
                  transactions: pendingTxes, account: i);
              unCofirmTxes.add(txes);
            }
            appLogger.debug(
                when: () => unCofirmTxes.isNotEmpty,
                runtime: runtimeType,
                functionName: "_trackTxes ${network.networkName}",
                msg: "${unCofirmTxes.length} pending txes founds.");
            if (unCofirmTxes.isEmpty) {
              return;
            }
            txSub = client
                .trackMempoolTransaction(
                    unCofirmTxes.expand((e) => e.transactions).toList())
                .listen((tx) async {
              final address = unCofirmTxes
                  .firstWhere((e) => e.transactions.contains(tx))
                  .account;
              await _callSynchronized(
                  type: DefaultChainNotify.transaction,
                  allowStatus: null,
                  t: () async {
                    address._addTx(tx);
                    updateAddressBalance(address);
                  });
            }, onDone: () {
              txSub = null;
            });
          });
    });
  }

  Future<void> saveTransaction(
      {required ADDRESS address, required TRANSACTION transaction}) async {
    await _callSynchronized(
        type: DefaultChainNotify.transaction,
        t: () async {
          await address._addTx(transaction);
          _trackTxes();
        });
  }

  Future<void> removeTransaction(
      {required ADDRESS address, required TRANSACTION transaction}) async {
    _isAccountAddress(address);
    await _callSynchronized(
      type: DefaultChainNotify.transaction,
      t: () async {
        await address._removeTx(transaction);
      },
    );
  }

  /// update address balance
  /// -[address]: address for retrive and update balance
  Future<void> updateAddressBalance(ADDRESS address,
      {bool tokens = true}) async {
    _isAccountAddress(address);
    await _updateAddressBalanceInternal(address, tokens: tokens);
    _refreshTotalBalance();
  }

  Future<void> _updateAddressBalanceInternal(ADDRESS address,
      {bool tokens = true});

  Future<void> updateTokenBalance(
      {required ADDRESS address, required List<TOKEN> tokens});

  Future<void> updateAccountBalance(
      {List<ADDRESS>? addresses, bool tokens = true}) async {
    addresses ??= await getAccountAddresses();
    if (addresses.isEmpty) return;
    await Future.wait(addresses.map((e) async {
      return updateAddressBalance(e, tokens: tokens);
    }));
    _refreshTotalBalance();
  }

  Future<void> _initAddress(ADDRESS? address) async {
    if (address == null || !address._status.isInit) return;
    _isAccountAddress(address);
    await address.init();
  }

  Future<void> _initInternal({bool client = true}) async {
    _contacts = (await _getContacts()).toImutableList;
    if (_addresses.isNotEmpty) {
      await _saveAddresses(_addresses);
      await _saveAccountInternal();
      appLogger.debug(
          runtime: runtimeType,
          msg: "addresses ${_addresses.length}",
          functionName: "_initInternal");
    }
    _addresses = await getAccountAddresses();
    _addressIndex = _addressIndex >= _addresses.length ? 0 : _addressIndex;
    await _initAddress(_addresses.elementAtOrNull(_addressIndex));
    _status = _WalletChainStatus.ready;
    if (client) clientOrNull();
  }

  Future<void> init({bool client = true}) async {
    if (!_status.isInit) return;
    try {
      await _callSynchronized(
          allowStatus: _WalletChainStatus.init,
          t: () async {
            await _initInternal(client: client);
          },
          type: DefaultChainNotify.address);
    } catch (e) {
      if (e == WalletExceptionConst.invalidChainState) return;
      rethrow;
    }
  }

  void dispose() {
    _callSynchronized(
        t: () async {
          _status = _WalletChainStatus.dispose;
          _storage.dispose();
          _controller.close();
          _service?.dispose();
          txSub?.cancel();
          txSub = null;
        },
        allowStatus: null);
  }

  Future<List<PROVIDER>> getProviders({ProviderIdentifier? identifier}) async {
    return _callSynchronized(
      t: () async {
        final providers = await _getProviders();
        return APIUtils.getAllProviders(network: network, providers: providers);
      },
    );
  }

  Future<List<PROVIDER>?> getProvider(
      {ProviderIdentifier? identifier, bool allowInWeb3 = false}) async {
    final providers = await _getProviders();
    return APIUtils.findProvider(
        network: network,
        providers: providers,
        identifier: _serviceIdentifier,
        allowInWeb3: allowInWeb3);
  }

  Future<void> updateProvider(PROVIDER provider) async {
    await _callSynchronized(
        lockId: LockId.one,
        t: () async {
          await _addNewProvider(provider);
        },
        type: DefaultChainNotify.updateProvider);
  }

  Future<void> removeProvider(PROVIDER provider) async {
    await _callSynchronized(
        lockId: LockId.one,
        t: () async {
          await _removeProvider(provider);
          _service?.dispose();
          _service = null;
          _serviceIdentifier = null;
          clientOrNull();
        },
        type: DefaultChainNotify.updateProvider);
  }

  Future<void> closeClient() async {
    _service?.close();
  }

  @override
  CborTagValue toCbor() {
    return CborTagValue(
        CborSerializable.fromDynamic([
          network.value,
          network.toCbor(),
          id,
          CborSerializable.fromDynamic([]),
          _addressIndex,
          config.toCbor(),
          _serviceIdentifier?.toCbor(),
          CborBigIntValue(totalBalance.value.balance),
        ]),
        CborTagsConst.iAccount);
  }

  Future<CborTagValue> toBackupCbor() async {
    await getAccountAddresses();
    return CborTagValue(
        CborSerializable.fromDynamic([
          network.value,
          network.toCbor(),
          id,
          CborSerializable.fromDynamic(
              _addresses.map((e) => e.toCbor()).toList()),
          _addressIndex,
          config.toCbor(),
          _serviceIdentifier?.toCbor(),
          CborBigIntValue(totalBalance.value.balance)
        ]),
        CborTagsConst.iAccount);
  }
}
