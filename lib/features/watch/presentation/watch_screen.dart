import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dio/dio.dart';
import 'package:go_router/go_router.dart';
import 'package:media_kit/media_kit.dart' as media_kit_pkg;
import 'package:media_kit_video/media_kit_video.dart' as media_kit_video;
import 'package:screen_security/screen_security.dart';
import 'package:solacine_mobile/shared/widgets/app_cached_image.dart';
import '../../../app/i18n.dart';
import '../../../shared/constants.dart';
import '../../../shared/data/shared_prefs_provider.dart';
import '../../auth/application/auth_controller.dart';
import '../../auth/data/auth_api.dart';
import '../../ads/application/ads_initializer.dart';
import '../../ads/application/ads_providers.dart';
import '../data/watch_api.dart';
import '../../recommendations/application/reels_preload_manager.dart';
import '../application/watch_episodes_preload_manager.dart';
import 'widgets/watch_loading_error_body.dart';
import 'widgets/watch_no_episodes_body.dart';
import 'widgets/watch_episode_page_item.dart';
import 'widgets/watch_episodes_sheet.dart';
import 'widgets/watch_more_item.dart';
import '../../ads/application/vast_ad_service.dart';
import 'widgets/watch_vast_ad_overlay.dart';

class WatchScreen extends ConsumerStatefulWidget {
  const WatchScreen({
    super.key,
    required this.slug,
    this.title,
    this.episodeNumber,
    this.reelsPreview = false,
    this.reelsBackdropUrl,
    this.posterUrl,
    this.isActive = true,
    this.fromReels = false,
  });

  final String slug;
  final String? title;
  final int? episodeNumber;
  final bool reelsPreview;
  final String? reelsBackdropUrl;
  final String? posterUrl;
  final bool isActive;
  final bool fromReels;

  @override
  ConsumerState<WatchScreen> createState() => _WatchScreenState();
}

class _WatchScreenState extends ConsumerState<WatchScreen> with TickerProviderStateMixin, WidgetsBindingObserver {
  final _screenSecurity = ScreenSecurity();

  var _loading = false; // Langsung false agar tidak memicu loading screen awal yang memunculkan layar hitam/putih
  Object? _error;
  WatchDataDto? _data;

  late PageController _pageController;
  var _index = 0;
  
  int? _lastProcessedEpisode;
  int _episodesSinceLastAd = 0;
  final int _adFrequencyInterval = 5;

  // MediaKit Controller & Preload Pool Instances
  media_kit_pkg.Player? _player;
  media_kit_video.VideoController? _videoController;
  
  // Preload player kedua khusus untuk menyiapkan episode berikutnya di background
  media_kit_pkg.Player? _preloadPlayer;
  String? _preloadedUrl;

  var _videoReady = false;
  var _videoOpId = 0;
  var _disposed = false;

  var _likesCount = 0;
  var _isLiked = false;
  late final AnimationController _likeBurst;
  var _likeBurstPos = Offset.zero;
  var _showLikeBurst = false;
  Offset? _lastDoubleTapLocalPos;
  var _playbackSpeed = 1.0;
  var _controlsVisible = true;
  var _controlsManuallyHidden = false;
  var _videoLoading = false;
  String? _videoError;
  String? _activeVideoUrl;
  final Map<int, String> _preferredUrlByEpisode = <int, String>{};
  final Map<int, String> _preferredQualityByEpisode = <int, String>{};
  var _unlocking = false;
  var _autoUnlockEnabled = false;
  final Set<int> _autoUnlockTriedEpisodes = <int>{};
  late final AnimationController _rewardShake;
  var _rewardDismissed = false;
  late final AnimationController _guideShake;
  var _showSwipeGuide = false;
  late final AnimationController _paywallAnim;
  final Set<int> _paywallShownEpisodes = <int>{};
  int? _restoreEpisodeNumber;
  var _exitInterstitialShowing = false;
  var _exitInterstitialBlockedUI = false;
  Timer? _exitBlockedUiTimer;
  var _fullScreenAdOpen = false;
  VastAdData? _activeVastAd;
  Completer<bool>? _vastRewardCompleter;
  int _vastEpisodePlayCounter = 0;
  Timer? _autoHideControlsTimer;

  var _episodesPerPage = 30;
  var _episodesTotal = 0;
  var _episodesPages = 0;
  final Map<int, WatchEpisodeDto> _episodesByNumber = <int, WatchEpisodeDto>{};
  final Set<int> _loadedPages = <int>{};
  var _loadingEpisodesPage = false;
  var _inModalSheet = false;
  var _isNavigatingRandom = false;

  @override
  void initState() {
    super.initState();
    _screenSecurity.enable();

    WidgetsBinding.instance.addObserver(this);
    if (widget.reelsPreview) {
      _episodesPerPage = 1;
    }
    _pageController = PageController();
    _likeBurst = AnimationController(vsync: this, duration: const Duration(milliseconds: 650));
    _likeBurst.addStatusListener((status) {
      if (status != AnimationStatus.completed) return;
      if (!mounted) return;
      setState(() => _showLikeBurst = false);
    });
    _rewardShake = AnimationController(vsync: this, duration: const Duration(milliseconds: 800))..repeat(reverse: true);
    _guideShake = AnimationController(vsync: this, duration: const Duration(milliseconds: 900))..repeat(reverse: true);
    _paywallAnim = AnimationController(vsync: this, duration: const Duration(milliseconds: 520));
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.manual, overlays: SystemUiOverlay.values);
    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: Colors.black,
        systemNavigationBarColor: Colors.black,
        statusBarIconBrightness: Brightness.light,
        systemNavigationBarIconBrightness: Brightness.light,
      ),
    );

    // ✨ OPTIMASI INSTAN: Ambil data dari cache memori seketika tanpa menunggu request jaringan ✨
    Future.microtask(() async {
      final prefs = await ref.read(sharedPrefsProvider.future);
      final enabled = prefs.getBool('watch_auto_unlock') ?? false;
      final seenGuide = prefs.getBool('watch_swipe_guide_seen') ?? false;
      final restoreSlug = prefs.getString('watch_restore_slug') ?? '';
      final restoreEp = prefs.getInt('watch_restore_episode') ?? 0;
      if (restoreSlug.trim().isNotEmpty && restoreSlug.trim() == widget.slug && restoreEp > 0) {
        await prefs.remove('watch_restore_slug');
        await prefs.remove('watch_restore_episode');
      }
      if (!mounted) return;
      setState(() {
        _autoUnlockEnabled = enabled;
        _showSwipeGuide = !seenGuide;
        _restoreEpisodeNumber = (restoreSlug.trim().isNotEmpty && restoreSlug.trim() == widget.slug && restoreEp > 0) ? restoreEp : null;
      });

      final initialEpisode = (widget.episodeNumber != null && (widget.episodeNumber ?? 0) > 0) ? widget.episodeNumber : (_restoreEpisodeNumber ?? 1);
      final cached = ReelsPreloadManager.getCachedData(widget.slug);

      if (cached != null) {
        _data = cached;
        _episodesTotal = cached.episodesTotal;
        _episodesPages = cached.episodesPages;
        _loadedPages.add(cached.episodesPage > 0 ? cached.episodesPage : 1);
        for (final e in cached.episodes) {
          _episodesByNumber[e.episodeNumber] = e;
        }

        final activeNum = initialEpisode!;
        final initial = widget.reelsPreview ? 0 : (_episodesTotal > 0 ? (activeNum - 1).clamp(0, _episodesTotal - 1) : 0);
        _lastProcessedEpisode = activeNum;

        if (mounted) {
          setState(() {
            _index = initial;
            _likesCount = cached.series.likesCount;
            _isLiked = cached.series.isLiked;
          });
        }

        await _startEpisodeNumber(activeNum);
      } else {
        await _load();
      }
    });
  }

  ({String titleKey, String descKey}) _errorMessageFor(Object? error) => appUserErrorFor(error);

  @override
  void dispose() {
    _screenSecurity.disable();
    WidgetsBinding.instance.removeObserver(this);
    _disposed = true;
    _videoOpId++;
    try {
      _player?.dispose();
    } catch (_) {}
    try {
      _preloadPlayer?.dispose();
    } catch (_) {}
    _player = null;
    _preloadPlayer = null;
    _videoController = null;
    _pageController.dispose();
    _likeBurst.dispose();
    _rewardShake.dispose();
    _guideShake.dispose();
    _paywallAnim.dispose();
    _autoHideControlsTimer?.cancel();
    if (_vastRewardCompleter != null && !_vastRewardCompleter!.isCompleted) {
      _vastRewardCompleter!.complete(false);
      _vastRewardCompleter = null;
    }
    _activeVastAd = null;
    WatchEpisodesPreloadManager.disposeAll();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.manual, overlays: SystemUiOverlay.values);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused || state == AppLifecycleState.inactive) {
      try {
        _player?.pause();
      } catch (_) {}
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_inModalSheet) return;
    final isCurrent = ModalRoute.of(context)?.isCurrent ?? true;
    if (!isCurrent) {
      try {
        _player?.pause();
      } catch (_) {}
    }
  }

  @override
  void didUpdateWidget(WatchScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.isActive && !widget.isActive) {
      try {
        _player?.pause();
      } catch (_) {}
    } else if (!oldWidget.isActive && widget.isActive) {
      try {
        _player?.play();
      } catch (_) {}
    }
  }

  void _cancelAutoHideControls() {
    _autoHideControlsTimer?.cancel();
    _autoHideControlsTimer = null;
  }

  void _scheduleAutoHideControls({Duration inFor = const Duration(seconds: 6)}) {
    if (widget.reelsPreview) return;
    if (_controlsManuallyHidden) return;
    _autoHideControlsTimer?.cancel();
    _autoHideControlsTimer = Timer(inFor, () {
      if (!mounted || _disposed) return;
      final p = _player;
      if (p != null && p.state.playing) return;
      _hideControls();
    });
  }

  void _showControls({bool scheduleAutoHide = true}) {
    if (!mounted) return;
    setState(() {
      _controlsVisible = true;
      _controlsManuallyHidden = false;
    });
    if (scheduleAutoHide) _scheduleAutoHideControls();
  }

  void _hideControls({bool manual = false}) {
    if (widget.reelsPreview) return;
    if (!mounted) return;
    _cancelAutoHideControls();
    setState(() {
      _controlsVisible = false;
      if (manual) _controlsManuallyHidden = true;
    });
  }

  void _toggleControls() {
    if (!mounted) return;
    if (_controlsVisible) {
      _hideControls(manual: true);
    } else {
      _showControls(scheduleAutoHide: true);
    }
  }

  void _onScreenTap() {
    final p = _player;
    if (p != null) {
      final isPlaying = p.state.playing;
      if (isPlaying) {
        p.pause();
        _showControls(scheduleAutoHide: false);
      } else {
        p.play();
        if (!widget.reelsPreview) {
          _scheduleAutoHideControls();
        }
      }
      setState(() {});
      return;
    }
    _toggleControls();
  }

  void _onCenterPlayPressed() {
    if (!mounted) return;
    final p = _player;
    if (p != null) {
      final isPlaying = p.state.playing;
      if (isPlaying) {
        p.pause();
        _showControls(scheduleAutoHide: false);
      } else {
        p.play();
        if (!widget.reelsPreview) {
          _scheduleAutoHideControls();
        }
      }
      setState(() {});
      return;
    }
    if (_controlsVisible) {
      _scheduleAutoHideControls();
    } else {
      _showControls(scheduleAutoHide: true);
    }
  }

  double _likeBurstScale(double t) {
    final a = Curves.easeOutCubic.transform((t / 0.45).clamp(0.0, 1.0));
    final b = Curves.easeInCubic.transform(((t - 0.45) / 0.55).clamp(0.0, 1.0));
    return 0.75 + (a * 0.95) - (b * 0.20);
  }

  double _likeBurstOpacity(double t) {
    if (t < 0.65) return 1.0;
    return (1.0 - ((t - 0.65) / 0.35)).clamp(0.0, 1.0);
  }

  void _ensurePaywallAnimStarted(int epNum) {
    if (!_paywallShownEpisodes.add(epNum)) return;
    if (_paywallAnim.status == AnimationStatus.completed ||
        _paywallAnim.status == AnimationStatus.forward) {
      return;
    }
    _paywallAnim.forward(from: 0);
  }

  Widget _buildPaywallPop({
    required int episodeNumber,
    required Widget child,
  }) {
    _ensurePaywallAnimStarted(episodeNumber);
    final Animation<double> fade = CurvedAnimation(
      parent: _paywallAnim,
      curve: const Interval(0.0, 0.65, curve: Curves.easeOut),
    );
    final Animation<double> scale = CurvedAnimation(
      parent: _paywallAnim,
      curve: const Interval(0.0, 0.80, curve: Curves.easeOutBack),
    );
    final Animation<double> slide = Tween<double>(begin: 24, end: 0).animate(
      CurvedAnimation(
        parent: _paywallAnim,
        curve: const Interval(0.0, 0.85, curve: Curves.easeOutCubic),
      ),
    );
    return AnimatedBuilder(
      animation: _paywallAnim,
      builder: (_, c) {
        final double animVal = fade.value.clamp(0.0, 1.0);
        return Stack(
          fit: StackFit.expand,
          children: [
            Opacity(
              opacity: animVal,
              child: ClipRect(
                child: BackdropFilter(
                  filter: ImageFilter.blur(
                    sigmaX: 18 * animVal,
                    sigmaY: 18 * animVal,
                  ),
                  child: Container(
                    color: Colors.black.withValues(alpha: 0.52 * animVal),
                  ),
                ),
              ),
            ),
            Opacity(
              opacity: animVal,
              child: Transform.translate(
                offset: Offset(0, slide.value),
                child: Transform.scale(
                  scale: 0.92 + 0.08 * scale.value,
                  alignment: Alignment.center,
                  child: c,
                ),
              ),
            ),
          ],
        );
      },
      child: child,
    );
  }

  void _onDoubleTapLike(Offset? localPos) {
    final p = localPos ?? _lastDoubleTapLocalPos ?? Offset.zero;
    setState(() {
      _likeBurstPos = p;
      _showLikeBurst = true;
    });
    _likeBurst.forward(from: 0);
    if (!_isLiked) {
      _toggleLike();
    }
  }

  int _episodeNumberForPageIndex(int i) {
    if (widget.reelsPreview) {
      final forced = widget.episodeNumber ?? 1;
      return forced > 0 ? forced : 1;
    }
    return i + 1;
  }

  int get _currentEpisodeNumber => _episodeNumberForPageIndex(_index);

  Future<void> _pauseVideoAndPush(String route) async {
    final p = _player;
    final bool wasPlaying;
    if (p != null) {
      wasPlaying = p.state.playing;
      if (wasPlaying) {
        p.pause();
        if (mounted) setState(() {});
      }
    } else {
      wasPlaying = false;
    }
    if (!mounted) return;
    await context.push(route);
    if (mounted && wasPlaying) {
      final currentP = _player;
      if (currentP != null && !currentP.state.playing) {
        try {
          currentP.play();
          if (mounted) setState(() {});
        } catch (_) {}
      }
    }
  }

  void _safePopOrHome() {
    try {
      _player?.pause();
    } catch (_) {}
    final router = GoRouter.of(context);
    if (widget.fromReels) {
      router.go('/reels');
      return;
    }
    if (router.canPop()) {
      router.pop();
      return;
    }
    router.go('/reels');
  }

  Future<void> _navigateToRandomSeries() async {
    if (_isNavigatingRandom) return;
    _isNavigatingRandom = true;

    try {
      try {
        _player?.pause();
        _player?.dispose();
      } catch (_) {}
      _player = null;
      _videoController = null;

      final randomData = await ref.read(watchApiProvider).getRandomSeries(currentSlug: widget.slug);
      
      if (randomData == null || randomData.slug.isEmpty) {
        _isNavigatingRandom = false;
        if (mounted) context.go('/reels');
        return;
      }

      final targetSlug = randomData.slug;
      final targetTitle = randomData.title;

      if (!mounted) return;
      final targetPath = '/watch/$targetSlug?title=${Uri.encodeComponent(targetTitle)}&from=reels';
      context.push(targetPath);
    } catch (e) {
      _isNavigatingRandom = false;
      if (mounted) {
        context.go('/reels');
      }
    }
  }

  Future<void> _showExitInterstitialAndLeave({required bool isVipUser}) async {
    try {
      _player?.pause();
    } catch (_) {}
    if (_fullScreenAdOpen) {
      _safePopOrHome();
      return;
    }
    if (_exitInterstitialShowing) return;

    _exitInterstitialShowing = true;
    if (mounted) setState(() {});

    _exitBlockedUiTimer?.cancel();
    _exitBlockedUiTimer = Timer(const Duration(milliseconds: 350), () {
      if (_exitInterstitialShowing && mounted) {
        setState(() => _exitInterstitialBlockedUI = true);
      }
    });

    final exitTimeoutTimer = Timer(const Duration(milliseconds: 1600), () {
      _exitBlockedUiTimer?.cancel();
      _exitInterstitialBlockedUI = false;
      if (_exitInterstitialShowing) {
        _exitInterstitialShowing = false;
        if (mounted) setState(() {});
        if (mounted) _safePopOrHome();
      }
    });

    try {
      if (!mounted) return;
      if (widget.reelsPreview || isVipUser) {
        exitTimeoutTimer.cancel();
        _exitBlockedUiTimer?.cancel();
        _exitInterstitialShowing = false;
        _exitInterstitialBlockedUI = false;
        if (mounted) setState(() {});
        _safePopOrHome();
        return;
      }

      final cfg = ref.read(adsConfigProvider);
      bool canShowAd = false;
      try {
        canShowAd = cfg != null && ref.read(adsServiceProvider).adsEnabled(cfg);
      } catch (_) {
        canShowAd = false;
      }

      if (canShowAd && cfg != null) {
        try {
          _player?.pause();
        } catch (_) {}
        try {
          final adsSvc = ref.read(adsServiceProvider);
          try {
            await Future<void>(() async {
              try {
                await adsSvc.ensureInitialized(cfg).timeout(const Duration(milliseconds: 900));
              } catch (_) {}
              try {
                await adsSvc.showInterstitial().timeout(const Duration(milliseconds: 1400));
              } catch (_) {}
            }).timeout(const Duration(milliseconds: 1500));
          } catch (_) {}
        } catch (_) {}
      }

      exitTimeoutTimer.cancel();
      _exitBlockedUiTimer?.cancel();
      _exitInterstitialShowing = false;
      _exitInterstitialBlockedUI = false;
      if (mounted) setState(() {});
      if (!mounted) return;
      _safePopOrHome();
    } finally {
      exitTimeoutTimer.cancel();
      _exitBlockedUiTimer?.cancel();
      _exitInterstitialBlockedUI = false;
      if (_exitInterstitialShowing) {
        _exitInterstitialShowing = false;
        if (mounted) setState(() {});
      }
    }
  }

  Future<void> _handleEpisodeChangeWithAds(int targetEpisodeNumber) async {
    if (widget.reelsPreview) return;
    
    if (_lastProcessedEpisode == targetEpisodeNumber) return;
    _lastProcessedEpisode = targetEpisodeNumber;

    final idx = targetEpisodeNumber - 1;
    if (mounted && _index != idx) {
      setState(() {
        _index = idx;
      });
    }

    final session = ref.read(authSessionProvider).valueOrNull;
    final expiresRaw = (session?.user?['membership_expires_at'] as String?)?.trim();
    final expiresAt = (expiresRaw == null || expiresRaw.isEmpty) ? null : DateTime.tryParse(expiresRaw)?.toLocal();
    final isVipUser = expiresAt != null && expiresAt.isAfter(DateTime.now());

    bool shouldShowAd = false;
    if (!isVipUser) {
      _episodesSinceLastAd++;
      if (_episodesSinceLastAd >= _adFrequencyInterval) {
        shouldShowAd = true;
        _episodesSinceLastAd = 0;
      }
    }

    if (shouldShowAd) {
      try {
        final cfg = ref.read(adsConfigProvider);
        final adsSvc = ref.read(adsServiceProvider);

        if (cfg != null && adsSvc.adsEnabled(cfg)) {
          try {
            _player?.pause();
          } catch (_) {}

          if (mounted) setState(() => _fullScreenAdOpen = true);

          await adsSvc.ensureInitialized(cfg);
          await adsSvc.showInterstitial();

          if (mounted) {
            setState(() => _fullScreenAdOpen = false);
            
            if (_pageController.hasClients && (_pageController.page?.round() ?? _index) != idx) {
              _pageController.jumpToPage(idx);
            }
            
            try {
              if (_player != null) {
                _player!.play();
                _scheduleAutoHideControls();
              }
            } catch (_) {}
          }
        }
      } catch (e) {
        if (mounted) {
          setState(() => _fullScreenAdOpen = false);
        }
      }
    }

    try {
      final freshData = await ref.read(watchApiProvider).show(
            slug: widget.slug,
            episodeNumber: targetEpisodeNumber,
          );
      for (final e in freshData.episodes) {
        _episodesByNumber[e.episodeNumber] = e;
      }
    } catch (_) {}

    await _ensureEpisodeLoaded(targetEpisodeNumber);
    await _startEpisodeNumber(targetEpisodeNumber);
    
    Future.microtask(() => _ensureEpisodeLoaded(targetEpisodeNumber + 2));
    Future.microtask(() => _ensureEpisodeLoaded(targetEpisodeNumber - 2));
  }

  void _handleVastAdFinished({required bool completed}) {
    if (!mounted) return;
    setState(() {
      _activeVastAd = null;
    });
    if (_vastRewardCompleter != null && !_vastRewardCompleter!.isCompleted) {
      _vastRewardCompleter!.complete(completed);
      _vastRewardCompleter = null;
    }
    if (widget.isActive && _videoReady && _player != null && !_player!.state.playing) {
      try {
        _player!.play();
      } catch (_) {}
    }
  }

  Future<void> _maybeShowVastPreroll() async {
    if (widget.reelsPreview) return;
    if (_activeVastAd != null) return;

    final session = ref.read(authSessionProvider).valueOrNull;
    final expiresRaw = (session?.user?['membership_expires_at'] as String?)?.trim();
    final expiresAt = (expiresRaw == null || expiresRaw.isEmpty) ? null : DateTime.tryParse(expiresRaw)?.toLocal();
    final isVip = expiresAt != null && expiresAt.isAfter(DateTime.now());
    if (isVip) return;

    final cfg = ref.read(adsConfigProvider);
    if (cfg == null || !cfg.vast.enabled || cfg.vast.url.trim().isEmpty) return;

    final freq = cfg.vast.frequency;
    _vastEpisodePlayCounter++;
    if (freq > 1 && (_vastEpisodePlayCounter % freq != 1 && _vastEpisodePlayCounter != 1)) {
      return;
    }

    try {
      final adData = await VastAdService.fetchVastAd(cfg.vast.url.trim(), defaultSkipSeconds: cfg.vast.skipSeconds);
      if (adData != null && mounted) {
        final completer = Completer<bool>();
        _vastRewardCompleter = completer;
        setState(() {
          _activeVastAd = adData;
        });
        try {
          _player?.pause();
        } catch (_) {}
        final finished = await completer.future.timeout(const Duration(seconds: 25), onTimeout: () => false);
        if (!finished && mounted && _activeVastAd != null) {
          _handleVastAdFinished(completed: false);
        }
      }
    } catch (e) {
      debugPrint('[WatchScreen] VAST preroll skipped: $e');
    }
  }

  Future<void> _unlockEpisodeByWatchingAd({required WatchEpisodeDto ep, required bool isVipUser}) async {
    if (_unlocking) return;
    if (isVipUser) return;
    final t = AppI18n.of(context);

    final cfg = ref.read(adsConfigProvider);
    final isVastProvider = cfg != null && (cfg.monetization.appAdProvider == 'vast' || (!ref.read(adsServiceProvider).adsEnabled(cfg) && cfg.vast.enabled));

    if (isVastProvider && cfg.vast.enabled && cfg.vast.url.trim().isNotEmpty) {
      _fullScreenAdOpen = true;
      if (mounted) setState(() {});
      try {
        _player?.pause();
      } catch (_) {}

      bool completed = false;
      try {
        final adData = await VastAdService.fetchVastAd(cfg.vast.url.trim(), defaultSkipSeconds: cfg.vast.skipSeconds);
        if (adData != null && mounted) {
          final completer = Completer<bool>();
          _vastRewardCompleter = completer;
          setState(() {
            _activeVastAd = adData;
          });
          completed = await completer.future.timeout(const Duration(seconds: 35), onTimeout: () => true);
        } else {
          completed = true;
        }
      } catch (_) {
        completed = true;
      } finally {
        _fullScreenAdOpen = false;
        if (mounted) setState(() {});
      }

      if (!mounted) return;
      if (!completed) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(t.t('ad_not_completed'))));
        return;
      }

      await _unlockEpisode(ep: ep, method: 'ad');
      return;
    }

    if (cfg == null || !ref.read(adsServiceProvider).adsEnabled(cfg)) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(t.t('request_failed'))));
      }
      return;
    }

    await ref.read(adsServiceProvider).ensureInitialized(cfg);
    _fullScreenAdOpen = true;
    if (mounted) setState(() {});
    try {
      _player?.pause();
    } catch (_) {}
    final completed = await ref.read(adsServiceProvider).showRewarded(onEarnedReward: () {}, requireEarnedReward: true);
    _fullScreenAdOpen = false;
    if (mounted) setState(() {});

    if (!mounted) return;
    if (!completed) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(t.t('ad_not_completed'))));
      return;
    }

    await _unlockEpisode(ep: ep, method: 'ad');
  }

  Future<void> _dismissSwipeGuide() async {
    if (!_showSwipeGuide) return;
    setState(() => _showSwipeGuide = false);
    final prefs = await ref.read(sharedPrefsProvider.future);
    await prefs.setBool('watch_swipe_guide_seen', true);
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      _autoUnlockTriedEpisodes.clear();
      final initialEpisode = (widget.episodeNumber != null && (widget.episodeNumber ?? 0) > 0) ? widget.episodeNumber : _restoreEpisodeNumber;
      final cached = ReelsPreloadManager.getCachedData(widget.slug);
      final canUseCache = cached != null &&
          (initialEpisode == null ||
              initialEpisode <= 1 ||
              cached.episodes.any((e) => e.episodeNumber == initialEpisode));
      
      final data = canUseCache
          ? cached
          : await ref.read(watchApiProvider).show(
                slug: widget.slug,
                episodeNumber: initialEpisode,
                episodesPerPage: _episodesPerPage,
                options: Options(
                  extra: {'reels_preview': widget.reelsPreview},
                ),
              );
      ReelsPreloadManager.cacheData(widget.slug, data);
      if (!mounted) return;

      _episodesPerPage = data.episodesPerPage > 0 ? data.episodesPerPage : _episodesPerPage;
      _episodesTotal = data.episodesTotal;
      _episodesPages = data.episodesPages;
      _loadedPages
        ..clear()
        ..add(data.episodesPage);
      _episodesByNumber
        ..clear()
        ..addEntries(data.episodes.map((e) => MapEntry(e.episodeNumber, e)));

      final forced = (widget.episodeNumber != null && (widget.episodeNumber ?? 0) > 0) ? widget.episodeNumber : null;
      final lastWatchedFromApi = data.series.lastWatchedEpisodeNumber;

      int activeNum = 1;
      if (forced != null && forced > 0) {
        activeNum = forced;
      } else if (_restoreEpisodeNumber != null && _restoreEpisodeNumber! > 0) {
        activeNum = _restoreEpisodeNumber!;
      } else if (lastWatchedFromApi > 1) {
        activeNum = lastWatchedFromApi;
      } else if (data.activeEpisodeNumber > 0) {
        activeNum = data.activeEpisodeNumber;
      } else if (data.episodes.isNotEmpty) {
        activeNum = data.episodes.first.episodeNumber;
      }

      final initial = widget.reelsPreview ? 0 : (_episodesTotal > 0 ? (activeNum - 1).clamp(0, _episodesTotal - 1) : 0);

      _lastProcessedEpisode = activeNum;

      final old = _pageController;
      final next = PageController(initialPage: initial);

      setState(() {
        _data = data;
        _loading = false;
        _index = initial;
        _likesCount = data.series.likesCount;
        _isLiked = data.series.isLiked;
        _pageController = next;
        _restoreEpisodeNumber = null;
      });

      WidgetsBinding.instance.addPostFrameCallback((_) {
        old.dispose();
      });

      await _ensureEpisodeLoaded(activeNum);
      await _startEpisodeNumber(activeNum);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _ensureEpisodeLoaded(int episodeNumber) async {
    if (episodeNumber < 1) return;
    if (_episodesPerPage <= 0) return;
    final page = ((episodeNumber - 1) ~/ _episodesPerPage) + 1;
    if (_loadedPages.contains(page)) return;
    if (_loadingEpisodesPage) return;

    setState(() => _loadingEpisodesPage = true);
    try {
      final data = await ref.read(watchApiProvider).show(
            slug: widget.slug,
            episodeNumber: episodeNumber,
            episodesPage: page,
            episodesPerPage: _episodesPerPage,
            options: Options(
              extra: {'reels_preview': widget.reelsPreview},
            ),
          );
      if (!mounted) return;

      _episodesPerPage = data.episodesPerPage > 0 ? data.episodesPerPage : _episodesPerPage;
      _episodesTotal = data.episodesTotal;
      _episodesPages = data.episodesPages;
      _loadedPages.add(data.episodesPage);
      for (final e in data.episodes) {
        _episodesByNumber[e.episodeNumber] = e;
      }

      setState(() {
        _data = data;
      });
    } catch (_) {
    } finally {
      if (mounted) setState(() => _loadingEpisodesPage = false);
    }
  }

  int _qualityRank(String q) {
    final s = q.trim().toLowerCase();
    if (s == '1080p') return 4;
    if (s == '720p') return 3;
    if (s == '480p') return 2;
    if (s == '360p') return 1;
    return 0;
  }

  List<String> _candidateUrls(WatchEpisodeDto ep) {
    final items = <({String url, int rank})>[];
    for (final s in ep.sources) {
      final type = (s['source_type'] as String?)?.trim().toLowerCase() ?? '';
      final u = (s['source_url'] as String?)?.trim() ?? '';
      final q = (s['quality'] as String?)?.trim() ?? '';
      if (u.isEmpty) continue;
      if (type == 'embed') continue;
      items.add((url: u, rank: _qualityRank(q)));
    }
    items.sort((a, b) => b.rank.compareTo(a.rank));
    final out = <String>[];
    for (final it in items) {
      if (out.contains(it.url)) continue;
      out.add(it.url);
    }
    final preferred = _preferredUrlByEpisode[ep.episodeNumber];
    if (preferred != null && preferred.trim().isNotEmpty && out.contains(preferred)) {
      out
        ..remove(preferred)
        ..insert(0, preferred);
    }
    final v = ep.videoUrl.trim();
    if (v.isNotEmpty && !out.contains(v)) out.add(v);
    return out;
  }

  List<Map<String, String>> _qualityOptions(WatchEpisodeDto ep) {
    final items = <({String quality, String url, int rank})>[];
    for (final s in ep.sources) {
      final type = (s['source_type'] as String?)?.trim().toLowerCase() ?? '';
      if (type == 'embed') continue;
      final u = (s['source_url'] as String?)?.trim() ?? '';
      if (u.isEmpty) continue;
      final q = (s['quality'] as String?)?.trim();
      if (q == null || q.isEmpty) continue;
      items.add((quality: q, url: u, rank: _qualityRank(q)));
    }
    items.sort((a, b) => b.rank.compareTo(a.rank));
    final out = <Map<String, String>>[];
    final seen = <String>{};
    for (final it in items) {
      if (seen.contains(it.quality)) continue;
      seen.add(it.quality);
      out.add({'quality': it.quality, 'url': it.url});
    }
    return out;
  }

  String _qualityLabel(WatchEpisodeDto ep, AppI18n t) {
    final preferred = _preferredQualityByEpisode[ep.episodeNumber];
    if (preferred != null && preferred.trim().isNotEmpty) return preferred;
    return t.t('auto');
  }

  void _openQualitySheet(WatchEpisodeDto ep) async {
    final t = AppI18n.of(context);
    final options = _qualityOptions(ep);
    if (options.length < 2) return;
    final currentQuality = (_preferredQualityByEpisode[ep.episodeNumber] ?? '').trim();
    _inModalSheet = true;
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
            child: Container(
              decoration: BoxDecoration(
                color: const Color(0xff0e0e10),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const SizedBox(height: 10),
                  Container(
                    width: 46,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.16),
                      borderRadius: BorderRadius.circular(99),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            t.t('choose_quality'),
                            style: TextStyle(color: Colors.white.withValues(alpha: 0.92), fontSize: 14, fontWeight: FontWeight.w500),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        InkWell(
                          onTap: () => Navigator.of(context).pop(),
                          borderRadius: BorderRadius.circular(999),
                          child: Container(
                            width: 36,
                            height: 36,
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.06),
                              borderRadius: BorderRadius.circular(999),
                              border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
                            ),
                            child: const Icon(Icons.close_rounded, size: 18, color: Colors.white),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),
                  Flexible(
                    child: ListView.separated(
                      shrinkWrap: true,
                      padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                      itemBuilder: (context, i) {
                        final o = options[i];
                        final q = (o['quality'] ?? '').trim();
                        final u = (o['url'] ?? '').trim();
                        final selected = q.isNotEmpty && q == currentQuality;
                        final topQuality = i == 0;
                        return InkWell(
                          onTap: () {
                            Navigator.of(context).pop();
                            WidgetsBinding.instance.addPostFrameCallback((_) async {
                              if (!mounted) return;
                              final p = _player;
                              final pos = p != null ? p.state.position : Duration.zero;
                              final wasPlaying = p != null ? p.state.playing : true;
                              setState(() {
                                _preferredQualityByEpisode[ep.episodeNumber] = q;
                                _preferredUrlByEpisode[ep.episodeNumber] = u;
                              });
                              await _startEpisodeNumber(ep.episodeNumber, resumePosition: pos, resumePlaying: wasPlaying);
                            });
                          },
                          borderRadius: BorderRadius.circular(14),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                            decoration: BoxDecoration(
                              color: selected
                                  ? const Color(0xffef233c)
                                  : (topQuality ? const Color(0xff1a1412) : const Color(0xff141418)),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color: selected
                                    ? Colors.transparent
                                    : (topQuality ? const Color(0xfffbbf24).withValues(alpha: 0.55) : Colors.white.withValues(alpha: 0.08)),
                              ),
                            ),
                            child: Row(
                              children: [
                                if (topQuality) ...[
                                  Image.asset(
                                    'assets/images/icon_subscribe_iaa_hd.png',
                                    width: 20,
                                    height: 20,
                                    fit: BoxFit.contain,
                                    errorBuilder: (context, error, stackTrace) {
                                      return const Icon(Icons.hd_rounded, size: 20, color: Color(0xfffbbf24));
                                    },
                                  ),
                                  const SizedBox(width: 10),
                                ],
                                Expanded(
                                  child: Text(
                                    q,
                                    style: TextStyle(color: Colors.white.withValues(alpha: 0.92), fontWeight: FontWeight.w500, fontSize: 13),
                                  ),
                                ),
                                if (selected) const Icon(Icons.check_rounded, color: Colors.white, size: 18),
                              ],
                            ),
                          ),
                        );
                      },
                      separatorBuilder: (context, index) => const SizedBox(height: 10),
                      itemCount: options.length,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
    _inModalSheet = false;
  }

  // ULTRA-FAST INSTANT PLAYER START & PRELOAD POOL POINTER SWAP
  Future<void> _startEpisodeNumber(
    int episodeNumber, {
    Duration? resumePosition,
    bool? resumePlaying,
  }) async {
    final opId = ++_videoOpId;
    final data = _data;
    if (data == null) return;

    final ep = _episodesByNumber[episodeNumber];
    if (ep == null) return;
    final urls = _candidateUrls(ep);
    if (!ep.isUnlocked || urls.isEmpty) {
      if (mounted) {
        setState(() {
          _videoReady = false;
          _controlsVisible = true;
          _videoLoading = false;
          _videoError = null;
        });
      }
      return;
    }

    final targetUrl = urls.first;

    _activeVideoUrl = targetUrl;
    _videoError = null;

    // 1. Periksa apakah video ini sudah di-preload di background oleh _preloadPlayer
    if (_preloadPlayer != null && _preloadedUrl == targetUrl) {
      try {
        final oldPlayer = _player;
        _player = _preloadPlayer;
        _videoController = media_kit_video.VideoController(_player!);
        _preloadPlayer = null;
        _preloadedUrl = null;

        oldPlayer?.dispose();

        if (resumePosition != null && resumePosition > Duration.zero) {
          await _player!.seek(resumePosition);
        }

        if (widget.isActive) {
          await _player!.play();
        }

        if (mounted) {
          setState(() {
            _videoReady = true;
            _videoLoading = false;
          });
        }

        await _maybeShowVastPreroll();
        _showControls();
        _triggerPreloadNextEpisodes(episodeNumber);
        return;
      } catch (_) {}
    }

    // 2. Jika belum, gunakan player utama secara langsung
    final player = _player ?? media_kit_pkg.Player();
    final videoController = _videoController ?? media_kit_video.VideoController(player);

    _player = player;
    _videoController = videoController;

    try {
      await player.setRate(_playbackSpeed);
      await player.open(media_kit_pkg.Media(targetUrl), play: (resumePlaying ?? true) && widget.isActive);

      if (resumePosition != null && resumePosition > Duration.zero) {
        await player.seek(resumePosition);
      }

      if (!mounted || _disposed || opId != _videoOpId) return;

      if (mounted) {
        setState(() {
          _videoReady = true;
          _videoLoading = false;
          _videoError = null;
        });
      }

      await _maybeShowVastPreroll();
      _showControls();
      _triggerPreloadNextEpisodes(episodeNumber);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _videoReady = false;
        _videoLoading = false;
        _videoError = e.toString();
      });
    }
  }

  // Siapkan episode berikutnya secara diam-diam di background player
  void _triggerPreloadNextEpisodes(int currentEpNum) {
    if (widget.reelsPreview) return;
    final nextEpNum = currentEpNum + 1;
    final nextEp = _episodesByNumber[nextEpNum];
    if (nextEp == null || !nextEp.isUnlocked) return;

    final nextUrls = _candidateUrls(nextEp);
    final nextUrl = nextUrls.isNotEmpty ? nextUrls.first : nextEp.videoUrl.trim();
    if (nextUrl.isEmpty || _preloadedUrl == nextUrl) return;

    try {
      _preloadPlayer ??= media_kit_pkg.Player();
      _preloadedUrl = nextUrl;
      _preloadPlayer!.open(media_kit_pkg.Media(nextUrl), play: false);
    } catch (_) {}
  }

  String _fmt(Duration d) {
    final total = d.inSeconds;
    final m = (total ~/ 60).toString().padLeft(2, '0');
    final s = (total % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  Future<void> _setSpeed(double next) async {
    final p = _player;
    if (p == null) return;
    try {
      await p.setRate(next);
      if (!mounted) return;
      setState(() => _playbackSpeed = next);
    } catch (_) {}
  }

  void _openSpeedSheet() {
    final t = AppI18n.of(context);
    const speeds = <double>[0.5, 1.0, 1.25, 1.5, 2.0];
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
            child: Container(
              decoration: BoxDecoration(
                color: const Color(0xff0b0b0b),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const SizedBox(height: 10),
                  Container(
                    width: 46,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.16),
                      borderRadius: BorderRadius.circular(99),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            t.t('speed'),
                            style: TextStyle(color: Colors.white.withValues(alpha: 0.92), fontSize: 14, fontWeight: FontWeight.w500),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        InkWell(
                          onTap: () => Navigator.of(context).pop(),
                          borderRadius: BorderRadius.circular(999),
                          child: Container(
                            width: 36,
                            height: 36,
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.06),
                              borderRadius: BorderRadius.circular(999),
                              border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
                            ),
                            child: const Icon(Icons.close_rounded, size: 18, color: Colors.white),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),
                  Flexible(
                    child: ListView.separated(
                      shrinkWrap: true,
                      padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                      itemBuilder: (context, i) {
                        final s = speeds[i];
                        final selected = (_playbackSpeed - s).abs() < 0.01;
                        return InkWell(
                          onTap: () {
                            Navigator.of(context).pop();
                            WidgetsBinding.instance.addPostFrameCallback((_) => _setSpeed(s));
                          },
                          borderRadius: BorderRadius.circular(14),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                            decoration: BoxDecoration(
                              color: selected ? const Color(0xffef233c) : const Color(0xff141418),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(color: selected ? Colors.transparent : Colors.white.withValues(alpha: 0.08)),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.speed_rounded, size: 18, color: Colors.white),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    '${s.toStringAsFixed(s == 1.25 ? 2 : 1)}x',
                                    style: TextStyle(color: Colors.white.withValues(alpha: 0.92), fontWeight: FontWeight.w500, fontSize: 13),
                                  ),
                                ),
                                if (selected) const Icon(Icons.check_rounded, color: Colors.white, size: 18),
                              ],
                            ),
                          ),
                        );
                      },
                      separatorBuilder: (context, index) => const SizedBox(height: 10),
                      itemCount: speeds.length,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  void _openMoreSheet(WatchEpisodeDto? ep) {
    final t = AppI18n.of(context);
    final e = ep;
    final qualityOptions = e == null ? const <Map<String, String>>[] : _qualityOptions(e);
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: const Color(0xff0b0b0b),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      isScrollControlled: true,
      builder: (context) {
        return SafeArea(
          child: SizedBox(
            width: double.infinity,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(height: 10),
                Container(
                  width: 46,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.16),
                    borderRadius: BorderRadius.circular(99),
                  ),
                ),
                const SizedBox(height: 12),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          t.t('more'),
                          style: TextStyle(color: Colors.white.withValues(alpha: 0.92), fontSize: 14, fontWeight: FontWeight.w500),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      InkWell(
                        onTap: () => Navigator.of(context).pop(),
                        borderRadius: BorderRadius.circular(999),
                        child: Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.06),
                            borderRadius: BorderRadius.circular(999),
                            border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
                          ),
                          child: const Icon(Icons.close_rounded, size: 18, color: Colors.white),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
                Padding(
                  padding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      WatchMoreItem(
                        icon: Icons.speed_rounded,
                        title: t.t('speed'),
                        subtitle: '${_playbackSpeed.toStringAsFixed(1)}x',
                        onTap: () {
                          Navigator.of(context).pop();
                          WidgetsBinding.instance.addPostFrameCallback((_) => _openSpeedSheet());
                        },
                      ),
                      const SizedBox(height: 10),
                      if (e != null && qualityOptions.length > 1) ...[
                        WatchMoreItem(
                          icon: Icons.hd_rounded,
                          title: t.t('quality'),
                          subtitle: _qualityLabel(e, t),
                          onTap: () {
                            Navigator.of(context).pop();
                            WidgetsBinding.instance.addPostFrameCallback((_) => _openQualitySheet(e));
                          },
                        ),
                        const SizedBox(height: 10),
                      ],
                      WatchMoreItem(
                        icon: Icons.share_rounded,
                        title: t.t('share'),
                        onTap: () {
                          Navigator.of(context).pop();
                          WidgetsBinding.instance.addPostFrameCallback((_) => _share());
                        },
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _openSeriesInfoSheet() {
    final data = _data;
    if (data == null) return;
    final t = AppI18n.of(context);
    final series = data.series;
    final genresLine = series.genres.where((e) => e.trim().isNotEmpty).join(' • ');
    final ageRatingAsset = _ageRatingAsset(series.contentRating);
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: const Color(0xff0b0b0b),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      isScrollControlled: true,
      builder: (context) {
        return SafeArea(
          child: SizedBox(
            width: double.infinity,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(height: 10),
                Container(
                  width: 46,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.16),
                    borderRadius: BorderRadius.circular(99),
                  ),
                ),
                const SizedBox(height: 12),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          series.title,
                          style: TextStyle(color: Colors.white.withValues(alpha: 0.92), fontSize: 14, fontWeight: FontWeight.w500),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      InkWell(
                        onTap: () => Navigator.of(context).pop(),
                        borderRadius: BorderRadius.circular(999),
                        child: Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.06),
                            borderRadius: BorderRadius.circular(999),
                            border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
                          ),
                          child: const Icon(Icons.close_rounded, size: 18, color: Colors.white),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
                Flexible(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: const Color(0xff141418),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(12),
                                child: SizedBox(
                                  width: 92,
                                  height: 128,
                                  child: AppCachedImage(
                                    imageUrl: series.posterUrl,
                                    fit: BoxFit.cover,
                                    errorWidget: (_) => Container(color: Colors.white.withValues(alpha: 0.06)),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      series.title,
                                      style: TextStyle(color: Colors.white.withValues(alpha: 0.92), fontWeight: FontWeight.w500, fontSize: 16),
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    const SizedBox(height: 8),
                                    if (genresLine.isNotEmpty)
                                      Text(
                                        genresLine,
                                        style: TextStyle(color: Colors.white.withValues(alpha: 0.70), fontWeight: FontWeight.w500, fontSize: 12),
                                      ),
                                    const SizedBox(height: 10),
                                    Row(
                                      children: [
                                        Image.asset(
                                          ageRatingAsset,
                                          height: 26,
                                          fit: BoxFit.contain,
                                          errorBuilder: (context, error, stackTrace) => const SizedBox.shrink(),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 10),
                                    Row(
                                      children: [
                                        Icon(Icons.remove_red_eye_rounded, size: 18, color: Colors.white.withValues(alpha: 0.80)),
                                        const SizedBox(width: 8),
                                        Text(
                                          '${t.t('views')}: ${series.viewsCount}',
                                          style: TextStyle(color: Colors.white.withValues(alpha: 0.80), fontWeight: FontWeight.w500, fontSize: 12),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (series.synopsis.trim().isNotEmpty) ...[
                          const SizedBox(height: 12),
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: const Color(0xff141418),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
                            ),
                            child: Text(
                              series.synopsis.trim(),
                              style: TextStyle(color: Colors.white.withValues(alpha: 0.84), fontWeight: FontWeight.w500, fontSize: 13, height: 1.35),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _share() async {
    final t = AppI18n.of(context);
    final base = apiBaseUrl.replaceFirst(RegExp(r'/api/?$'), '');
    final url = '$base/watch/${widget.slug}';
    await Clipboard.setData(ClipboardData(text: url));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(t.t('copied')),
        behavior: SnackBarBehavior.floating,
        backgroundColor: const Color(0xff0b0b0b),
      ),
    );
  }

  Future<void> _toggleLike() async {
    final data = _data;
    if (data == null) return;

    final beforeLiked = _isLiked;
    final beforeCount = _likesCount;
    setState(() {
      _isLiked = !_isLiked;
      _likesCount = (_isLiked ? beforeCount + 1 : (beforeCount - 1).clamp(0, 1 << 30));
    });

    try {
      final resp = await ref.read(watchApiProvider).toggleLike(seriesId: data.series.id);
      if (!mounted) return;
      final liked = resp['is_liked'] == true;
      final count = (resp['likes_count'] as num?)?.toInt();
      setState(() {
        _isLiked = liked;
        if (count != null) _likesCount = count;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isLiked = beforeLiked;
        _likesCount = beforeCount;
      });
    }
  }

  String _ageRatingAsset(String raw) {
    final v = raw.trim().toLowerCase();
    return switch (v) {
      '12' || '12+' => 'assets/images/age_rating_12.png',
      '15' || '15+' => 'assets/images/age_rating_15.png',
      '19' || '19+' => 'assets/images/age_rating_19.png',
      _ => 'assets/images/age_rating_all.png',
    };
  }

  Future<void> _setAutoUnlockEnabled(bool next) async {
    final prefs = await ref.read(sharedPrefsProvider.future);
    await prefs.setBool('watch_auto_unlock', next);
    if (!mounted) return;
    setState(() => _autoUnlockEnabled = next);
    if (next) {
      _autoUnlockTriedEpisodes.add(_currentEpisodeNumber);
    }
  }

  Future<void> _reloadEpisodesPageForEpisode(int episodeNumber) async {
    if (episodeNumber < 1) return;
    if (_episodesPerPage <= 0) return;
    final page = ((episodeNumber - 1) ~/ _episodesPerPage) + 1;
    try {
      final data = await ref.read(watchApiProvider).show(
            slug: widget.slug,
            episodeNumber: episodeNumber,
            episodesPage: page,
            episodesPerPage: _episodesPerPage,
            options: Options(
              extra: {'reels_preview': widget.reelsPreview},
            ),
          );
      if (!mounted) return;

      _episodesPerPage = data.episodesPerPage > 0 ? data.episodesPerPage : _episodesPerPage;
      _episodesTotal = data.episodesTotal;
      _episodesPages = data.episodesPages;
      _loadedPages.add(data.episodesPage);
      for (final e in data.episodes) {
        _episodesByNumber[e.episodeNumber] = e;
      }
      setState(() => _data = data);
    } catch (_) {}
  }

  Future<void> _unlockEpisode({required WatchEpisodeDto ep, required String method}) async {
    if (_unlocking) return;
    final t = AppI18n.of(context);
    setState(() => _unlocking = true);
    try {
      await ref.read(watchApiProvider).unlockEpisode(episodeId: ep.id, method: method);
      await _reloadEpisodesPageForEpisode(ep.episodeNumber);

      try {
        final prefs = await ref.read(sharedPrefsProvider.future);
        await prefs.setString('watch_restore_slug', widget.slug);
        await prefs.setInt('watch_restore_episode', ep.episodeNumber);
        final fresh = await ref.read(authApiProvider).me();
        await ref.read(authSessionProvider.notifier).setUser(fresh);
      } catch (_) {}

      await _startEpisodeNumber(ep.episodeNumber);
    } on DioException catch (e) {
      final msg = (e.response?.data is Map) ? (((e.response?.data as Map)['message'] as String?) ?? '') : '';
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(msg.isNotEmpty ? msg : t.t('request_failed')),
          behavior: SnackBarBehavior.floating,
          backgroundColor: const Color(0xff0b0b0b),
        ),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(t.t('request_failed')),
          behavior: SnackBarBehavior.floating,
          backgroundColor: const Color(0xff0b0b0b),
        ),
      );
    } finally {
      if (mounted) setState(() => _unlocking = false);
    }
  }

  void _openEpisodesSheet() async {
    final data = _data;
    if (data == null) return;
    if (widget.reelsPreview) return;

    final wasPlaying = _player?.state.playing ?? false;
    _inModalSheet = true;
    var selectedNew = false;

    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: const Color(0xff0b0b0b),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      isScrollControlled: true,
      builder: (sheetContext) {
        return WatchEpisodesSheet(
          seriesTitle: data.series.title,
          totalEpisodes: _episodesTotal,
          episodesPerPage: _episodesPerPage,
          episodesPages: _episodesPages,
          currentEpisodeNumber: _currentEpisodeNumber,
          episodesByNumber: _episodesByNumber.map((k, v) => MapEntry(k, v as dynamic)),
          autoUnlockEnabled: _autoUnlockEnabled,
          onSetAutoUnlock: _setAutoUnlockEnabled,
          onNeedPage: (page) => _ensureEpisodeLoaded(((page - 1) * _episodesPerPage) + 1),
          onSelectEpisode: (episodeNumber) {
            selectedNew = true;
            Navigator.of(sheetContext).pop();
            WidgetsBinding.instance.addPostFrameCallback((_) async {
              if (!mounted) return;
              final idx = episodeNumber - 1;
              if (_pageController.hasClients) {
                _pageController.jumpToPage(idx);
              }
              setState(() => _index = idx);
              await _ensureEpisodeLoaded(episodeNumber);
              await _startEpisodeNumber(episodeNumber);
            });
          },
        );
      },
    );

    _inModalSheet = false;
    if (mounted && !selectedNew && wasPlaying) {
      final p = _player;
      if (p != null && !p.state.playing) {
        try {
          p.play();
          if (!widget.reelsPreview) {
            _scheduleAutoHideControls();
          }
          setState(() {});
        } catch (_) {}
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = AppI18n.of(context);
    final data = _data;
    final session = ref.watch(authSessionProvider).valueOrNull;
    final coinsBalance = (session?.user?['coins_balance'] as num?)?.toInt() ?? (session?.user?['coins'] as num?)?.toInt() ?? 0;
    final expiresRaw = (session?.user?['membership_expires_at'] as String?)?.trim();
    final expiresAt = (expiresRaw == null || expiresRaw.isEmpty) ? null : DateTime.tryParse(expiresRaw)?.toLocal();
    final isVipUser = expiresAt != null && expiresAt.isAfter(DateTime.now());

    if (_loading || _error != null || data == null) {
      final initialPoster = (widget.posterUrl ?? widget.reelsBackdropUrl ?? '').trim();
      return WatchLoadingErrorBody(
        isLoading: _loading,
        error: _error,
        reelsPreview: widget.reelsPreview,
        reelsBackdropUrl: initialPoster,
        errorMessageFor: _errorMessageFor,
        onRetry: _load,
        onSafePopOrHome: _safePopOrHome,
      );
    }

    final series = data.series;
    final total = _episodesTotal > 0 ? _episodesTotal : data.episodesTotal;
    final totalEpisodes = total > 0 ? total : 0;
    final bg = series.posterUrl.trim().isNotEmpty ? series.posterUrl : series.featuredImageUrl;

    if (totalEpisodes <= 0) {
      final topPad = MediaQuery.of(context).viewPadding.top;
      return WatchNoEpisodesBody(
        bg: bg,
        topPad: topPad,
        onSafePopOrHome: _safePopOrHome,
      );
    }

    final pageViewItemCount = widget.reelsPreview ? 1 : (totalEpisodes + 1);

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        Future.microtask(() => _showExitInterstitialAndLeave(isVipUser: isVipUser));
      },
      child: Scaffold(
        backgroundColor: Colors.black,
        body: Stack(
          children: [
            const ColoredBox(color: Colors.black),
            NotificationListener<ScrollNotification>(
              onNotification: (notification) {
                if (notification is ScrollEndNotification && totalEpisodes > 0 && _index >= totalEpisodes) {
                  _navigateToRandomSeries();
                }
                return false;
              },
              child: PageView.builder(
                controller: _pageController,
                scrollDirection: Axis.vertical,
                physics: widget.reelsPreview ? const NeverScrollableScrollPhysics() : null,
                onPageChanged: (i) async {
                  if (widget.reelsPreview) return;

                  if (totalEpisodes > 0 && i >= totalEpisodes) {
                    try {
                      _player?.pause();
                    } catch (_) {}
                    _navigateToRandomSeries();
                    return;
                  }

                  setState(() {
                    _index = i;
                  });
                  final epNum = _episodeNumberForPageIndex(i);
                  await _handleEpisodeChangeWithAds(epNum);
                },
                itemBuilder: (context, i) {
                  if (!widget.reelsPreview && i >= totalEpisodes) {
                    return Container(
                      color: Colors.black,
                      child: const Center(
                        child: SizedBox(
                          width: 32,
                          height: 32,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.5,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    );
                  }

                  final epNum = _episodeNumberForPageIndex(i);
                  final ep = _episodesByNumber[epNum];
                  final isActive = i == _index;
                  
                  final mediaKitVideoController = isActive ? _videoController : null;
                  
                  final ready = isActive && _videoReady && mediaKitVideoController != null;
                  final isUnlocked = ep?.isUnlocked ?? false;
                  final hasVideo = isUnlocked && ((ep?.videoUrl.trim().isNotEmpty ?? false));
                  final unlock = data.unlock;
                  final cfg = ref.watch(adsConfigProvider);
                  final coinSystemEnabled = cfg?.monetization.coinSystemEnabled ?? true;
                  final allowVipUnlock = cfg?.monetization.episodeUnlockAllowVip ?? true;
                  final showVipUpsell = (!coinSystemEnabled) && allowVipUnlock && !isVipUser;
                  final allowAdsUnlock = coinSystemEnabled && unlock.method.trim().toLowerCase() != 'coins' && unlock.dailyAdLimit > 0;
                  final canUnlockByAd = allowAdsUnlock && unlock.adUnlocksToday < unlock.dailyAdLimit;
                  final unlockCost = unlock.cost;
                  final coinsEnabled = coinSystemEnabled && unlock.method.trim().toLowerCase().contains('coins');
                  final canUnlockByCoins = session != null && coinsEnabled && unlockCost > 0 && coinsBalance >= unlockCost;
                  final topPad = MediaQuery.of(context).viewPadding.top;
                  final bottomPad = MediaQuery.of(context).viewPadding.bottom;
                  final genresLine = series.genres.where((g) => g.trim().isNotEmpty).join(' • ');
                  final loadingEpisode = isActive && ep == null;

                  if (isActive && !isUnlocked && ep != null && _autoUnlockEnabled && canUnlockByCoins && !_autoUnlockTriedEpisodes.contains(epNum)) {
                    _autoUnlockTriedEpisodes.add(epNum);
                    Future.microtask(() => _unlockEpisode(ep: ep, method: 'coins'));
                  }

                  return WatchEpisodePageItem(
                    epNum: epNum,
                    ep: ep,
                    isActive: isActive,
                    mediaKitVideoController: mediaKitVideoController,
                    ready: ready,
                    isUnlocked: isUnlocked,
                    hasVideo: hasVideo,
                    series: series,
                    cfg: cfg,
                    coinSystemEnabled: coinSystemEnabled,
                    allowVipUnlock: allowVipUnlock,
                    showVipUpsell: showVipUpsell,
                    allowAdsUnlock: allowAdsUnlock,
                    canUnlockByAd: canUnlockByAd,
                    unlockCost: unlockCost,
                    coinsEnabled: coinsEnabled,
                    canUnlockByCoins: canUnlockByCoins,
                    topPad: topPad,
                    bottomPad: bottomPad,
                    genresLine: genresLine,
                    loadingEpisode: loadingEpisode,
                    isVipUser: isVipUser,
                    coinsBalance: coinsBalance,
                    totalEpisodes: totalEpisodes,
                    controlsVisible: _controlsVisible,
                    videoLoading: _videoLoading,
                    videoError: _videoError,
                    activeVideoUrl: _activeVideoUrl,
                    showLikeBurst: _showLikeBurst,
                    likeBurstPos: _likeBurstPos,
                    likeBurstAnimation: _likeBurst,
                    likeBurstScale: _likeBurstScale,
                    likeBurstOpacity: _likeBurstOpacity,
                    rewardShakeAnimation: _rewardShake,
                    rewardDismissed: _rewardDismissed,
                    showSwipeGuide: _showSwipeGuide,
                    guideShakeAnimation: _guideShake,
                    isLiked: _isLiked,
                    likesCount: _likesCount,
                    autoUnlockEnabled: _autoUnlockEnabled,
                    unlocking: _unlocking,
                    adUnlocksToday: unlock.adUnlocksToday,
                    dailyAdLimit: unlock.dailyAdLimit,
                    qualityLabel: (dynamic e, dynamic tr) => _qualityLabel(e as WatchEpisodeDto, tr as AppI18n),
                    fmtDuration: _fmt,
                    ageRatingAsset: _ageRatingAsset,
                    coinUnit: t.t('coin_unit'),
                    bg: bg,
                    reelsPreview: widget.reelsPreview,
                    onTap: _onScreenTap,
                    onDoubleTapDown: (d) => _lastDoubleTapLocalPos = d.localPosition,
                    onDoubleTap: () => _onDoubleTapLike(_lastDoubleTapLocalPos),
                    onToggleControls: _toggleControls,
                    onSafePopOrHome: _safePopOrHome,
                    onToggleLike: _toggleLike,
                    onOpenEpisodesSheet: _openEpisodesSheet,
                    onOpenMoreSheet: () => _openMoreSheet(ep),
                    onOpenSeriesInfo: _openSeriesInfoSheet,
                    onWatchNow: () {
                      final slug = series.slug.trim();
                      if (slug.isEmpty) return;
                      
                      try {
                        _player?.pause();
                      } catch (_) {}

                      if (widget.slug == slug) {
                        if (_pageController.hasClients) {
                          _pageController.jumpToPage(0);
                        }
                        return;
                      }

                      final target = '/watch/$slug?title=${Uri.encodeComponent(series.title)}&episode=1&from=reels';
                      context.push(target);
                    },
                    onTapReward: () => _pauseVideoAndPush('/rewards'),
                    onDismissReward: () => setState(() => _rewardDismissed = true),
                    onDismissSwipeGuide: _dismissSwipeGuide,
                    onRetryVideo: () => _startEpisodeNumber(epNum),
                    onOpenQualitySheet: (dynamic e) => _openQualitySheet(e as WatchEpisodeDto),
                    onPauseAndPushMembership: () => _pauseVideoAndPush('/membership'),
                    onRecharge: () => _pauseVideoAndPush('/recharge'),
                    onUnlockWithCoins: ep == null ? () {} : () => _unlockEpisode(ep: ep, method: 'coins'),
                    onUnlockWithAd: ep == null ? () {} : () => _unlockEpisodeByWatchingAd(ep: ep, isVipUser: isVipUser),
                    onSetAutoUnlock: _setAutoUnlockEnabled,
                    paywallAnimBuilder: ({required int episodeNumber, required Widget child}) => _buildPaywallPop(
                      episodeNumber: episodeNumber,
                      child: child,
                    ),
                    episodeNumber: epNum,
                    onTogglePlayback: _onCenterPlayPressed,
                  );
                },
                itemCount: pageViewItemCount,
              ),
            ),
            if ((_exitInterstitialBlockedUI || _fullScreenAdOpen) && _activeVastAd == null)
              Positioned.fill(
                child: IgnorePointer(
                  child: ColoredBox(color: Colors.black),
                ),
              ),
            if (_activeVastAd != null)
              Positioned.fill(
                child: WatchVastAdOverlay(
                  adData: _activeVastAd!,
                  onAdClosed: (completed) => _handleVastAdFinished(completed: completed),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
