import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/application/auth_controller.dart';
import '../../bootstrap/application/bootstrap_controller.dart';
import '../data/ads_config.dart';

final adsConfigProvider = Provider<AdsConfig?>((ref) {
  final bootstrap = ref.watch(appBootstrapProvider);
  return bootstrap.maybeWhen(
    data: (d) => AdsConfig.fromAppConfig(d.appConfig.data, publicSettings: d.publicSettings),
    orElse: () => null,
  );
});

final isVipProvider = Provider<bool>((ref) {
  final session = ref.watch(authSessionProvider).valueOrNull;
  final expiresRaw = (session?.user?['membership_expires_at'] as String?)?.trim();
  final expiresAt = (expiresRaw == null || expiresRaw.isEmpty) ? null : DateTime.tryParse(expiresRaw)?.toLocal();
  return expiresAt != null && expiresAt.isAfter(DateTime.now());
});

