import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../shared/widgets/active_shell_branch_scope.dart';
import 'i18n.dart';
import '../features/bootstrap/application/bootstrap_controller.dart';
import '../features/bootstrap/application/app_update_controller.dart';
import '../features/bootstrap/presentation/app_update_screen.dart';
import '../features/auth/application/auth_controller.dart';
import '../features/auth/application/email_verification_skip_controller.dart';
import '../features/auth/presentation/email_verification_screen.dart';
import '../features/auth/presentation/login_screen.dart';
import '../features/auth/presentation/register_screen.dart';
import '../features/auth/presentation/two_factor_verify_screen.dart';
import '../features/home/home_screen.dart';
import '../features/profile/profile_screen.dart';
import '../features/profile/presentation/account_screen.dart';
import '../features/profile/presentation/legal_webview_screen.dart';
import '../features/profile/presentation/two_factor_screen.dart';
import '../features/profile/presentation/update_password_screen.dart';
import '../features/rewards/presentation/rewards_screen.dart';
import '../features/genres/presentation/genres_screen.dart';
import '../features/genres/presentation/genre_series_screen.dart';
import '../features/my_list/presentation/my_list_screen.dart';
import '../features/recommendations/presentation/reels_screen.dart';
import '../features/search/presentation/search_screen.dart';
import '../features/splash/splash_screen.dart';
import '../features/support/presentation/support_ticket_screen.dart';
import '../features/support/presentation/support_tickets_screen.dart';
import '../features/inbox/presentation/inbox_screen.dart';
import '../features/devices/presentation/devices_screen.dart';
import '../features/watch/presentation/watch_screen.dart';

// --- IMPOR WALLET YANG SUDAH DISESUAIKAN JALURNYA ---
import '../features/wallet/presentation/coins_recharge_screen.dart';
import '../features/wallet/presentation/vip_membership_screen.dart';
import '../features/wallet/presentation/purchase_history_screen.dart';
import '../features/wallet/presentation/payment_return_screen.dart';

import '../shared/data/package_info_provider.dart';

final rootNavigatorKey = GlobalKey<NavigatorState>();
GoRouter? _previousRouter;

final appRouterProvider = Provider<GoRouter>((ref) {
  final auth = ref.watch(authSessionProvider);
  final bootstrap = ref.watch(appBootstrapProvider);
  final packageInfo = ref.watch(packageInfoProvider);
  final skipVerify = ref.watch(skipEmailVerificationProvider);

  final prevConfig = _previousRouter?.routerDelegate.currentConfiguration;
  final initialLoc = (prevConfig != null && prevConfig.isNotEmpty) 
      ? prevConfig.last.matchedLocation 
      : '/reels';

  final router = GoRouter(
    navigatorKey: rootNavigatorKey,
    initialLocation: initialLoc,
    routes: [
      GoRoute(
        path: '/',
        builder: (context, state) => const SplashScreen(),
      ),
      GoRoute(
        path: '/update',
        builder: (context, state) => const AppUpdateScreen(),
      ),
      GoRoute(
        path: '/verify-email',
        builder: (context, state) => const EmailVerificationScreen(),
      ),
      GoRoute(
        path: '/login',
        pageBuilder: (context, state) => const NoTransitionPage(
          child: LoginScreen(),
        ),
      ),
      GoRoute(
        path: '/register',
        pageBuilder: (context, state) => const NoTransitionPage(
          child: RegisterScreen(),
        ),
      ),
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) {
          return ActiveShellBranchScope(
            currentIndex: navigationShell.currentIndex,
            child: navigationShell,
          );
        },
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/home',
                pageBuilder: (context, state) => const NoTransitionPage(
                  child: HomeScreen(),
                ),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/reels',
                pageBuilder: (context, state) => const NoTransitionPage(
                  child: ReelsScreen(),
                ),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/my-list',
                pageBuilder: (context, state) => const NoTransitionPage(
                  child: MyListScreen(),
                ),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/profile',
                pageBuilder: (context, state) => const NoTransitionPage(
                  child: ProfileScreen(),
                ),
              ),
            ],
          ),
        ],
      ),
      GoRoute(
        path: '/account',
        pageBuilder: (context, state) => const NoTransitionPage(
          child: AccountScreen(),
        ),
      ),
      GoRoute(
        path: '/legal',
        pageBuilder: (context, state) {
          final qp = state.uri.queryParameters;
          final title = (qp['title'] ?? '').trim();
          final url = (qp['url'] ?? '').trim();
          return NoTransitionPage(
            child: LegalWebViewScreen(
              title: title,
              url: url,
            ),
          );
        },
      ),
      GoRoute(
        path: '/account/password',
        pageBuilder: (context, state) => const NoTransitionPage(
          child: UpdatePasswordScreen(),
        ),
      ),
      GoRoute(
        path: '/account/2fa',
        pageBuilder: (context, state) => const NoTransitionPage(
          child: TwoFactorScreen(),
        ),
      ),
      GoRoute(
        path: '/two-factor',
        pageBuilder: (context, state) {
          final qp = state.uri.queryParameters;
          final extra = state.extra;
          final map = extra is Map ? extra.cast<String, dynamic>() : <String, dynamic>{};

          final challengeToken = (qp['challenge_token'] ?? (map['challenge_token'] as String?) ?? '').trim();
          final email = (qp['email'] ?? (map['email'] as String?) ?? '').trim();
          return NoTransitionPage(
            child: TwoFactorVerifyScreen(
              challengeToken: challengeToken,
              email: email,
            ),
          );
        },
      ),
      GoRoute(
        path: '/support',
        pageBuilder: (context, state) => const NoTransitionPage(
          child: SupportTicketsScreen(),
        ),
        routes: [
          GoRoute(
            path: ':id',
            pageBuilder: (context, state) {
              final raw = state.pathParameters['id'] ?? '';
              final id = int.tryParse(raw) ?? 0;
              final subject = (state.extra is String) ? (state.extra as String) : '';
              return NoTransitionPage(
                child: SupportTicketScreen(id: id, subject: subject),
              );
            },
          ),
        ],
      ),
      GoRoute(
        path: '/inbox',
        pageBuilder: (context, state) => const NoTransitionPage(
          child: InboxScreen(),
        ),
      ),
      GoRoute(
        path: '/devices',
        pageBuilder: (context, state) => const NoTransitionPage(
          child: DevicesScreen(),
        ),
      ),
      GoRoute(
        path: '/wallet',
        pageBuilder: (context, state) {
          final tab = (state.uri.queryParameters['tab'] ?? '').trim().toLowerCase();
          if (tab == 'membership') {
            return const NoTransitionPage(
              child: VipMembershipScreen(),
            );
          }
          return const NoTransitionPage(
            child: CoinsRechargeScreen(),
          );
        },
      ),
      GoRoute(
        path: '/recharge',
        pageBuilder: (context, state) => const NoTransitionPage(
          child: CoinsRechargeScreen(),
        ),
      ),
      GoRoute(
        path: '/wallet/recharge',
        pageBuilder: (context, state) => const NoTransitionPage(
          child: CoinsRechargeScreen(),
        ),
      ),
      GoRoute(
        path: '/membership',
        pageBuilder: (context, state) => const NoTransitionPage(
          child: VipMembershipScreen(),
        ),
      ),
      GoRoute(
        path: '/wallet/membership',
        pageBuilder: (context, state) => const NoTransitionPage(
          child: VipMembershipScreen(),
        ),
      ),
      GoRoute(
        path: '/watch/:slug',
        pageBuilder: (context, state) {
          final slug = (state.pathParameters['slug'] ?? '').trim();
          final title = (state.uri.queryParameters['title'] ?? '').trim();
          final poster = (state.uri.queryParameters['poster'] ?? '').trim();
          final episode = int.tryParse((state.uri.queryParameters['episode'] ?? '').trim()) ?? 0;
          final fromReels = (state.uri.queryParameters['from'] ?? '').trim() == 'reels';
          return NoTransitionPage(
            child: WatchScreen(
              slug: slug,
              title: title.isEmpty ? null : title,
              posterUrl: poster.isEmpty ? null : poster,
              episodeNumber: episode > 0 ? episode : null,
              fromReels: fromReels,
            ),
          );
        },
      ),
      GoRoute(
        path: '/payment-return',
        pageBuilder: (context, state) {
          final qp = state.uri.queryParameters;
          final paymentOrderId = (qp['payment_order_id'] ?? '').trim();
          final provider = (qp['provider'] ?? '').trim();
          final status = (qp['status'] ?? '').trim();
          return NoTransitionPage(
            child: PaymentReturnScreen(
              paymentOrderId: paymentOrderId,
              provider: provider,
              status: status,
            ),
          );
        },
      ),
      GoRoute(
        path: '/purchase-history',
        pageBuilder: (context, state) => const NoTransitionPage(
          child: PurchaseHistoryScreen(),
        ),
      ),
      GoRoute(
        path: '/genres',
        pageBuilder: (context, state) => const NoTransitionPage(
          child: GenresScreen(),
        ),
      ),
      GoRoute(
        path: '/search',
        pageBuilder: (context, state) => const NoTransitionPage(
          child: SearchScreen(),
        ),
      ),
      GoRoute(
        path: '/rewards',
        pageBuilder: (context, state) => const NoTransitionPage(
          child: RewardsScreen(),
        ),
      ),
      GoRoute(
        path: '/genre/:slug',
        pageBuilder: (context, state) {
          final slug = state.pathParameters['slug'] ?? '';
          final title = state.uri.queryParameters['title'] ?? '';
          return NoTransitionPage(
            child: GenreSeriesScreen(
              slug: slug,
              title: Uri.decodeComponent(title),
            ),
          );
        },
      ),
    ],
    redirect: (context, state) {
      final loc = state.matchedLocation;
      final isAuthRoute = loc == '/login' || loc == '/register';
      final isVerifyRoute = loc == '/verify-email';
      final isUpdateRoute = loc == '/update';
      final isTwoFactorRoute = loc == '/two-factor';
      final isPaymentReturnRoute = loc == '/payment-return';
      final isLegalRoute = loc == '/legal';
      final isPayRoute = loc == '/pay';

      if (bootstrap.isLoading) {
        return (loc == '/' || isUpdateRoute || isLegalRoute || isPayRoute) ? null : '/';
      }

      if (bootstrap.hasError) {
        return (loc == '/' || isUpdateRoute || isLegalRoute || isPayRoute) ? null : '/';
      }

      if (packageInfo.isLoading) {
        return (loc == '/' || isUpdateRoute || isLegalRoute || isPayRoute) ? null : '/';
      }

      if (packageInfo.hasError) {
        return (loc == '/' || isUpdateRoute || isLegalRoute || isPayRoute) ? null : '/';
      }

      final general = (bootstrap.valueOrNull?.appConfig.data['general'] as Map<String, dynamic>?) ?? const <String, dynamic>{};
      final apiVersionCodeStr = general['version_code']?.toString() ?? '1';
      final forceUpdate = general['force_update'] == true || general['force_update'] == 'true';
      final latestVersionCode = int.tryParse(apiVersionCodeStr) ?? 1;
      final currentVersionCode = int.tryParse(packageInfo.valueOrNull?.buildNumber ?? '') ?? 1;

      final updateNeeded = latestVersionCode > currentVersionCode;
      final updateDismissedLive = ref.read(appUpdateDismissedProvider);
      final shouldBlockForUpdate = updateNeeded && (forceUpdate || !updateDismissedLive);
      if (shouldBlockForUpdate) {
        if (isUpdateRoute) return null;
        return '/update';
      }

      if (isUpdateRoute) {
        return null;
      }

      if (auth.isLoading) {
        if (loc == '/' || isAuthRoute || isVerifyRoute || isTwoFactorRoute || isPaymentReturnRoute || isLegalRoute || isPayRoute) {
          return null;
        }
        return '/';
      }

      final signedIn = auth.valueOrNull != null;

      if (!signedIn) {
        if (isAuthRoute || isTwoFactorRoute || isLegalRoute || isPayRoute) return null;
        return '/login';
      }

      final emailVerified = auth.valueOrNull?.user?['email_verified'] == true;
      final allowSkip = (bootstrap.valueOrNull?.publicSettings['auth'] is Map)
          ? ((bootstrap.valueOrNull?.publicSettings['auth'] as Map)['allow_email_verification_skip'] == true)
          : true;
      final skipped = allowSkip && skipVerify.valueOrNull == true;
      if (!emailVerified && !skipped && !isVerifyRoute) {
        return '/verify-email';
      }

      // Diperbarui agar saat baru login atau masuk ke root/home, langsung diarahkan ke reels
      if (signedIn && (loc == '/' || isAuthRoute || loc == '/home')) {
        return '/reels';
      }

      return null;
    },
    errorBuilder: (context, state) {
      final err = appUserErrorFor(state.error);
      final t = AppI18n.of(context);
      return Directionality(
        textDirection: Directionality.of(context),
        child: ColoredBox(
          color: const Color(0xFF050505),
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    t.t(err.titleKey),
                    style: const TextStyle(color: Color(0xFFE5E7EB), fontWeight: FontWeight.w700, fontSize: 18),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 10),
                  Text(
                    t.t(err.descKey),
                    style: const TextStyle(color: Color(0xFF9CA3AF), fontSize: 14),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    },
  );

  _previousRouter = router;
  return router;
});
