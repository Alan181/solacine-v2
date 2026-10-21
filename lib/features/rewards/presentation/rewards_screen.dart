import 'dart:async';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:intl/intl.dart';
import '../../../app/i18n.dart';
import '../../ads/application/ads_initializer.dart';
import '../../ads/application/ads_providers.dart';
import '../../auth/application/auth_controller.dart';
import '../../auth/data/auth_api.dart';
import '../data/rewards_api.dart';
import 'widgets/rewards_app_bar_header.dart';
import 'widgets/rewards_coins_award_overlay.dart';
import 'widgets/rewards_daily_checkin_section.dart';
import 'widgets/rewards_loading_error_body.dart';
import 'widgets/rewards_tasks_list.dart';
import 'widgets/rewards_watch_ads_section.dart';

class RewardsScreen extends ConsumerStatefulWidget {
  const RewardsScreen({super.key});

  @override
  ConsumerState<RewardsScreen> createState() => _RewardsScreenState();
}

class _RewardsScreenState extends ConsumerState<RewardsScreen> with WidgetsBindingObserver {
  RewardsConfig? _config;
  Object? _error;
  bool _expanded = false;
  bool _loading = true;
  bool _refreshing = false;
  int? _pendingLinkTaskId;
  int? _countingDownTaskId;
  int _countdownSeconds = 0;
  DateTime? _countdownEndTime;
  Timer? _countdownTimer;
  final Set<int> _claimedTaskIds = <int>{};
  final Set<int> _loadingTaskIds = <int>{};
  bool _claimingCheckin = false;
  bool _claimingAds = false;

  void _markTaskLoading(int taskId, {required bool loading}) {
    if (!mounted) return;
    setState(() {
      if (loading) {
        _loadingTaskIds.add(taskId);
      } else {
        _loadingTaskIds.remove(taskId);
      }
    });
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    Future.microtask(() => _load(showLoader: true, refreshUser: false));
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _countdownTimer?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && _countingDownTaskId != null && _countdownEndTime != null) {
      final remaining = _countdownEndTime!.difference(DateTime.now()).inSeconds;
      if (remaining <= 0) {
        _countdownTimer?.cancel();
        setState(() {
          _pendingLinkTaskId = _countingDownTaskId;
          _countingDownTaskId = null;
          _countdownSeconds = 0;
          _countdownEndTime = null;
        });
      } else {
        setState(() {
          _countdownSeconds = remaining;
        });
      }
    }
  }

  Future<void> _load({required bool showLoader, required bool refreshUser}) async {
    final shouldShowLoader = showLoader || _config == null;
    setState(() {
      _error = null;
      _loading = shouldShowLoader;
      _refreshing = !shouldShowLoader;
    });

    try {
      final cfg = await ref.read(rewardsApiProvider).config();
      if (!mounted) return;
      setState(() => _config = cfg);

      if (refreshUser) {
        final fresh = await ref.read(authApiProvider).me();
        await ref.read(authSessionProvider.notifier).setUser(fresh);
      }
    } on DioException catch (e) {
      final code = e.response?.statusCode ?? 0;
      if (code == 401) {
        await ref.read(authSessionProvider.notifier).logout();
        return;
      }
      if (!mounted) return;
      setState(() => _error = e);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e);
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
          _refreshing = false;
        });
      }
    }
  }

  Future<void> _showAwardOverlay(int coins) async {
    if (!mounted || coins <= 0) return;
    try {
      await showGeneralDialog<void>(
        context: context,
        barrierDismissible: true,
        barrierLabel: 'Dismiss',
        barrierColor: Colors.black.withValues(alpha: 0.65),
        transitionDuration: const Duration(milliseconds: 250),
        pageBuilder: (context, animation, secondaryAnimation) {
          return RewardsCoinsAwardOverlay(coins: coins);
        },
      );
    } catch (e) {
      debugPrint('Award overlay display error: $e');
    }
  }

  Future<void> _claimCheckin() async {
    if (_claimingCheckin) return;
    setState(() => _claimingCheckin = true);
    final t = AppI18n.of(context);

    String message = '';
    int awarded = 0;
    try {
      final result = await ref.read(rewardsApiProvider).checkin();
      final fresh = await ref.read(authApiProvider).me();
      await ref.read(authSessionProvider.notifier).setUser(fresh);

      if (!mounted) return;
      awarded = (result['coins_awarded'] as num?)?.toInt() ?? 0;
      final cfg = _config;
      if (cfg != null && awarded > 0) {
        final updated = RewardsConfig(
          platform: cfg.platform,
          enabled: cfg.enabled,
          checkinSchedule: cfg.checkinSchedule,
          tasks: cfg.tasks,
          availableCoins: (cfg.availableCoins - awarded).clamp(0, 99999999),
        );
        _config = updated;
        ref.read(rewardsConfigProvider.notifier).updateConfig(updated);
      } else {
        ref.read(rewardsConfigProvider.notifier).refresh();
      }
    } on DioException catch (e) {
      final code = e.response?.statusCode ?? 0;
      message = _messageFromDio(e);
      if (code == 401) {
        await ref.read(authSessionProvider.notifier).logout();
        return;
      }
      if (code == 403 && message.toLowerCase().contains('banned')) {
        await ref.read(authSessionProvider.notifier).logout();
        return;
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message.isNotEmpty ? message : t.t('request_failed'))),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(t.t('request_failed'))),
      );
    } finally {
      if (mounted) {
        setState(() => _claimingCheckin = false);
      }
    }

    if (awarded > 0) {
      await _showAwardOverlay(awarded);
    }
  }

  Future<void> _startLinkTask(RewardTask task) async {
    final t = AppI18n.of(context);
    final url = task.targetUrl.trim();
    if (url.isEmpty) return;

    final ok = await showDialog<bool>(
          context: context,
          barrierDismissible: true,
          builder: (context) {
            return AlertDialog(
              backgroundColor: const Color(0xff0b0b0b),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: Text(
                t.t('task_follow_instruction'),
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.92),
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
              content: Text(
                t.t('task_browse_15s_then_return'),
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.70),
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  height: 1.35,
                ),
              ),
              actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
              actions: [
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.of(context).pop(false),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.white.withValues(alpha: 0.85),
                          side: BorderSide(color: Colors.white.withValues(alpha: 0.12)),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        ),
                        child: Text(t.t('cancel')),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: FilledButton(
                        onPressed: () => Navigator.of(context).pop(true),
                        style: FilledButton.styleFrom(
                          backgroundColor: const Color(0xfff43f5e),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          textStyle: const TextStyle(fontWeight: FontWeight.w500),
                        ),
                        child: Text(t.t('continue')),
                      ),
                    ),
                  ],
                ),
              ],
            );
          },
        ) ??
        false;

    if (!ok) return;

    final uri = Uri.tryParse(url);
    if (uri == null) return;
    final didLaunch = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!didLaunch && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(t.t('unable_open_link'))),
      );
      return;
    }

    if (!mounted) return;
    _countdownTimer?.cancel();
    _countingDownTaskId = task.id;
    _pendingLinkTaskId = null;
    _countdownSeconds = 15;
    _countdownEndTime = DateTime.now().add(const Duration(seconds: 15));
    setState(() {});

    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      final remaining = _countdownEndTime != null
          ? _countdownEndTime!.difference(DateTime.now()).inSeconds
          : _countdownSeconds - 1;

      if (remaining <= 0) {
        timer.cancel();
        setState(() {
          _pendingLinkTaskId = task.id;
          _countingDownTaskId = null;
          _countdownSeconds = 0;
          _countdownEndTime = null;
        });
      } else {
        setState(() {
          _countdownSeconds = remaining;
        });
      }
    });
  }

  Future<void> _claimLinkTask(RewardTask task) async {
    if (_loadingTaskIds.contains(task.id)) return;
    final t = AppI18n.of(context);

    // Deteksi apakah ini misi drama atau task biasa yang tidak butuh pending link 15 detik
    final dramaRegExp = RegExp(r'tonton.*?(\d+)', caseSensitive: false);
    final isDrama = task.type == 'drama' || dramaRegExp.hasMatch(task.title);

    // Jika bukan drama dan pending link task belum selesai, abaikan
    if (!isDrama && _pendingLinkTaskId != task.id) return;

    _markTaskLoading(task.id, loading: true);
    int awarded = 0;
    try {
      final res = await ref.read(rewardsApiProvider).claimTask(taskId: task.id);
      awarded = (res['coins_awarded'] as num?)?.toInt() ?? task.rewardCoins;
      final fresh = await ref.read(authApiProvider).me();
      await ref.read(authSessionProvider.notifier).setUser(fresh);

      if (!mounted) return;
      _claimedTaskIds.add(task.id);
      if (_pendingLinkTaskId == task.id) {
        _pendingLinkTaskId = null;
      }
      final cfg = _config;
      if (cfg != null) {
        final updated = RewardsConfig(
          platform: cfg.platform,
          enabled: cfg.enabled,
          checkinSchedule: cfg.checkinSchedule,
          tasks: cfg.tasks.where((e) => e.id != task.id).toList(),
          availableCoins: (cfg.availableCoins - awarded).clamp(0, 99999999),
        );
        _config = updated;
        ref.read(rewardsConfigProvider.notifier).updateConfig(updated);
      } else {
        ref.read(rewardsConfigProvider.notifier).refresh();
      }
      setState(() {});
    } on DioException catch (e) {
      final code = e.response?.statusCode ?? 0;
      final msg = _messageFromDio(e);
      if (code == 401) {
        await ref.read(authSessionProvider.notifier).logout();
        return;
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(msg.isNotEmpty ? msg : t.t('request_failed'))),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(t.t('request_failed'))),
      );
    } finally {
      _markTaskLoading(task.id, loading: false);
    }

    if (awarded > 0) {
      await _showAwardOverlay(awarded);
    }
  }

  Future<void> _claimAdTask(RewardTask task) async {
    if (_claimingAds) return;
    final t = AppI18n.of(context);

    final isVip = ref.read(isVipProvider);
    if (isVip) return;

    final cfg = ref.read(adsConfigProvider);
    final adType = cfg?.monetization.appAdType ?? 'rewarded';
    final service = ref.read(adsServiceProvider);
    if (cfg == null || !cfg.monetization.appAdsEnabled || !service.adsEnabled(cfg)) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(t.t('request_failed'))));
      }
      return;
    }

    setState(() => _claimingAds = true);
    int awarded = 0;
    try {
      await service.ensureInitialized(cfg);

      final completed = adType == 'interstitial'
          ? await service.showInterstitial()
          : await service.showRewarded(onEarnedReward: () {}, requireEarnedReward: true);
      if (!completed) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(t.t('ad_not_completed'))));
        }
        return;
      }

      final res = await ref.read(rewardsApiProvider).claimTask(taskId: task.id);
      awarded = (res['coins_awarded'] as num?)?.toInt() ?? task.rewardCoins;
      final fresh = await ref.read(authApiProvider).me();
      await ref.read(authSessionProvider.notifier).setUser(fresh);

      if (!mounted) return;
      _claimedTaskIds.add(task.id);
      final cfgLocal = _config;
      if (cfgLocal != null) {
        final updated = RewardsConfig(
          platform: cfgLocal.platform,
          enabled: cfgLocal.enabled,
          checkinSchedule: cfgLocal.checkinSchedule,
          tasks: cfgLocal.tasks.where((e) => e.id != task.id).toList(),
          availableCoins: (cfgLocal.availableCoins - awarded).clamp(0, 99999999),
        );
        _config = updated;
        ref.read(rewardsConfigProvider.notifier).updateConfig(updated);
      } else {
        ref.read(rewardsConfigProvider.notifier).refresh();
      }
      setState(() {});
    } on DioException catch (e) {
      final code = e.response?.statusCode ?? 0;
      final msg = _messageFromDio(e);
      if (code == 401) {
        await ref.read(authSessionProvider.notifier).logout();
        return;
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(msg.isNotEmpty ? msg : t.t('request_failed'))),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(t.t('request_failed'))),
      );
    } finally {
      if (mounted) {
        setState(() => _claimingAds = false);
      }
    }

    if (awarded > 0) {
      await _showAwardOverlay(awarded);
    }
  }

  Future<void> _openUrl(String value) async {
    final t = AppI18n.of(context);
    final uri = Uri.tryParse(value.trim());
    if (uri == null) return;
    final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!ok && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(t.t('unable_open_link'))),
      );
    }
  }

  String _messageFromDio(DioException e) {
    final data = e.response?.data;
    if (data is Map) {
      final msg = data['message'];
      if (msg is String && msg.trim().isNotEmpty) return msg.trim();
    }
    if (data is String && data.trim().isNotEmpty) return data.trim();
    return '';
  }

  String _dateOnly(String raw) {
    final v = raw.trim();
    if (v.isEmpty) return '';
    final m = RegExp(r'^\d{4}-\d{2}-\d{2}').firstMatch(v);
    if (m != null) return m.group(0) ?? '';
    final dt = DateTime.tryParse(v);
    if (dt != null) {
      return dt.toLocal().toIso8601String().split('T').first;
    }
    final parts = v.split(RegExp(r'\s+'));
    return parts.isNotEmpty ? parts.first : v;
  }

  @override
  Widget build(BuildContext context) {
    final t = AppI18n.of(context);
    final session = ref.watch(authSessionProvider).valueOrNull;
    final isVip = ref.watch(isVipProvider);
    final coins = (session?.user?['coins_balance'] as num?)?.toInt() ??
        (session?.user?['coins'] as num?)?.toInt() ??
        0;
    final lastCheckin = _dateOnly((session?.user?['last_checkin_date'] as String?) ?? '');
    final streak = (session?.user?['checkin_streak'] as num?)?.toInt() ?? 0;
    final todayLocal = DateTime.now().toIso8601String().split('T').first;
    final todayUtc = DateTime.now().toUtc().toIso8601String().split('T').first;
    final claimedToday = lastCheckin == todayLocal || lastCheckin == todayUtc;

    final cfg = _config;
    final schedule = cfg?.checkinSchedule ?? const <int>[];
    final tasks = cfg?.tasks ?? const <RewardTask>[];

    final adTasks = tasks.where((e) => e.type == 'ad').toList();
    final otherTasks = tasks.where((e) => e.type != 'ad').toList();
    final dayIndex = _dayIndexForUi(
      streak: streak,
      claimedToday: claimedToday,
      daysCount: (schedule.isNotEmpty ? schedule.length : 7).clamp(1, 7),
    );
    final todayReward = (schedule.isNotEmpty && dayIndex >= 1 && dayIndex <= schedule.length)
        ? schedule[dayIndex - 1]
        : 20;

    void goBack() {
      if (context.canPop()) {
        context.pop();
      } else {
        context.go('/profile');
      }
    }

    return PopScope(
      canPop: context.canPop(),
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        goBack();
      },
      child: Scaffold(
        backgroundColor: const Color(0xff050505),
        body: Stack(
          children: [
            Align(
              alignment: Alignment.topCenter,
              child: Opacity(
                opacity: 0.18,
                child: Image.asset(
                  'assets/images/icon_subscribe_iaa_bg.png',
                  width: double.infinity,
                  height: 240,
                  fit: BoxFit.cover,
                  alignment: Alignment.topCenter,
                  filterQuality: FilterQuality.low,
                ),
              ),
            ),
            SafeArea(
              child: Column(
                children: [
                  RewardsAppBarHeader(
                    coins: coins,
                    onBackPressed: goBack,
                  ),
                  if (_refreshing)
                    const SizedBox(
                      height: 2,
                      child: LinearProgressIndicator(
                        color: Colors.white,
                        backgroundColor: Colors.transparent,
                      ),
                    ),
                  Expanded(
                    child: (_config == null && _loading)
                        ? RewardsLoadingErrorBody(
                            loading: _loading,
                            configLoaded: _config != null,
                            error: _error,
                            onRetry: () => _load(showLoader: true, refreshUser: true),
                          )
                        : RefreshIndicator(
                            onRefresh: () => _load(showLoader: false, refreshUser: true),
                            color: Colors.white,
                            backgroundColor: const Color(0xff0b0b0b),
                            child: ListView(
                              physics: const AlwaysScrollableScrollPhysics(),
                              padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                              children: [
                                if (_error != null)
                                  RewardsLoadingErrorBody(
                                    loading: _loading,
                                    configLoaded: _config != null,
                                    error: _error,
                                    onRetry: () => _load(showLoader: true, refreshUser: true),
                                  ),
                                _buildTopBannerCard(context),
                                const SizedBox(height: 12),
                                _buildSummaryCards(
                                  context: context,
                                  coins: coins,
                                  streak: streak,
                                  todayReward: todayReward,
                                  claimedToday: claimedToday,
                                ),
                                const SizedBox(height: 14),
                                RewardsDailyCheckinSection(
                                  schedule: schedule,
                                  dayIndex: dayIndex,
                                  claimedToday: claimedToday,
                                  loading: _claimingCheckin,
                                  onClaim: claimedToday ? null : _claimCheckin,
                                ),
                                const SizedBox(height: 14),
                                if (!isVip && adTasks.isNotEmpty)
                                  Padding(
                                    padding: const EdgeInsets.only(bottom: 14),
                                    child: RewardsWatchAdsSection(
                                      title: t.t('watch_ads'),
                                      tasks: adTasks,
                                      loading: _claimingAds,
                                      onTap: adTasks.isEmpty ? null : () => _claimAdTask(adTasks.first),
                                    ),
                                  ),
                                RewardsTasksList(
                                  tasks: otherTasks,
                                  claimedTaskIds: _claimedTaskIds,
                                  loadingTaskIds: _loadingTaskIds,
                                  pendingLinkTaskId: _pendingLinkTaskId,
                                  countingDownTaskId: _countingDownTaskId,
                                  countdownSeconds: _countdownSeconds,
                                  expanded: _expanded,
                                  onToggleExpanded: () => setState(() => _expanded = !_expanded),
                                  onStartLinkTask: _startLinkTask,
                                  onClaimLinkTask: _claimLinkTask,
                                  onOpenUrl: _openUrl,
                                  adsTasks: adTasks,
                                  isVip: isVip,
                                ),
                              ],
                            ),
                          ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTopBannerCard(BuildContext context) {
    final t = AppI18n.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xff09090b),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xff18181b)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: const Color(0xff121215),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xff1f1f25)),
            ),
            child: const Icon(
              Icons.card_giftcard_rounded,
              color: Colors.white,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  t.t('reward_center'),
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.95),
                    fontSize: 14.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  t.t('reward_center_desc'),
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.50),
                    fontSize: 11,
                    height: 1.3,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          SizedBox(
            height: 32,
            child: FilledButton.icon(
              onPressed: () => context.push('/recharge'),
              icon: const Icon(Icons.account_balance_wallet_rounded, size: 13),
              label: Text(t.t('top_up_coins')),
              style: FilledButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: const Color(0xff09090b),
                padding: const EdgeInsets.symmetric(horizontal: 10),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(9)),
                textStyle: const TextStyle(fontWeight: FontWeight.w800, fontSize: 11),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryCards({
    required BuildContext context,
    required int coins,
    required int streak,
    required int todayReward,
    required bool claimedToday,
  }) {
    final t = AppI18n.of(context);
    final formattedCoins = NumberFormat('#,###').format(coins);
    final streakDisplay = streak > 0 ? streak : 0;
    final dayLabel = streakDisplay == 1
        ? t.t('streak_day')
        : (t.t('streak_days').contains('{') ? 'Days' : t.t('streak_days'));

    return SizedBox(
      height: 104,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 1. My Coins Balance
          Expanded(
            child: Container(
              height: 104,
              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 10),
              decoration: BoxDecoration(
                color: const Color(0xff09090b),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xff18181b)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: FittedBox(
                              fit: BoxFit.scaleDown,
                              alignment: AlignmentDirectional.centerStart,
                              child: Text(
                                t.t('my_coins_balance'),
                                style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.45),
                                  fontSize: 8.5,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 0.1,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 4),
                          Container(
                            width: 18,
                            height: 18,
                            decoration: BoxDecoration(
                              color: const Color(0xff121215),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(color: const Color(0xff1f1f25)),
                            ),
                            child: Icon(
                              Icons.toll_rounded,
                              size: 10,
                              color: Colors.white.withValues(alpha: 0.70),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 7),
                      SizedBox(
                        height: 22,
                        child: Align(
                          alignment: AlignmentDirectional.centerStart,
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            alignment: AlignmentDirectional.centerStart,
                            child: Text(
                              formattedCoins,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.w800,
                                height: 1.0,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(
                    height: 25,
                    child: Align(
                      alignment: AlignmentDirectional.centerStart,
                      child: Text(
                        t.t('available_coins_desc'),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.45),
                          fontSize: 9.5,
                          height: 1.25,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 6),
          // 2. Active Streak
          Expanded(
            child: Container(
              height: 104,
              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 10),
              decoration: BoxDecoration(
                color: const Color(0xff09090b),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xff18181b)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: FittedBox(
                              fit: BoxFit.scaleDown,
                              alignment: AlignmentDirectional.centerStart,
                              child: Text(
                                t.t('active_streak'),
                                style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.45),
                                  fontSize: 8.5,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 0.1,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 4),
                          Container(
                            width: 18,
                            height: 18,
                            decoration: BoxDecoration(
                              color: const Color(0xff121215),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(color: const Color(0xff1f1f25)),
                            ),
                            child: const Icon(
                              Icons.local_fire_department_rounded,
                              size: 11,
                              color: Color(0xfffb923c),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 7),
                      SizedBox(
                        height: 22,
                        child: Align(
                          alignment: AlignmentDirectional.centerStart,
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            alignment: AlignmentDirectional.centerStart,
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.baseline,
                              textBaseline: TextBaseline.alphabetic,
                              children: [
                                Text(
                                  '$streakDisplay',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 18,
                                    fontWeight: FontWeight.w800,
                                    height: 1.0,
                                  ),
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  dayLabel,
                                  style: TextStyle(
                                    color: Colors.white.withValues(alpha: 0.55),
                                    fontSize: 10.5,
                                    fontWeight: FontWeight.w600,
                                    height: 1.0,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(
                    height: 25,
                    child: Align(
                      alignment: AlignmentDirectional.centerStart,
                      child: Text(
                        t.t('consecutive_checkins_desc'),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.45),
                          fontSize: 9.5,
                          height: 1.25,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 6),
          // 3. Today's Reward
          Expanded(
            child: Container(
              height: 104,
              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 10),
              decoration: BoxDecoration(
                color: const Color(0xff09090b),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xff18181b)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: FittedBox(
                              fit: BoxFit.scaleDown,
                              alignment: AlignmentDirectional.centerStart,
                              child: Text(
                                t.t('todays_reward'),
                                style: TextStyle(
                                  color: claimedToday ? const Color(0xff34d399) : Colors.white.withValues(alpha: 0.45),
                                  fontSize: 8.5,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 0.1,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 4),
                          Container(
                            width: 18,
                            height: 18,
                            decoration: BoxDecoration(
                              color: claimedToday
                                  ? const Color(0xff10b981).withValues(alpha: 0.15)
                                  : const Color(0xff121215),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(
                                color: claimedToday
                                    ? const Color(0xff10b981).withValues(alpha: 0.25)
                                    : const Color(0xff1f1f25),
                              ),
                            ),
                            child: Icon(
                              claimedToday ? Icons.check_rounded : Icons.auto_awesome_rounded,
                              size: 10,
                              color: claimedToday ? const Color(0xff34d399) : Colors.white.withValues(alpha: 0.70),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 7),
                      SizedBox(
                        height: 22,
                        child: Align(
                          alignment: AlignmentDirectional.centerStart,
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            alignment: AlignmentDirectional.centerStart,
                            child: Text(
                              '+$todayReward',
                              style: TextStyle(
                                color: claimedToday ? const Color(0xff34d399) : Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.w800,
                                height: 1.0,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(
                    height: 25,
                    child: Align(
                      alignment: AlignmentDirectional.centerStart,
                      child: Text(
                        claimedToday ? t.t('claimed_for_today') : t.t('ready_to_claim_now'),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.45),
                          fontSize: 9.5,
                          height: 1.25,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

int _dayIndexForUi({required int streak, required bool claimedToday, required int daysCount}) {
  final maxDays = daysCount.clamp(1, 7);
  final s = streak < 0 ? 0 : streak;

  final lastClaimedDay = s <= 0 ? 1 : (((s - 1) % maxDays) + 1);
  if (claimedToday) return lastClaimedDay;

  final nextClaimDay = ((s % maxDays) + 1);
  return nextClaimDay;
}
