bool isLikelyEmail(String input) {
  final v = input.trim();
  if (v.isEmpty) return false;
  final at = v.indexOf('@');
  if (at <= 0) return false;
  if (at != v.lastIndexOf('@')) return false;
  final domain = v.substring(at + 1);
  if (domain.isEmpty) return false;
  if (!domain.contains('.')) return false;
  if (domain.startsWith('.') || domain.endsWith('.')) return false;
  if (v.contains(' ')) return false;
  return true;
}

