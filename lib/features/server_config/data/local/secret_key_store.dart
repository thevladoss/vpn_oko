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

  static const String _dbKeyName = 'oko_db_key';

  final SecretStore _store;

  Future<String> getOrCreateKey() async {
    throw UnimplementedError();
  }
}
