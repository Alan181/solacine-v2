import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../app/i18n.dart';
import '../../../shared/data/package_info_provider.dart';
import '../../auth/application/auth_controller.dart';
import '../application/app_update_controller.dart';
import '../application/bootstrap_controller.dart';

class AppUpdateScreen extends ConsumerWidget {
  const AppUpdateScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = AppI18n.of(context);
    final bootstrap = ref.watch(appBootstrapProvider).valueOrNull;
    final packageInfo = ref.watch(packageInfoProvider).valueOrNull;
    final auth = ref.watch(authSessionProvider).valueOrNull;

    final general = (bootstrap?.appConfig.data['general'] as Map<String, dynamic>?) ?? const <String, dynamic>{};
    final apiVersionCodeStr = general['version_code']?.toString() ?? '1';
    final forceUpdate = general['force_update'] == true || general['force_update'] == 'true';
    final updateLink = (general['update_link']?.toString() ?? '').trim();

    final latestVersionCode = int.tryParse(apiVersionCodeStr) ?? 1;
    final currentVersionCode = int.tryParse(packageInfo?.buildNumber ?? '') ?? 1;

    final appVersionLabel = packageInfo == null
        ? '...'
        : '${packageInfo.version}+${packageInfo.buildNumber}';

    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: Colors.black,
        body: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 360),
                child: Container(
                  decoration: BoxDecoration(
                    color: const Color(0xff111111),
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.55),
                        blurRadius: 40,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(22, 18, 22, 22),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const SizedBox(height: 8),
                        const Icon(Icons.system_update_rounded, color: Colors.white, size: 56),
                        const SizedBox(height: 16),
                        Text(
                          t.t('update_available_title'),
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.5,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          forceUpdate ? t.t('update_force_body') : t.t('update_optional_body'),
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.65),
                            fontSize: 15,
                            height: 1.4,
                          ),
                        ),
                        const SizedBox(height: 14),
                        Text(
                          t.t(
                            'update_versions',
                            params: {
                              'current': '$currentVersionCode ($appVersionLabel)',
                              'latest': '$latestVersionCode',
                            },
                          ),
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.55),
                            fontSize: 12,
                            height: 1.35,
                          ),
                        ),
                        const SizedBox(height: 22),
                        SizedBox(
                          width: double.infinity,
                          height: 50,
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.white,
                              foregroundColor: Colors.black,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                              elevation: 0,
                            ),
                            onPressed: updateLink.isEmpty
                                ? null
                                : () async {
                                    final uri = Uri.tryParse(updateLink);
                                    if (uri == null) return;
                                    final okExternal = await launchUrl(uri, mode: LaunchMode.externalApplication);
                                    if (okExternal) return;

                                    final okInApp = await launchUrl(uri, mode: LaunchMode.inAppWebView);
                                    if (okInApp) return;

                                    if (context.mounted) {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(content: Text(t.t('update_open_failed'))),
                                      );
                                    }
                                  },
                            child: Text(
                              t.t('update_now'),
                              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                            ),
                          ),
                        ),
                        if (!forceUpdate) ...[
                          const SizedBox(height: 12),
                          SizedBox(
                            width: double.infinity,
                            height: 50,
                            child: OutlinedButton(
                              style: OutlinedButton.styleFrom(
                                foregroundColor: Colors.white,
                                side: BorderSide(color: Colors.white.withValues(alpha: 0.18)),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                              ),
                              onPressed: () {
                                if (ref.read(appUpdateDismissedProvider)) return;
                                ref.read(appUpdateDismissedProvider.notifier).state = true;

                                Future.microtask(() {
                                  if (!context.mounted) return;
                                  final signedIn = auth != null;
                                  context.go(signedIn ? '/home' : '/login');
                                });
                              },
                              child: Text(
                                t.t('continue'),
                                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                              ),
                            ),
                          ),
                        ],
                        if (forceUpdate) ...[
                          const SizedBox(height: 10),
                          Text(
                            t.t('update_force_hint'),
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.5),
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
