abstract interface class ClipboardSource {
  Future<String?> readText();
}
