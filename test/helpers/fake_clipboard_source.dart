import 'package:vpn_oko/features/server_config/domain/repositories/clipboard_source.dart';

class FakeClipboardSource implements ClipboardSource {
  FakeClipboardSource({this.textToReturn});

  String? textToReturn;

  @override
  Future<String?> readText() async => textToReturn;
}
