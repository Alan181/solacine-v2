import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:applovin_max/applovin_max.dart' as applovin;
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:unity_ads_plugin/unity_ads_plugin.dart';
import 'package:unity_levelplay_mediation/unity_levelplay_mediation.dart';

import '../data/ads_config.dart';

enum _AdKind {
  banner,
  interstitial,
  rewarded,
}

class AdsService {
  AdsService();

  bool _initialized = false;
  AdsConfig? _config;

  InterstitialAd? _admobInterstitial;
  bool _loadingAdmobInterstitial = false;

  bool _applovinInitialized = false;
  bool _unityInitialized = false;
  bool _ironsourceInitialized = false;

  final Map<String, bool> _unityLoaded = <String, bool>{};
  Completer<void>? _unityInitCompleter;
  Completer<void>? _ironsourceInitCompleter;

  LevelPlayInterstitialAd? _ironsourceInterstitial;
  LevelPlayRewardedAd? _ironsourceRewarded;

  DateTime? _lastInterstitialShownAt;
  DateTime? _lastFullScreenAdShownAt;

  bool get initialized => _initialized;
  AdsConfig? get config => _config;
  DateTime? get lastFullScreenAdShownAt => _lastFullScreenAdShownAt;

  void _log(String message) {}

  AdsNetwork? _forcedNetworkFromProvider(AdsConfig cfg) {
    final raw = cfg.monetization.appAdProvider.trim().toLowerCase();
    return switch (raw) {
      'admob' => AdsNetwork.admob,
      'facebook' => AdsNetwork.admob,
      'meta' => AdsNetwork.admob,
      'fan' => AdsNetwork.admob,
      'applovin' => AdsNetwork.applovin,
      'max' => AdsNetwork.applovin,
      'unity' => AdsNetwork.unity,
      'ironsource' => AdsNetwork.ironsource,
      'levelplay' => AdsNetwork.ironsource,
      _ => null,
    };
  }

  (bool, String) _networkHasAnyAdWithReason(AdsConfig cfg, AdsNetwork network) {
    final banner = _supportsNetwork(cfg, network, _AdKind.banner);
    final interstitial = _supportsNetwork(cfg, network, _AdKind.interstitial);
    final rewarded = _supportsNetwork(cfg, network, _AdKind.rewarded);
    final any = banner.$1 || interstitial.$1 || rewarded.$1;
    if (any) return (true, 'at least one ad type configured (banner=${banner.$1}, interstitial=${interstitial.$1}, rewarded=${rewarded.$1})');
    final reasons = <String>[
      if (!_isNetworkEnabled(cfg, network)) '$network.status=Disabled',
    ];
    final keyMissing = [banner, interstitial, rewarded].where((e) => !e.$1).map((e) => e.$2).where((s) => s.isNotEmpty).toSet().toList();
    if (keyMissing.isNotEmpty) reasons.add('missing IDs: ${keyMissing.join(', ')}');
    return (false, reasons.isEmpty ? 'no ad units configured' : reasons.join('; '));
  }

  bool _isNetworkEnabled(AdsConfig cfg, AdsNetwork network) {
    return switch (network) {
      AdsNetwork.admob => cfg.admob.enabled,
      AdsNetwork.applovin => cfg.applovin.enabled,
      AdsNetwork.unity => cfg.unity.enabled,
      AdsNetwork.ironsource => cfg.ironsource.enabled,
    };
  }

  (bool, String) _supportsNetwork(AdsConfig cfg, AdsNetwork network, _AdKind kind) {
    if (!_isNetworkEnabled(cfg, network)) return (false, 'disabled');
    return switch (network) {
      AdsNetwork.admob => (true, ''),
      AdsNetwork.applovin => _checkIds(cfg.applovin.sdkKey, kind == _AdKind.banner ? cfg.applovin.bannerId : kind == _AdKind.interstitial ? cfg.applovin.interstitialId : cfg.applovin.rewardedId, kind),
      AdsNetwork.unity => _checkIds(cfg.unity.gameId, kind == _AdKind.banner ? cfg.unity.bannerId : kind == _AdKind.interstitial ? cfg.unity.interstitialId : cfg.unity.rewardedId, kind),
      AdsNetwork.ironsource => _checkIds(cfg.ironsource.appKey, kind == _AdKind.banner ? cfg.ironsource.bannerId : kind == _AdKind.interstitial ? cfg.ironsource.interstitialId : cfg.ironsource.rewardedId, kind),
    };
  }

  (bool, String) _checkIds(String key, String unitId, _AdKind kind) {
    if (key.trim().isEmpty) return (false, 'sdk/app/game key empty');
    if (unitId.trim().isEmpty) return (false, '${kind.name}Id empty');
    return (true, '');
  }

  bool _isMediationMode(AdsConfig cfg) {
    final p = cfg.monetization.appAdProvider.trim().toLowerCase();
    return const {'mediation', 'rotation', 'custom'}.contains(p);
  }

  AdsNetwork? _smartFallbackProvider(AdsConfig cfg, {_AdKind? forKind}) {
    final candidates = <AdsNetwork>[AdsNetwork.unity, AdsNetwork.applovin, AdsNetwork.ironsource, AdsNetwork.admob];
    for (final n in candidates) {
      final (ok, _) = _networkHasAnyAdWithReason(cfg, n);
      if (!ok) continue;
      if (forKind != null) {
        final s = _supportsNetwork(cfg, n, forKind);
        if (!s.$1) continue;
      }
      _log('[Smart Fallback] picked $n as first eligible network for provider fallback');
      return n;
    }
    return null;
  }

  (AdsNetwork, String) _resolveEffectiveProvider(AdsConfig cfg) {
    final raw = cfg.monetization.appAdProvider.trim().toLowerCase();
    final mediation = _isMediationMode(cfg);
    final forced = _forcedNetworkFromProvider(cfg);
    if (mediation) {
      final fallback = _smartFallbackProvider(cfg);
      if (fallback == null) return (AdsNetwork.admob, 'mediation mode but no network ready; default to admob');
      return (fallback, 'mediation mode (provider=$raw); smart fallback to first ready network');
    }
    if (forced == null) {
      final fallback = _smartFallbackProvider(cfg);
      if (fallback == null) return (AdsNetwork.admob, 'provider=$raw unrecognized and no network ready; default to admob');
      return (fallback, 'provider=$raw unrecognized; smart fallback to first ready network');
    }
    final (ok, reason) = _networkHasAnyAdWithReason(cfg, forced);
    if (ok) {
      return (forced, 'SINGLE-PROVIDER MODE (forced=$raw) -> $forced OK ($reason)');
    }
    return (forced, 'SINGLE-PROVIDER MODE (forced=$raw) -> $forced NOT READY ($reason); NO FALLBACK — respecting your choice. Fix IDs/status or switch to Mediation Mode');
  }

  bool adsEnabled(AdsConfig cfg) {
    if (!cfg.monetization.appAdsEnabled) {
      _log('adsEnabled=false: monetization.appAdsEnabled is OFF in admin panel');
      return false;
    }
    final (effective, reason) = _resolveEffectiveProvider(cfg);
    final (ok, detail) = _networkHasAnyAdWithReason(cfg, effective);
    _log('adsEnabled=$ok: effectiveProvider=$effective — $reason — status=$detail');
    return ok;
  }

  AdsNetwork? _pickNetworkFor(_AdKind kind) {
    final cfg = _config;
    if (cfg == null) {
      _log('_pickNetworkFor($kind)=null: no AdsConfig');
      return null;
    }
    if (!cfg.monetization.appAdsEnabled) {
      _log('_pickNetworkFor($kind)=null: appAdsEnabled OFF');
      return null;
    }

    final mediation = _isMediationMode(cfg);
    final (effective, reason) = _resolveEffectiveProvider(cfg);
    _log('_pickNetworkFor($kind): $reason -> effective=$effective (mode=${mediation ? 'mediation' : 'single'})');
    final s = _supportsNetwork(cfg, effective, kind);
    if (s.$1) return effective;
    if (mediation) {
      _log('_pickNetworkFor($kind): effective=$effective not eligible for $kind (${s.$2}); trying smart fallback for this kind (mediation mode)');
      return _smartFallbackProvider(cfg, forKind: kind);
    }
    _log('_pickNetworkFor($kind): effective=$effective not eligible for $kind (${s.$2}); NO FALLBACK (single provider mode respecting user choice)');
    return null;
  }

  AdsNetwork? pickBannerNetwork() => _pickNetworkFor(_AdKind.banner);
  AdsNetwork? pickInterstitialNetwork() => _pickNetworkFor(_AdKind.interstitial);
  AdsNetwork? pickRewardedNetwork() => _pickNetworkFor(_AdKind.rewarded);

  List<AdsNetwork> rankedBannerNetworks({int maxFallbacks = 2}) => _rankedNetworksFor(_AdKind.banner, maxFallbacks: maxFallbacks);
  List<AdsNetwork> rankedInterstitialNetworks({int maxFallbacks = 2}) => _rankedNetworksFor(_AdKind.interstitial, maxFallbacks: maxFallbacks);
  List<AdsNetwork> rankedRewardedNetworks({int maxFallbacks = 2}) => _rankedNetworksFor(_AdKind.rewarded, maxFallbacks: maxFallbacks);

  bool _supportsNetworkBool(AdsConfig cfg, AdsNetwork network, _AdKind kind) => _supportsNetwork(cfg, network, kind).$1;

  Future<void> ensureInitialized(AdsConfig cfg) async {
    if (_initialized) return;
    _config = cfg;
    if (kIsWeb) return;
    if (_supportsNetworkBool(cfg, AdsNetwork.admob, _AdKind.banner) || _supportsNetworkBool(cfg, AdsNetwork.admob, _AdKind.interstitial) || _supportsNetworkBool(cfg, AdsNetwork.admob, _AdKind.rewarded)) {
      await MobileAds.instance.initialize();
    }
    if (_supportsNetworkBool(cfg, AdsNetwork.applovin, _AdKind.banner) || _supportsNetworkBool(cfg, AdsNetwork.applovin, _AdKind.interstitial) || _supportsNetworkBool(cfg, AdsNetwork.applovin, _AdKind.rewarded)) {
      await _initApplovin(cfg);
    }
    if (_supportsNetworkBool(cfg, AdsNetwork.unity, _AdKind.banner) || _supportsNetworkBool(cfg, AdsNetwork.unity, _AdKind.interstitial) || _supportsNetworkBool(cfg, AdsNetwork.unity, _AdKind.rewarded)) {
      await _initUnity(cfg);
    }
    if (_supportsNetworkBool(cfg, AdsNetwork.ironsource, _AdKind.banner) || _supportsNetworkBool(cfg, AdsNetwork.ironsource, _AdKind.interstitial) || _supportsNetworkBool(cfg, AdsNetwork.ironsource, _AdKind.rewarded)) {
      await _initIronSource(cfg);
    }
    _initialized = true;
  }

  Future<void> _initApplovin(AdsConfig cfg) async {
    if (_applovinInitialized) return;
    await applovin.AppLovinMAX.initialize(cfg.applovin.sdkKey);
    _applovinInitialized = true;
  }

  Future<void> _initUnity(AdsConfig cfg) async {
    if (_unityInitialized) {
      _log('[Unity] init skipped (already initialized)');
      return;
    }
    final existing = _unityInitCompleter;
    if (existing != null) {
      _log('[Unity] init in progress, waiting...');
      return existing.future;
    }
    final c = Completer<void>();
    _unityInitCompleter = c;
    _log('[Unity] init start: gameId=${cfg.unity.gameId} testMode=$kDebugMode');
    UnityAds.init(
      gameId: cfg.unity.gameId,
      testMode: kDebugMode,
      onComplete: () {
        _unityInitialized = true;
        _log('[Unity] init SUCCESS');
        unawaited(Future<void>(() async {
          await Future<void>.delayed(const Duration(milliseconds: 500));
          if (cfg.unity.bannerId.isNotEmpty) {
            _log('[Unity] preloading banner: ${cfg.unity.bannerId}');
            unawaited(_unityEnsureLoaded(cfg.unity.bannerId));
          }
          if (cfg.unity.interstitialId.isNotEmpty) {
            _log('[Unity] preloading interstitial: ${cfg.unity.interstitialId}');
            unawaited(_unityEnsureLoaded(cfg.unity.interstitialId));
          }
          if (cfg.unity.rewardedId.isNotEmpty) {
            _log('[Unity] preloading rewarded: ${cfg.unity.rewardedId}');
            unawaited(_unityEnsureLoaded(cfg.unity.rewardedId));
          }
        }));
        if (!c.isCompleted) c.complete();
      },
      onFailed: (UnityAdsInitializationError error, String message) {
        _log('[Unity] init FAILED: error=$error message=$message');
        _unityInitialized = false;
        if (!c.isCompleted) c.complete();
      },
    );
    await c.future;
    _unityInitCompleter = null;
  }

  Future<void> _initIronSource(AdsConfig cfg) async {
    if (_ironsourceInitialized) {
      _log('[IronSource] init skipped (already initialized)');
      return;
    }
    final existing = _ironsourceInitCompleter;
    if (existing != null) {
      _log('[IronSource] init in progress, waiting...');
      return existing.future;
    }
    final c = Completer<void>();
    _ironsourceInitCompleter = c;
    _log('[IronSource] init start: appKey=${cfg.ironsource.appKey} testMode=$kDebugMode');

    try {
      _log('[IronSource] Privacy: skipping GDPR/CCPA explicit calls (managed internally by LevelPlay SDK; integrate real CMP in production if required)');

      final listener = _IronSourceInitListener(
        onSuccess: (config) {
          try {
            _log('[IronSource] init SUCCESS');
          } catch (_) {
            _log('[IronSource] init SUCCESS');
          }
          _ironsourceInitialized = true;
          _ironsourceInterstitial = LevelPlayInterstitialAd(adUnitId: cfg.ironsource.interstitialId);
          _ironsourceRewarded = LevelPlayRewardedAd(adUnitId: cfg.ironsource.rewardedId);
          _log('[IronSource] interstitial adUnitId=${cfg.ironsource.interstitialId}, rewarded adUnitId=${cfg.ironsource.rewardedId}');
          if (!c.isCompleted) c.complete();
        },
        onFailed: (error) {
          _log('[IronSource] init FAILED: errorCode=${error.errorCode}, errorMessage=${error.errorMessage}');
          _ironsourceInitialized = false;
          if (!c.isCompleted) c.complete();
        },
      );
      final initRequest = LevelPlayInitRequest.builder(cfg.ironsource.appKey).build();
      await LevelPlay.init(initRequest: initRequest, initListener: listener);
    } catch (e, st) {
      _log('[IronSource] init EXCEPTION: $e\n$st');
      _ironsourceInitialized = false;
      if (!c.isCompleted) c.complete();
    }

    await c.future;
    _ironsourceInitCompleter = null;
  }

  Future<bool> _waitReady(Future<bool> Function() check, {int attempts = 20, int delayMs = 250}) async {
    for (var i = 0; i < attempts; i++) {
      final ready = await check();
      if (ready) return true;
      await Future<void>.delayed(Duration(milliseconds: delayMs));
    }
    return false;
  }

  /// Pick a full list of eligible networks for an ad kind, ordered by preference.
  /// First element = primary pick (effective provider). Others = runtime fallbacks in case of No Fill (MEDIATION MODE ONLY).
  /// In Single Provider Mode, returns only the primary network even if invalid (respecting user choice).
  List<AdsNetwork> _rankedNetworksFor(_AdKind kind, {int maxFallbacks = 2}) {
    final cfg = _config;
    if (cfg == null) return const [];
    final mediation = _isMediationMode(cfg);
    final primary = _pickNetworkFor(kind);
    final used = <AdsNetwork>{};
    final ranked = <AdsNetwork>[];
    if (primary != null) {
      ranked.add(primary);
      used.add(primary);
    }
    if (!mediation) {
      final logNetworks = ranked.isEmpty ? 'null' : ranked.first.toString();
      _log('rankedNetworksFor($kind): SINGLE PROVIDER MODE -> returning only primary=$logNetworks (no fallbacks, respecting user choice)');
      return ranked;
    }
    final fallbackOrder = <AdsNetwork>[AdsNetwork.unity, AdsNetwork.applovin, AdsNetwork.ironsource, AdsNetwork.admob];
    for (final n in fallbackOrder) {
      if (used.contains(n)) continue;
      final s = _supportsNetwork(cfg, n, kind);
      if (!s.$1) continue;
      ranked.add(n);
      used.add(n);
      if (ranked.length - 1 >= maxFallbacks) break;
    }
    _log('rankedNetworksFor($kind): MEDIATION MODE -> ranked=$ranked');
    return ranked;
  }

  Future<bool> showInterstitial() async {
    final cfg = _config;
    if (cfg == null) return false;
    if (kIsWeb) return false;
    if (!adsEnabled(cfg)) return false;

    final last = _lastInterstitialShownAt;
    if (last != null && DateTime.now().difference(last).inSeconds < 12) {
      return false;
    }
    final lastAny = _lastFullScreenAdShownAt;
    if (lastAny != null && DateTime.now().difference(lastAny).inSeconds < 45) {
      return false;
    }

    final now = DateTime.now();
    _lastInterstitialShownAt = now;
    _lastFullScreenAdShownAt = now;

    final ranked = _rankedNetworksFor(_AdKind.interstitial);
    if (ranked.isEmpty) {
      _log('showInterstitial: no networks ranked for interstitial');
      return false;
    }
    if (ranked.length > 1) {
      _log('showInterstitial: primary=${ranked.first}, runtime fallbacks=${ranked.skip(1).join(', ')} (in case of No Fill)');
    }

    for (var i = 0; i < ranked.length; i++) {
      final network = ranked[i];
      final attempt = i + 1;
      final ok = await switch (network) {
        AdsNetwork.admob => _showAdmobInterstitial(cfg),
        AdsNetwork.applovin => _showApplovinInterstitial(cfg),
        AdsNetwork.unity => _showUnityInterstitial(cfg),
        AdsNetwork.ironsource => _showIronSourceInterstitial(cfg),
      };
      if (ok) {
        if (attempt > 1) _log('showInterstitial: SUCCESS on attempt #$attempt via $network (fallback worked)');
        return true;
      }
      if (attempt < ranked.length) {
        _log('showInterstitial: attempt #$attempt via $network FAILED (No Fill / Timeout). Trying next fallback: ${ranked[attempt]}');
      }
    }
    _log('showInterstitial: FAILED after ${ranked.length} attempts — all eligible networks returned No Fill');
    return false;
  }

  Future<bool> showRewarded({required VoidCallback onEarnedReward, bool requireEarnedReward = true}) async {
    final cfg = _config;
    if (cfg == null) return false;
    if (kIsWeb) return false;
    if (!adsEnabled(cfg)) return false;

    final now = DateTime.now();
    _lastFullScreenAdShownAt = now;

    final ranked = _rankedNetworksFor(_AdKind.rewarded);
    if (ranked.isEmpty) {
      _log('showRewarded: no networks ranked for rewarded');
      return false;
    }
    if (ranked.length > 1) {
      _log('showRewarded: primary=${ranked.first}, runtime fallbacks=${ranked.skip(1).join(', ')} (in case of No Fill)');
    }

    var rewardGiven = false;
    void guardedOnEarned() {
      if (rewardGiven) return;
      rewardGiven = true;
      onEarnedReward();
    }

    for (var i = 0; i < ranked.length; i++) {
      final network = ranked[i];
      final attempt = i + 1;
      final ok = await switch (network) {
        AdsNetwork.admob => _showAdmobRewarded(cfg, onEarnedReward: guardedOnEarned, requireEarnedReward: requireEarnedReward),
        AdsNetwork.applovin => _showApplovinRewarded(cfg, onEarnedReward: guardedOnEarned, requireEarnedReward: requireEarnedReward),
        AdsNetwork.unity => _showUnityRewarded(cfg, onEarnedReward: guardedOnEarned, requireEarnedReward: requireEarnedReward),
        AdsNetwork.ironsource => _showIronSourceRewarded(cfg, onEarnedReward: guardedOnEarned, requireEarnedReward: requireEarnedReward),
      };
      if (ok) {
        if (attempt > 1) _log('showRewarded: SUCCESS on attempt #$attempt via $network (fallback worked)');
        return true;
      }
      if (attempt < ranked.length) {
        _log('showRewarded: attempt #$attempt via $network FAILED (No Fill / Timeout). Trying next fallback: ${ranked[attempt]}');
      }
    }
    _log('showRewarded: FAILED after ${ranked.length} attempts — all eligible networks returned No Fill');
    return false;
  }

  Future<bool> _showAdmobInterstitial(AdsConfig cfg) async {
    if (_admobInterstitial == null && !_loadingAdmobInterstitial) {
      _loadingAdmobInterstitial = true;
      try {
        _admobInterstitial = await _loadAdmobInterstitial(cfg);
      } finally {
        _loadingAdmobInterstitial = false;
      }
    }

    final ad = _admobInterstitial;
    if (ad == null) return false;

    final c = Completer<bool>();
    ad.fullScreenContentCallback = FullScreenContentCallback(
      onAdDismissedFullScreenContent: (ad) {
        ad.dispose();
        _admobInterstitial = null;
        try {
          SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
        } catch (_) {}
        if (!c.isCompleted) c.complete(true);
      },
      onAdFailedToShowFullScreenContent: (ad, _) {
        ad.dispose();
        _admobInterstitial = null;
        try {
          SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
        } catch (_) {}
        if (!c.isCompleted) c.complete(false);
      },
    );
    ad.show();
    return c.future;
  }

  Future<InterstitialAd?> _loadAdmobInterstitial(AdsConfig cfg) async {
    final c = Completer<InterstitialAd?>();
    final unitId = cfg.admob.effectiveInterstitialId(cfg.platform);
    InterstitialAd.load(
      adUnitId: unitId,
      request: const AdRequest(),
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: (ad) async {
          try {
            await ad.setImmersiveMode(true);
          } catch (_) {}
          c.complete(ad);
        },
        onAdFailedToLoad: (_) => c.complete(null),
      ),
    );
    return c.future;
  }

  Future<bool> _showAdmobRewarded(AdsConfig cfg, {required VoidCallback onEarnedReward, required bool requireEarnedReward}) async {
    final ad = await _loadAdmobRewarded(cfg);
    if (ad == null) return false;

    var earned = false;
    var shownAt = DateTime.now();
    _lastFullScreenAdShownAt = shownAt;
    final c = Completer<bool>();
    ad.fullScreenContentCallback = FullScreenContentCallback(
      onAdDismissedFullScreenContent: (ad) {
        ad.dispose();
        try {
          SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
        } catch (_) {}
        final seconds = DateTime.now().difference(shownAt).inSeconds;
        final completed = requireEarnedReward ? earned : (seconds >= 4);
        if (!c.isCompleted) c.complete(completed);
      },
      onAdFailedToShowFullScreenContent: (ad, _) {
        ad.dispose();
        try {
          SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
        } catch (_) {}
        if (!c.isCompleted) c.complete(false);
      },
    );
    ad.show(
      onUserEarnedReward: (_, __) {
        if (earned) return;
        earned = true;
        onEarnedReward();
      },
    );
    return c.future;
  }

  Future<RewardedAd?> _loadAdmobRewarded(AdsConfig cfg) async {
    final c = Completer<RewardedAd?>();
    final unitId = cfg.admob.effectiveRewardedId(cfg.platform);
    RewardedAd.load(
      adUnitId: unitId,
      request: const AdRequest(),
      rewardedAdLoadCallback: RewardedAdLoadCallback(
        onAdLoaded: (ad) async {
          try {
            await ad.setImmersiveMode(true);
          } catch (_) {}
          c.complete(ad);
        },
        onAdFailedToLoad: (_) => c.complete(null),
      ),
    );
    return c.future;
  }

  Future<bool> _showApplovinInterstitial(AdsConfig cfg) async {
    await _initApplovin(cfg);
    final unitId = cfg.applovin.interstitialId;
    final c = Completer<bool>();
    applovin.AppLovinMAX.setInterstitialListener(
      applovin.InterstitialListener(
        onAdLoadedCallback: (_) {},
        onAdDisplayedCallback: (_) {},
        onAdClickedCallback: (_) {},
        onAdHiddenCallback: (ad) {
          if (!c.isCompleted) c.complete(true);
        },
        onAdDisplayFailedCallback: (_, __) {
          if (!c.isCompleted) c.complete(false);
        },
        onAdLoadFailedCallback: (_, __) {
          if (!c.isCompleted) c.complete(false);
        },
      ),
    );
    applovin.AppLovinMAX.loadInterstitial(unitId);
    final ready = await _waitReady(() async => (await applovin.AppLovinMAX.isInterstitialReady(unitId)) == true);
    if (!ready) {
      if (!c.isCompleted) c.complete(false);
      return c.future;
    }
    applovin.AppLovinMAX.showInterstitial(unitId);
    return c.future;
  }

  Future<bool> _showApplovinRewarded(AdsConfig cfg, {required VoidCallback onEarnedReward, required bool requireEarnedReward}) async {
    await _initApplovin(cfg);
    final unitId = cfg.applovin.rewardedId;
    final c = Completer<bool>();
    var earned = false;
    var shownAt = DateTime.now();
    applovin.AppLovinMAX.setRewardedAdListener(
      applovin.RewardedAdListener(
        onAdLoadedCallback: (_) {},
        onAdDisplayedCallback: (_) {},
        onAdClickedCallback: (_) {},
        onAdHiddenCallback: (ad) {
          final seconds = DateTime.now().difference(shownAt).inSeconds;
          final completed = requireEarnedReward ? earned : (seconds >= 4);
          if (!c.isCompleted) c.complete(completed);
        },
        onAdDisplayFailedCallback: (_, __) {
          if (!c.isCompleted) c.complete(false);
        },
        onAdLoadFailedCallback: (_, __) {
          if (!c.isCompleted) c.complete(false);
        },
        onAdReceivedRewardCallback: (_, __) {
          if (earned) return;
          earned = true;
          onEarnedReward();
        },
      ),
    );
    applovin.AppLovinMAX.loadRewardedAd(unitId);
    final ready = await _waitReady(() async => (await applovin.AppLovinMAX.isRewardedAdReady(unitId)) == true);
    if (!ready) {
      if (!c.isCompleted) c.complete(false);
      return c.future;
    }
    shownAt = DateTime.now();
    applovin.AppLovinMAX.showRewardedAd(unitId);
    return c.future;
  }

  Future<bool> _showUnityInterstitial(AdsConfig cfg) async {
    await _initUnity(cfg);
    if (!_unityInitialized) {
      _log('[Unity] showInterstitial aborted: init failed or never completed');
      return false;
    }
    final placementId = cfg.unity.interstitialId;
    _log('[Unity] showInterstitial: placement=$placementId');
    final ok = await _unityEnsureLoaded(placementId);
    if (!ok) {
      _log('[Unity] showInterstitial failed: ad not ready after load');
      return false;
    }
    final c = Completer<bool>();
    _unityLoaded[placementId] = false;
    UnityAds.showVideoAd(
      placementId: placementId,
      onStart: (String p) => _log('[Unity] showInterstitial onStart: $p'),
      onComplete: (String p) {
        _log('[Unity] showInterstitial onComplete: $p');
        unawaited(_unityEnsureLoaded(placementId));
        if (!c.isCompleted) c.complete(true);
      },
      onSkipped: (String p) {
        _log('[Unity] showInterstitial onSkipped: $p');
        unawaited(_unityEnsureLoaded(placementId));
        if (!c.isCompleted) c.complete(true);
      },
      onFailed: (String p, UnityAdsShowError e, String m) {
        _log('[Unity] showInterstitial FAILED: $p error=$e message=$m');
        unawaited(_unityEnsureLoaded(placementId));
        if (!c.isCompleted) c.complete(false);
      },
    );
    return c.future;
  }

  Future<bool> _showUnityRewarded(AdsConfig cfg, {required VoidCallback onEarnedReward, required bool requireEarnedReward}) async {
    await _initUnity(cfg);
    if (!_unityInitialized) {
      _log('[Unity] showRewarded aborted: init failed or never completed');
      return false;
    }
    final placementId = cfg.unity.rewardedId;
    _log('[Unity] showRewarded: placement=$placementId requireEarned=$requireEarnedReward');
    final ok = await _unityEnsureLoaded(placementId);
    if (!ok) {
      _log('[Unity] showRewarded failed: ad not ready after load');
      return false;
    }
    final c = Completer<bool>();
    var earned = false;
    var shownAt = DateTime.now();
    _unityLoaded[placementId] = false;
    UnityAds.showVideoAd(
      placementId: placementId,
      onStart: (String p) {
        shownAt = DateTime.now();
        _log('[Unity] showRewarded onStart: $p');
      },
      onComplete: (String p) {
        _log('[Unity] showRewarded onComplete: $p');
        if (!earned) {
          earned = true;
          onEarnedReward();
        }
        unawaited(_unityEnsureLoaded(placementId));
        if (!c.isCompleted) c.complete(true);
      },
      onSkipped: (String p) {
        _log('[Unity] showRewarded onSkipped: $p');
        unawaited(_unityEnsureLoaded(placementId));
        final seconds = DateTime.now().difference(shownAt).inSeconds;
        final completed = requireEarnedReward ? earned : (seconds >= 4);
        _log('[Unity] showRewarded skipped: earned=$earned elapsed=${seconds}s completed=$completed');
        if (!c.isCompleted) c.complete(completed);
      },
      onFailed: (String p, UnityAdsShowError e, String m) {
        _log('[Unity] showRewarded FAILED: $p error=$e message=$m');
        unawaited(_unityEnsureLoaded(placementId));
        if (!c.isCompleted) c.complete(false);
      },
    );
    return c.future;
  }

  Future<bool> _unityEnsureLoaded(String placementId) async {
    if (_unityLoaded[placementId] == true) {
      _log('[Unity] already loaded: $placementId');
      return true;
    }
    _log('[Unity] load() placement=$placementId');
    final c = Completer<bool>();
    UnityAds.load(
      placementId: placementId,
      onComplete: (String p) {
        _unityLoaded[placementId] = true;
        _log('[Unity] load SUCCESS: $p');
        if (!c.isCompleted) c.complete(true);
      },
      onFailed: (String p, UnityAdsLoadError e, String m) {
        _log('[Unity] load FAILED: $p error=$e message=$m');
        if (!c.isCompleted) c.complete(false);
      },
    );
    return c.future;
  }

  Future<bool> _showIronSourceInterstitial(AdsConfig cfg) async {
    await _initIronSource(cfg);
    if (!_ironsourceInitialized) {
      _log('[IronSource] showInterstitial ABORT: init failed or never completed');
      return false;
    }
    final ad = _ironsourceInterstitial;
    if (ad == null) {
      _log('[IronSource] showInterstitial ABORT: interstitial ad object is null');
      return false;
    }
    final adUnitId = cfg.ironsource.interstitialId;
    _log('[IronSource] showInterstitial start: adUnitId=$adUnitId');

    final loadedC = Completer<void>.sync();
    final failedC = Completer<void>.sync();
    final resultC = Completer<bool>();

    ad.setListener(
      _IronSourceInterstitialListener(
        onLoaded: (info) {
          _log('[IronSource] interstitial onAdLoaded: adUnitId=${info.adUnitId}');
          if (!loadedC.isCompleted) loadedC.complete();
        },
        onDisplayed: (info) {
          _log('[IronSource] interstitial onAdDisplayed: adUnitId=${info.adUnitId}');
        },
        onClosed: (info) {
          _log('[IronSource] interstitial onAdClosed: adUnitId=${info.adUnitId}');
          if (!resultC.isCompleted) resultC.complete(true);
        },
        onDisplayFailed: (error, info) {
          _log('[IronSource] interstitial onAdDisplayFailed: adUnitId=${info.adUnitId} errorCode=${error.errorCode} errorMessage=${error.errorMessage}');
          if (!resultC.isCompleted) resultC.complete(false);
        },
        onLoadFailed: (error) {
          _log('[IronSource] interstitial onAdLoadFailed: errorCode=${error.errorCode} errorMessage=${error.errorMessage}');
          if (!failedC.isCompleted) failedC.complete();
        },
        onClicked: (info) {
          _log('[IronSource] interstitial onAdClicked: adUnitId=${info.adUnitId}');
        },
        onFailed: () {
          if (!failedC.isCompleted) failedC.complete();
          if (!resultC.isCompleted) resultC.complete(false);
        },
      ),
    );

    try {
      _log('[IronSource] interstitial calling loadAd()...');
      ad.loadAd();
    } catch (e, st) {
      _log('[IronSource] interstitial loadAd EXCEPTION: $e\n$st');
      if (!resultC.isCompleted) resultC.complete(false);
      return resultC.future;
    }

    // Callback-first strategy: wait for onAdLoaded or onAdLoadFailed.
    // Fallback to isAdReady polling only if the plugin silently swallows the callback.
    const safetyTimeoutMs = 15000;
    const tickMs = 1000;
    var waited = 0;
    var loadedByCallback = false;
    var failedByCallback = false;

    while (waited < safetyTimeoutMs) {
      if (loadedC.isCompleted) {
        loadedByCallback = true;
        break;
      }
      if (failedC.isCompleted) {
        failedByCallback = true;
        break;
      }
      try {
        final ready = await ad.isAdReady();
        if (ready) {
          _log('[IronSource] interstitial isAdReady=true via polling (callback may have been missed)');
          loadedByCallback = true;
          break;
        }
      } catch (e) {
        _log('[IronSource] interstitial isAdReady poll warning: $e');
      }
      if (waited > 0 && waited % 2000 == 0) {
        _log('[IronSource] interstitial still loading... waited ${(waited / 1000).toStringAsFixed(0)}s');
      }
      await Future<void>.delayed(const Duration(milliseconds: tickMs));
      waited += tickMs;
    }

    if (!loadedByCallback) {
      if (failedByCallback) {
        _log('[IronSource] interstitial FAILED: onAdLoadFailed fired via callback');
      } else {
        _log('[IronSource] interstitial FAILED: not ready after ${(safetyTimeoutMs / 1000).toStringAsFixed(0)}s safety timeout');
      }
      if (!resultC.isCompleted) resultC.complete(false);
      return resultC.future;
    }

    _log('[IronSource] interstitial ready — calling showAd()...');
    try {
      ad.showAd();
    } catch (e, st) {
      _log('[IronSource] interstitial showAd EXCEPTION: $e\n$st');
      if (!resultC.isCompleted) resultC.complete(false);
    }
    return resultC.future.timeout(
      const Duration(seconds: 45),
      onTimeout: () {
        _log('[IronSource] interstitial showAd TIMEOUT after 45s (user may never closed ad)');
        return true;
      },
    );
  }

  Future<bool> _showIronSourceRewarded(AdsConfig cfg, {required VoidCallback onEarnedReward, required bool requireEarnedReward}) async {
    await _initIronSource(cfg);
    if (!_ironsourceInitialized) {
      _log('[IronSource] showRewarded ABORT: init failed or never completed');
      return false;
    }
    final ad = _ironsourceRewarded;
    if (ad == null) {
      _log('[IronSource] showRewarded ABORT: rewarded ad object is null');
      return false;
    }
    final adUnitId = cfg.ironsource.rewardedId;
    _log('[IronSource] showRewarded start: adUnitId=$adUnitId requireEarned=$requireEarnedReward');

    final loadedC = Completer<void>.sync();
    final failedC = Completer<void>.sync();
    final resultC = Completer<bool>();

    var earned = false;
    var shownAt = DateTime.now();

    ad.setListener(
      _IronSourceRewardedListener(
        onLoaded: (info) {
          _log('[IronSource] rewarded onAdLoaded: adUnitId=${info.adUnitId}');
          if (!loadedC.isCompleted) loadedC.complete();
        },
        onDisplayed: (info) {
          _log('[IronSource] rewarded onAdDisplayed: adUnitId=${info.adUnitId}');
          shownAt = DateTime.now();
        },
        onRewarded: () {
          _log('[IronSource] rewarded onRewarded: user earned reward');
          if (earned) return;
          earned = true;
          onEarnedReward();
        },
        onClosed: (info) {
          _log('[IronSource] rewarded onAdClosed: adUnitId=${info.adUnitId}');
          final seconds = DateTime.now().difference(shownAt).inSeconds;
          final completed = requireEarnedReward ? earned : (seconds >= 4);
          _log('[IronSource] rewarded closed: seconds=$seconds earned=$earned requireEarned=$requireEarnedReward completed=$completed');
          if (!resultC.isCompleted) resultC.complete(completed);
        },
        onDisplayFailed: (error, info) {
          _log('[IronSource] rewarded onAdDisplayFailed: adUnitId=${info.adUnitId} errorCode=${error.errorCode} errorMessage=${error.errorMessage}');
          if (!resultC.isCompleted) resultC.complete(false);
        },
        onLoadFailed: (error) {
          _log('[IronSource] rewarded onAdLoadFailed: errorCode=${error.errorCode} errorMessage=${error.errorMessage}');
          if (!failedC.isCompleted) failedC.complete();
        },
        onClicked: (info) {
          _log('[IronSource] rewarded onAdClicked: adUnitId=${info.adUnitId}');
        },
        onFailed: () {
          if (!failedC.isCompleted) failedC.complete();
          if (!resultC.isCompleted) resultC.complete(false);
        },
        onDisplayedLegacy: () {
          shownAt = DateTime.now();
        },
      ),
    );

    try {
      _log('[IronSource] rewarded calling loadAd()...');
      ad.loadAd();
    } catch (e, st) {
      _log('[IronSource] rewarded loadAd EXCEPTION: $e\n$st');
      if (!resultC.isCompleted) resultC.complete(false);
      return resultC.future;
    }

    // Callback-first strategy (same as interstitial)
    const safetyTimeoutMs = 15000;
    const tickMs = 1000;
    var waited = 0;
    var loadedByCallback = false;
    var failedByCallback = false;

    while (waited < safetyTimeoutMs) {
      if (loadedC.isCompleted) {
        loadedByCallback = true;
        break;
      }
      if (failedC.isCompleted) {
        failedByCallback = true;
        break;
      }
      try {
        final ready = await ad.isAdReady();
        if (ready) {
          _log('[IronSource] rewarded isAdReady=true via polling (callback may have been missed)');
          loadedByCallback = true;
          break;
        }
      } catch (e) {
        _log('[IronSource] rewarded isAdReady poll warning: $e');
      }
      if (waited > 0 && waited % 2000 == 0) {
        _log('[IronSource] rewarded still loading... waited ${(waited / 1000).toStringAsFixed(0)}s');
      }
      await Future<void>.delayed(const Duration(milliseconds: tickMs));
      waited += tickMs;
    }

    if (!loadedByCallback) {
      if (failedByCallback) {
        _log('[IronSource] rewarded FAILED: onAdLoadFailed fired via callback');
      } else {
        _log('[IronSource] rewarded FAILED: not ready after ${(safetyTimeoutMs / 1000).toStringAsFixed(0)}s safety timeout');
      }
      if (!resultC.isCompleted) resultC.complete(false);
      return resultC.future;
    }

    _log('[IronSource] rewarded ready — calling showAd()...');
    shownAt = DateTime.now();
    try {
      ad.showAd();
    } catch (e, st) {
      _log('[IronSource] rewarded showAd EXCEPTION: $e\n$st');
      if (!resultC.isCompleted) resultC.complete(false);
    }
    return resultC.future.timeout(
      const Duration(seconds: 90),
      onTimeout: () {
        _log('[IronSource] rewarded showAd TIMEOUT after 90s');
        return requireEarnedReward ? earned : true;
      },
    );
  }
}

class _IronSourceInitListener with LevelPlayInitListener {
  _IronSourceInitListener({required this.onSuccess, required this.onFailed});

  final void Function(LevelPlayConfiguration configuration) onSuccess;
  final void Function(LevelPlayInitError error) onFailed;

  @override
  void onInitFailed(LevelPlayInitError error) => onFailed(error);

  @override
  void onInitSuccess(LevelPlayConfiguration configuration) => onSuccess(configuration);
}

class _IronSourceInterstitialListener with LevelPlayInterstitialAdListener {
  _IronSourceInterstitialListener({
    required this.onLoaded,
    required this.onDisplayed,
    required this.onClosed,
    required this.onDisplayFailed,
    required this.onLoadFailed,
    required this.onClicked,
    required this.onFailed,
  });

  final void Function(LevelPlayAdInfo adInfo) onLoaded;
  final void Function(LevelPlayAdInfo adInfo) onDisplayed;
  final void Function(LevelPlayAdInfo adInfo) onClosed;
  final void Function(LevelPlayAdError error, LevelPlayAdInfo adInfo) onDisplayFailed;
  final void Function(LevelPlayAdError error) onLoadFailed;
  final void Function(LevelPlayAdInfo adInfo) onClicked;
  final VoidCallback onFailed;

  @override
  void onAdLoaded(LevelPlayAdInfo adInfo) => onLoaded(adInfo);

  @override
  void onAdInfoChanged(LevelPlayAdInfo adInfo) {}

  @override
  void onAdDisplayed(LevelPlayAdInfo adInfo) => onDisplayed(adInfo);

  @override
  void onAdClicked(LevelPlayAdInfo adInfo) => onClicked(adInfo);

  @override
  void onAdClosed(LevelPlayAdInfo adInfo) => onClosed(adInfo);

  @override
  void onAdDisplayFailed(LevelPlayAdError error, LevelPlayAdInfo adInfo) => onDisplayFailed(error, adInfo);

  @override
  void onAdLoadFailed(LevelPlayAdError error) => onLoadFailed(error);
}

class _IronSourceRewardedListener with LevelPlayRewardedAdListener {
  _IronSourceRewardedListener({
    required this.onLoaded,
    required this.onDisplayed,
    required this.onRewarded,
    required this.onClosed,
    required this.onDisplayFailed,
    required this.onLoadFailed,
    required this.onClicked,
    required this.onFailed,
    required this.onDisplayedLegacy,
  });

  final void Function(LevelPlayAdInfo adInfo) onLoaded;
  final void Function(LevelPlayAdInfo adInfo) onDisplayed;
  final VoidCallback onRewarded;
  final void Function(LevelPlayAdInfo adInfo) onClosed;
  final void Function(LevelPlayAdError error, LevelPlayAdInfo adInfo) onDisplayFailed;
  final void Function(LevelPlayAdError error) onLoadFailed;
  final void Function(LevelPlayAdInfo adInfo) onClicked;
  final VoidCallback onFailed;
  final VoidCallback onDisplayedLegacy;

  @override
  void onAdLoaded(LevelPlayAdInfo adInfo) => onLoaded(adInfo);

  @override
  void onAdInfoChanged(LevelPlayAdInfo adInfo) {}

  @override
  void onAdClicked(LevelPlayAdInfo adInfo) => onClicked(adInfo);

  @override
  void onAdDisplayed(LevelPlayAdInfo adInfo) {
    onDisplayed(adInfo);
    onDisplayedLegacy();
  }

  @override
  void onAdClosed(LevelPlayAdInfo adInfo) => onClosed(adInfo);

  @override
  void onAdDisplayFailed(LevelPlayAdError error, LevelPlayAdInfo adInfo) => onDisplayFailed(error, adInfo);

  @override
  void onAdLoadFailed(LevelPlayAdError error) => onLoadFailed(error);

  @override
  void onAdRewarded(LevelPlayReward reward, LevelPlayAdInfo adInfo) => onRewarded();
}
