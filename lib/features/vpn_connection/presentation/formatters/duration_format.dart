String hhmmss(Duration duration) {
  final d = duration.isNegative ? Duration.zero : duration;
  String two(int n) => n.toString().padLeft(2, '0');
  final s = d.inSeconds % 60;
  if (d.inHours == 0) {
    return '${two(d.inMinutes)}:${two(s)}';
  }
  final m = d.inMinutes % 60;
  return '${two(d.inHours)}:${two(m)}:${two(s)}';
}
