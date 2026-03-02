part of 'package:on_chain_wallet/wallet/chain/chain/chain.dart';

class ChainStorageManager with BaseRepository {
  final List<DefaultChainStorageId> chainStorageIds;

  /// table name
  String? _id;
  final NetworkType networkType;
  ChainStorageManager({
    required String id,
    required this.networkType,
  })  : _id = id,
        chainStorageIds = DefaultChainStorageId.values;
  @override
  String get tableId {
    final id = _id;
    if (id == null) throw WalletExceptionConst.storageIsNotAvailable;
    return id;
  }

  Future<List<ITableDataStructA>> _queriesStorage(
      {required int storage,
      StorageId? storageKey,
      String? key,
      String? keyA,
      int? offset,
      int? limit,
      int? createdAtLt,
      int? createdAtGt,
      IDatabaseQueryOrdering ordering = IDatabaseQueryOrdering.desc}) async {
    return await queriesStorage(
        storageId: storageKey?.storageId,
        storage: storage,
        key: key,
        keyA: keyA,
        offset: offset,
        limit: limit,
        ordering: ordering,
        createdAtLt: createdAtLt,
        createdAtGt: createdAtGt);
  }

  Future<List<List<int>>> queriesChainStorage(
      {required ChainStorageId storage,
      String? key,
      String? keyA,
      int? offset,
      int? limit,
      IDatabaseQueryOrdering ordering = IDatabaseQueryOrdering.desc}) async {
    final data = await _queriesStorage(
        storageKey: storage,
        key: key,
        storage: networkType.id,
        keyA: keyA,
        offset: offset,
        limit: limit,
        ordering: ordering);
    return data.map((e) => e.data).toList();
  }

  Future<List<int>?> queryChainStorage({
    required StorageId storage,
    String? key,
    String? keyA,
  }) async {
    return queryStorageData(
        storage: networkType.id,
        storageId: storage.storageId,
        key: key,
        keyA: keyA);
  }

  Future<bool> insertChainStorage(
      {required CborSerializable value,
      required StorageId storage,
      String? key,
      String? keyA}) async {
    return insertStorage(
        storage: networkType.id,
        storageId: storage.storageId,
        key: key,
        keyA: keyA,
        value: value);
  }

  Future<bool> removeChainStorage(
      {StorageId? storage, String? key, String? keyA}) async {
    return await removeStorage(
        storage: networkType.id,
        storageId: storage?.storageId,
        key: key,
        keyA: keyA);
  }

  void dispose() {
    _id = null;
  }

  Future<List<WalletBackupChainRepository>> readAllChainRepositories(
      {List<String> web3Identifier = const []}) async {
    final shared = await _queriesStorage(storage: networkType.id);
    List<WalletBackupChainRepository> chainRepositories = [];
    for (final i in shared) {
      if (i.storageId == DefaultChainStorageId.web3.storageId &&
          !web3Identifier.contains(i.key)) {
        continue;
      }
      final storage =
          chainStorageIds.firstWhereOrNull((e) => e.storageId == i.storageId);
      assert(storage != null, "unknow storage key ${i.storageId}");
      if (storage == null) continue;
      final repository = WalletBackupChainRepository(
          storageID: storage.storageId,
          value: i.data,
          identifier: i.key,
          identifier2: i.keyA,
          createdAt: i.createdAt,
          chainID: networkType.id);
      chainRepositories.add(repository);
    }

    return chainRepositories;
  }

  Future<void> restoreChainRepositories(
      List<WalletBackupChainRepository> repositories) async {
    List<ITableInsertOrUpdateStructA> params = [];
    for (final i in repositories) {
      if (i.chainID != networkType.id) {
        throw WalletExceptionConst.invalidBackupData;
      }
      final storageKey =
          chainStorageIds.firstWhereOrNull((e) => e.storageId == i.storageID);
      // assert(storageKey != null, "unknown storage key");
      if (storageKey == null) continue;
      final createdAt = i.createdAt;
      final param = ITableInsertOrUpdateStructA(
          data: i.value,
          storage: networkType.id,
          storageId: i.storageID,
          key: i.identifier,
          keyA: i.identifier2,
          createdAt: createdAt == null
              ? null
              : DateTimeUtils.fromSecondsSinceEpoch(createdAt),
          tableName: tableId);
      params.add(param);
    }

    await insertAllStorage(params);
  }
}

/// for chain storage management networkid and [NetworkType.id] allowed to [100000 - 1]
class NetworkStorageManager extends ChainStorageManager {
  static const int maxAddressItemLimit = 300;

  final NetworkConfig config;

  /// storage id
  final WalletNetwork network;
  int get networkId => network.value;

  /// shared storage id [NetworkType.id]
  // final NetworkType networkType;
  NetworkStorageManager._({
    required this.network,
    required super.id,
    required this.config,
    required super.networkType,
  });
  factory NetworkStorageManager(
      {required WalletNetwork network,
      required String id,
      required NetworkConfig config}) {
    return NetworkStorageManager._(
        network: network, id: id, config: config, networkType: network.type);
  }

  Future<List<List<int>>> queriesNetworkStorage(
      {required StorageId storage,
      BaseChainAccount? address,
      String? keyA,
      int? offset,
      int? limit,
      IDatabaseQueryOrdering ordering = IDatabaseQueryOrdering.desc}) async {
    final data = await _queriesStorage(
        storage: networkId,
        key: address?.identifier,
        storageKey: storage,
        keyA: keyA,
        offset: offset,
        limit: limit,
        ordering: ordering);
    return data.map((e) => e.data).toList();
  }

  Future<List<int>?> queryNetworkStorage({
    required StorageId storage,
    BaseChainAccount? address,
    String? keyA,
  }) async {
    return await queryStorageData(
        storage: networkId,
        storageId: storage.storageId,
        key: address?.identifier,
        keyA: keyA);
  }

  Future<bool> insertNetworkStorage(
      {required CborSerializable value,
      required StorageId storage,
      BaseChainAccount? address,
      String? keyA,
      DateTime? createdAt}) async {
    final data = await insertStorage(
        storage: networkId,
        storageId: storage.storageId,
        key: address?.identifier,
        keyA: keyA,
        value: value,
        createdAt: createdAt);
    return data;
  }

  Future<bool> insertNetworkStorages(
      {required List<CborSerializable> values,
      required StorageId storage,
      BaseChainAccount? address,
      List<String>? keys,
      List<DateTime>? createdAt}) async {
    if (values.isEmpty) return true;
    final totalItems = values.length;
    if ((keys != null && keys.length != totalItems) ||
        (createdAt != null && createdAt.length != totalItems)) {
      throw WalletExceptionConst.internalError("Bad storage items");
    }
    final items = List.generate(
      values.length,
      (index) {
        return ITableInsertOrUpdateStructA(
            storage: networkId,
            storageId: storage.storageId,
            key: address?.identifier,
            keyA: keys?.elementAt(index),
            data: values.elementAt(index).toCbor().encode(),
            tableName: tableId,
            createdAt: createdAt?.elementAt(index));
      },
    );
    final data = await insertStorages(items);
    return data;
  }

  Future<bool> removeNetworkStorage(
      {StorageId? storage, BaseChainAccount? address, String? keyA}) async {
    return await removeStorage(
        storage: networkId,
        storageId: storage?.storageId,
        key: address?.identifier,
        keyA: keyA);
  }

  Future<List<WalletBackupNetworkRepository>> readAllRepositories() async {
    final keys = await _queriesStorage(storage: networkId);
    List<WalletBackupNetworkRepository> chainRepositories = [];
    for (final i in keys) {
      final storage = config.storageKeys
          .firstWhereOrNull((e) => e.storageId == i.storageId);
      if (storage == null || storage == DefaultNetworkStorageId.address) {
        continue;
      }
      final repository = WalletBackupNetworkRepository(
          identifier: i.key,
          storageID: storage.storageId,
          value: i.data,
          networkID: networkId,
          identifier2: i.keyA,
          createdAt: i.createdAt);
      chainRepositories.add(repository);
    }
    return chainRepositories;
  }

  Future<void> restoreNetworkRepositories(
      List<WalletBackupNetworkRepository> repositories) async {
    List<ITableInsertOrUpdateStructA> params = [];
    for (final i in repositories) {
      if (i.networkID != networkId) {
        throw WalletExceptionConst.invalidBackupData;
      }
      final storageKey = config.storageKeys
          .firstWhereOrNull((e) => e.storageId == i.storageID);
      // assert(storageKey != null, "unknown storage key");
      if (storageKey == null) continue;
      final createdAt = i.createdAt;
      final param = ITableInsertOrUpdateStructA(
          data: i.value,
          storage: networkId,
          storageId: i.storageID,
          key: i.identifier,
          keyA: i.identifier2,
          createdAt: createdAt == null
              ? null
              : DateTimeUtils.fromSecondsSinceEpoch(createdAt),
          tableName: tableId);
      params.add(param);
    }

    await insertAllStorage(params);
  }

  Future<void> saveAccount(Chain chain) async {
    await insertNetworkStorage(
        value: chain, storage: DefaultNetworkStorageId.account);
  }

  Future<void> removeAccount(Chain chain) async {
    await removeNetworkStorage();
  }

  Future<bool> insertNetworkAddresses(
      {StorageId storage = DefaultNetworkStorageId.address,
      List<BaseChainAccount> addresses = const []}) async {
    if (addresses.isEmpty) return false;
    final storages = addresses
        .map((e) => ITableInsertOrUpdateStructA(
            data: e.toCbor().encode(),
            storage: networkId,
            storageId: storage.storageId,
            tableName: tableId,
            key: e.identifier))
        .toList();
    final data = await insertStorages(storages);
    return data;
  }

  ///
}
