import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/application/auth_controller.dart';
import '../data/inbox_api.dart';

final inboxUnreadCountProvider = FutureProvider<int>((ref) async {
  final session = ref.watch(authSessionProvider).valueOrNull;
  if (session == null) return 0;
  return ref.read(inboxApiProvider).unreadCount();
});

