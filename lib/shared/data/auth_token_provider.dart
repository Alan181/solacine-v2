import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/auth/domain/auth_storage_keys.dart';
import 'secure_storage_provider.dart';

final authTokenProvider = FutureProvider<String?>((ref) async {
  final storage = ref.watch(secureStorageProvider);
  return storage.read(key: authTokenStorageKey);
});

