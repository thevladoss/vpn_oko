import 'package:vpn_osin/features/server_config/domain/repositories/clipboard_source.dart';

class FakeClipboardSource implements ClipboardSource {
  FakeClipboardSource({this.textToReturn, this.errorToThrow});

  String? textToReturn;
  Exception? errorToThrow;

  @override
  Future<String?> readText() async {
    final error = errorToThrow;
    if (error != null) {
      throw error;
    }
    return textToReturn;
  }
}
