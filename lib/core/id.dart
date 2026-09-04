String createId(String prefix) {
  final now = DateTime.now().microsecondsSinceEpoch;
  return '$prefix-$now';
}
