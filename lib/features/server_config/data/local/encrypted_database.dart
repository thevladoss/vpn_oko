import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:vpn_oko/features/server_config/data/local/app_database.dart';
import 'package:vpn_oko/features/server_config/data/local/secret_key_store.dart';

const String _databaseFileName = 'oko_servers.db';

AppDatabase openEncryptedDatabase(SecretKeyStore keyStore) {
  return AppDatabase(_encryptedExecutor(keyStore));
}

LazyDatabase _encryptedExecutor(SecretKeyStore keyStore) {
  return LazyDatabase(() async {
    final dir = await getApplicationDocumentsDirectory();
    final file = File(p.join(dir.path, _databaseFileName));
    final key = await keyStore.getOrCreateKey();
    return NativeDatabase.createInBackground(
      file,
      setup: (rawDb) => rawDb.execute("PRAGMA key = '$key';"),
    );
  });
}
