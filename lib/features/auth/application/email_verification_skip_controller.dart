import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/data/shared_prefs_provider.dart';

class EmailVerificationSkipController extends AsyncNotifier<bool> {
  static const _key = 'skip_email_verification';

  @override
  Future<bool> build() async {
    final prefs = await ref.watch(sharedPrefsProvider.future);
    return prefs.getBool(_key) ?? false;
  }

  Future<void> setSkipped(bool skipped) async {
    final prefs = await ref.read(sharedPrefsProvider.future);
    await prefs.setBool(_key, skipped);
    state = AsyncData(skipped);
  }
}

final skipEmailVerificationProvider = AsyncNotifierProvider<EmailVerificationSkipController, bool>(
  EmailVerificationSkipController.new,
);

