import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:dio/dio.dart';
import '../../app/i18n.dart';
import '../auth/application/auth_controller.dart';
import '../auth/data/auth_api.dart';
import '../bootstrap/application/bootstrap_controller.dart';
import '../inbox/application/inbox_unread_count_provider.dart';
import '../localization/application/locale_controller.dart';
import '../../shared/widgets/app_bottom_nav_bar.dart';
import '../../shared/widgets/app_loading_indicator.dart';
import 'widgets/profile_app_bar_header.dart';
import 'widgets/profile_membership_vip_card.dart';
import 'widgets/profile_wallet_row.dart';
import 'widgets/profile_menu_tile.dart';
import 'widgets/profile_logout_button.dart';
import 'widgets/profile_language_sheet.dart';
import 'widgets/profile_settings_sheet.dart';
import 'widgets/profile_delete_account_dialog.dart';
import '../rewards/data/rewards_api.dart';

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  var _loggingOut = false;

  @override
  Widget build(BuildContext context) {
    final t = AppI18n.of(context);
    final session = ref.watch(authSessionProvider).valueOrNull;
    final unreadInbox = ref.watch(inboxUnreadCountProvider).valueOrNull ?? 0;
    final rewardsConfig = ref.watch(rewardsConfigProvider).valueOrNull;
    final availableRewardCoins = rewardsConfig?.availableCoins ??
        (session?.user?['available_rewards_coins'] as num?)?.toInt() ??
        RewardsConfigNotifier.cachedAvailableCoins;
    final rewardBadge = availableRewardCoins > 0 ? '+$availableRewardCoins' : null;
    final name = (session?.user?['name'] as String?) ?? '';
    final id = (session?.user?['id'] as num?)?.toInt() ?? 0;
    final coins = (session?.user?['coins_balance'] as num?)?.toInt() ??
        (session?.user?['coins'] as num?)?.toInt() ??
        0;
    final email = (session?.user?['email'] as String?) ?? '';
    final avatarUrl = (session?.user?['avatar_url'] as String?) ?? '';
    final authProvider = (session?.user?['auth_provider'] as String?) ?? '';
    final expiresRaw = (session?.user?['membership_expires_at'] as String?)?.trim();
    final expiresAt = _tryParseDateTime(expiresRaw)?.toLocal();
    final now = DateTime.now();
    final isVip = expiresAt != null && expiresAt.isAfter(now);
    final daysLeft = _daysLeftCeil(expiresAt, now);
    final expiresDateLabel = expiresAt != null ? _formatYmd(expiresAt) : '';
    final bootstrap = ref.watch(appBootstrapProvider).valueOrNull;
    final appName = (bootstrap?.publicSettings['app_name'] as String?) ?? t.t('app_name');
    final canPop = GoRouter.of(context).canPop();

    Future<void> onLogout() async {
      if (_loggingOut) return;
      setState(() => _loggingOut = true);
      final startedAt = DateTime.now();
      await Future<void>.delayed(const Duration(milliseconds: 180));
      try {
        await ref.read(authSessionProvider.notifier).logout();
      } finally {
        final elapsedMs = DateTime.now().difference(startedAt).inMilliseconds;
        final remain = 420 - elapsedMs;
        if (remain > 0) {
          await Future<void>.delayed(Duration(milliseconds: remain));
        }
        if (mounted) setState(() => _loggingOut = false);
      }
    }

    return PopScope(
      canPop: canPop,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        if (canPop) {
          context.pop();
          return;
        }
        context.go('/reels'); // Diubah dari /home ke /reels
      },
      child: Scaffold(
        backgroundColor: const Color(0xff050505),
        body: Stack(
          children: [
            SafeArea(
              child: Column(
                children: [
                  ProfileAppBarHeader(
                    displayName: name.isNotEmpty ? name : appName,
                    idLabel: id > 0 ? t.t('user_id', params: {'id': id.toString()}) : '',
                    emailLabel: email,
                    avatarUrl: avatarUrl,
                    authProvider: authProvider,
                    isVip: isVip,
                    onEdit: () => context.push('/account'),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 20, 14),
                    child: ProfileMembershipVipCard(
                      appName: appName,
                      isVip: isVip,
                      expiresDateLabel: expiresDateLabel,
                      daysLeft: daysLeft,
                      onActivate: () => context.push('/membership'),
                    ),
                  ),
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        color: const Color(0xff050505),
                        borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
                        border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
                      ),
                      child: ClipRRect(
                        borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
                        child: Material(
                          type: MaterialType.transparency,
                          child: Stack(
                            children: [
                              Align(
                                alignment: Alignment.topCenter,
                                child: Container(
                                  width: double.infinity,
                                  height: 160,
                                  decoration: const BoxDecoration(
                                    gradient: LinearGradient(
                                      begin: Alignment.topCenter,
                                      end: Alignment.bottomCenter,
                                      colors: [
                                        Color(0xff3f3b35),
                                        Color(0xff030303),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                              ListView(
                                padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                                children: [
                                  ProfileWalletRow(
                                    coins: coins,
                                    onRecharge: () => context.push('/recharge'),
                                  ),
                                  const SizedBox(height: 18),
                                  ProfileMenuTile(
                                    title: t.t('inbox'),
                                    iconAsset: 'assets/images/mine_icon_download.webp',
                                    showDot: unreadInbox > 0,
                                    onTap: () => context.push('/inbox'),
                                  ),
                                  ProfileMenuTile(
                                    title: t.t('devices'),
                                    iconAsset: 'assets/images/ng.webp',
                                    onTap: () => context.push('/devices'),
                                  ),
                                  ProfileMenuTile(
                                    title: t.t('purchase_history'),
                                    iconAsset: 'assets/images/mine_icon_medeem.webp',
                                    onTap: () => context.push('/purchase-history'),
                                  ),
                                  ProfileMenuTile(
                                    title: t.t('earn_rewards'),
                                    iconAsset: 'assets/images/mine_earn_rewards.png',
                                    badgeText: rewardBadge,
                                    onTap: () async {
                                      await context.push('/rewards');
                                      ref.read(rewardsConfigProvider.notifier).refresh();
                                    },
                                  ),
                                  ProfileMenuTile(
                                    title: t.t('support'),
                                    iconAsset: 'assets/images/mine_icon_insite_message.webp',
                                    onTap: () => context.push('/support'),
                                  ),
                                  ProfileMenuTile(
                                    title: t.t('language'),
                                    iconAsset: 'assets/images/mine_icon_language.webp',
                                    onTap: () => _showLanguageSheet(context, ref),
                                  ),
                                  ProfileMenuTile(
                                    title: t.t('settings'),
                                    iconAsset: 'assets/images/mine_icon_setting.webp',
                                    onTap: () => _showSettingsSheet(context, ref),
                                  ),
                                  const SizedBox(height: 16),
                                  ProfileLogoutButton(onLogout: onLogout),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            if (_loggingOut)
              Positioned.fill(
                child: Container(
                  color: Colors.black.withValues(alpha: 0.55),
                  alignment: Alignment.center,
                  child: const AppLoadingIndicator(radius: 14),
                ),
              ),
          ],
        ),
        bottomNavigationBar: const AppBottomNavBar(currentIndex: 3),
      ),
    );
  }
}

Future<void> _showLanguageSheet(BuildContext context, WidgetRef ref) async {
  final bootstrap = ref.read(appBootstrapProvider).valueOrNull;
  final languages = bootstrap?.languages ?? const [];
  if (languages.isEmpty) return;

  final currentCode = ref.read(appLocaleProvider).valueOrNull?.languageCode ?? bootstrap?.localeCode ?? '';

  final items = languages
      .map((dynamic l) => LanguageItem(code: l.code as String, name: l.name as String))
      .toList();

  await showModalBottomSheet<void>(
    context: context,
    backgroundColor: const Color(0xff0b0b0b),
    showDragHandle: true,
    builder: (context) {
      return ProfileLanguageSheet(
        languages: items,
        currentCode: currentCode,
        onLanguageSelected: (code) {
          ref.read(appLocaleProvider.notifier).setLocale(Locale(code));
        },
      );
    },
  );
}

Future<void> _showSettingsSheet(BuildContext context, WidgetRef ref) async {
  final rootContext = context;
  final t = AppI18n.of(context);
  final bootstrap = ref.read(appBootstrapProvider).valueOrNull;
  final general = (bootstrap?.appConfig.data['general'] as Map?)?.cast<String, dynamic>() ?? const <String, dynamic>{};
  final legal = (bootstrap?.publicSettings['legal'] as Map?)?.cast<String, dynamic>() ?? const <String, dynamic>{};

  final privacyUrl = ((general['privacy_policy_link'] as String?) ?? (legal['privacy_policy'] as String?) ?? '').trim();
  final termsUrl = ((general['terms_of_service_link'] as String?) ?? (legal['terms_of_service'] as String?) ?? '').trim();

  await showModalBottomSheet<void>(
    context: context,
    backgroundColor: const Color(0xff0b0b0b),
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(22))),
    showDragHandle: true,
    builder: (sheetContext) {
      return ProfileSettingsSheet(
        privacyUrl: privacyUrl,
        termsUrl: termsUrl,
        privacyTitle: t.t('privacy_policy'),
        termsTitle: t.t('terms_of_use'),
        deleteAccountTitle: t.t('delete_account'),
        onPrivacyTap: () => _openLegalPage(rootContext, title: t.t('privacy_policy'), url: privacyUrl),
        onTermsTap: () => _openLegalPage(rootContext, title: t.t('terms_of_use'), url: termsUrl),
        onDeleteAccountTap: () async => _confirmAndDeleteAccount(rootContext, ref),
      );
    },
  );
}

Future<void> _openLegalPage(BuildContext context, {required String title, required String url}) async {
  final t = AppI18n.of(context);
  final value = url.trim();
  if (value.isEmpty) return;
  final uri = Uri.tryParse(value);
  if (uri == null) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(t.t('unable_open_link'))));
    return;
  }

  final loc = Uri(
    path: '/legal',
    queryParameters: {
      'title': title,
      'url': uri.toString(),
    },
  ).toString();
  if (!context.mounted) return;
  context.push(loc);
}

Future<void> _confirmAndDeleteAccount(BuildContext context, WidgetRef ref) async {
  final t = AppI18n.of(context);
  final ok = await showDialog<bool>(
        context: context,
        builder: (context) {
          return ProfileDeleteAccountDialog(
            title: t.t('delete_account'),
            content: t.t('delete_account_confirm'),
            cancelText: t.t('cancel'),
            deleteText: t.t('delete'),
          );
        },
      ) ??
      false;

  if (!ok || !context.mounted) return;

  showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (context) {
      return const Center(
        child: AppLoadingIndicator(radius: 14),
      );
    },
  );

  try {
    await ref.read(authApiProvider).deleteAccount();

    if (!context.mounted) return;
    Navigator.of(context).pop();

    if (!context.mounted) return;
    context.go('/login');

    await ref.read(authSessionProvider.notifier).logout();
  } on DioException catch (e) {
    if (!context.mounted) return;
    Navigator.of(context).pop();

    final raw = e.response?.data;
    String? msg;
    if (raw is Map<String, dynamic>) {
      msg = (raw['message'] as String?)?.trim();
    }
    msg ??= (e.message ?? '').trim();
    if (msg.isEmpty) msg = null;
    if (msg != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
      return;
    }

    final detected = appUserErrorFor(e);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(t.t(detected.titleKey))),
    );
  } catch (e) {
    if (!context.mounted) return;
    Navigator.of(context).pop();

    final detected = appUserErrorFor(e);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(t.t(detected.titleKey))),
    );
  }
}

DateTime? _tryParseDateTime(String? raw) {
  if (raw == null) return null;
  final v = raw.trim();
  if (v.isEmpty) return null;
  return DateTime.tryParse(v);
}

int _daysLeftCeil(DateTime? expiresAt, DateTime now) {
  if (expiresAt == null) return 0;
  final diff = expiresAt.difference(now);
  final seconds = diff.inSeconds;
  if (seconds <= 0) return 0;
  return (seconds + 86399) ~/ 86400;
}

String _formatYmd(DateTime dt) {
  final y = dt.year.toString().padLeft(4, '0');
  final m = dt.month.toString().padLeft(2, '0');
  final d = dt.day.toString().padLeft(2, '0');
  return '$y-$m-$d';
}
