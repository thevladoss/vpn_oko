import 'package:flutter/services.dart';
import 'package:vpn_oko/features/server_config/domain/repositories/clipboard_source.dart';

class SystemClipboardSource implements ClipboardSource {
  const SystemClipboardSource();

  @override
  Future<String?> readText() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    return data?.text;
  }
}
