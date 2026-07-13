(String value, String unit) formatBytesParts(int bytes) {
  const units = ['B', 'KB', 'MB', 'GB'];
  if (bytes < 1024) return ('$bytes', units[0]);
  var value = bytes.toDouble();
  var i = 0;
  while (value >= 1024 && i < units.length - 1) {
    value /= 1024;
    i++;
  }
  return (value.toStringAsFixed(1), units[i]);
}

String formatBytes(int bytes) {
  final (value, unit) = formatBytesParts(bytes);
  return '$value $unit';
}
