import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../application/ads_providers.dart';
import 'ads_service.dart';

final adsServiceProvider = Provider<AdsService>((ref) => AdsService());

class AdsInitializer extends ConsumerStatefulWidget {
  const AdsInitializer({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<AdsInitializer> createState() => _AdsInitializerState();
}

class _AdsInitializerState extends ConsumerState<AdsInitializer> {
  @override
  void initState() {
    super.initState();
    ref.listenManual(adsConfigProvider, (prev, next) => _maybeInit());
    ref.listenManual(isVipProvider, (prev, next) => _maybeInit());
    Future.microtask(_maybeInit);
  }

  Future<void> _maybeInit() async {
    if (!mounted) return;
    if (kIsWeb) return;
    final cfg = ref.read(adsConfigProvider);
    if (cfg == null) return;
    final isVip = ref.read(isVipProvider);
    if (isVip) return;
    if (!ref.read(adsServiceProvider).adsEnabled(cfg)) return;
    await ref.read(adsServiceProvider).ensureInitialized(cfg);
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
