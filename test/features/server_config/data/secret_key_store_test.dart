import 'package:flutter_test/flutter_test.dart';
import 'package:vpn_oko/features/server_config/data/local/secret_key_store.dart';

class _InMemorySecretStore implements SecretStore {
  final Map<String, String> _data = {};

  int writeCount = 0;

  @override
  Future<String?> read(String key) async => _data[key];

  @override
  Future<void> write(String key, String value) async {
    writeCount++;
    _data[key] = value;
  }
}

void main() {
  final hex64 = RegExp(r'^[0-9a-f]{64}$');

  test('generates a 64-char hex key and persists it on the empty store',
      () async {
    final store = _InMemorySecretStore();
    final sut = SecretKeyStore(store);

    final key = await sut.getOrCreateKey();

    expect(key.length, 64);
    expect(hex64.hasMatch(key), isTrue);
    expect(store.writeCount, 1);
  });

  test('returns the same key without regenerating on repeat calls', () async {
    final store = _InMemorySecretStore();
    final sut = SecretKeyStore(store);

    final first = await sut.getOrCreateKey();
    final second = await sut.getOrCreateKey();

    expect(second, first);
    expect(store.writeCount, 1);
  });

  test('reuses the stored key across new instances without a new write',
      () async {
    final store = _InMemorySecretStore();

    final first = await SecretKeyStore(store).getOrCreateKey();
    final reopened = await SecretKeyStore(store).getOrCreateKey();

    expect(reopened, first);
    expect(store.writeCount, 1);
  });

  test('produces different keys across independent stores', () async {
    final a = await SecretKeyStore(_InMemorySecretStore()).getOrCreateKey();
    final b = await SecretKeyStore(_InMemorySecretStore()).getOrCreateKey();

    expect(a, isNot(b));
  });
}
