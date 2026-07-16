import 'dart:math';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

abstract interface class SecretStore {
  Future<String?> read(String key);

  Future<void> write(String key, String value);
}

class FlutterSecretStore implements SecretStore {
  const FlutterSecretStore(this._storage);

  final FlutterSecureStorage _storage;

  @override
  Future<String?> read(String key) => _storage.read(key: key);

  @override
  Future<void> write(String key, String value) =>
      _storage.write(key: key, value: value);
}

class SecretKeyStore {
  const SecretKeyStore(this._store);

  static const String _dbKeyName = 'osin_db_key';

  final SecretStore _store;

  Future<String> getOrCreateKey() async {
    final existing = await _store.read(_dbKeyName);
    if (existing != null && existing.isNotEmpty) {
      return existing;
    }
    final key = _generateKey();
    await _store.write(_dbKeyName, key);
    return key;
  }

  String _generateKey() {
    final random = Random.secure();
    final bytes = List<int>.generate(32, (_) => random.nextInt(256));
    return bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  }
}
