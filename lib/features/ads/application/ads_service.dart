import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:applovin_max/applovin_max.dart' as applovin;
import 'package:google_mobile_ads/google_mobile_ads.dart' as admob_ads;
import 'package:unity_ads_plugin/unity_ads_plugin.dart';
import 'package:unity_levelplay_mediation/unity_levelplay_mediation.dart';
import 'package:wortise/wortise.dart' as wortise_ads;

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

  admob_ads.InterstitialAd? _admobInterstitial;
  bool _loadingAdmobInterstitial = false;

  bool _applovinInitialized = false;
  bool _unityInitialized = false;
  bool _ironsourceInitialized = false;
  bool _wortiseInitialized = false;

  final Map<String, bool> _unityLoaded = <String, bool>{};
  Completer<void>? _unityInitCompleter;
  Completer<void>? _ironsourceInitCompleter;
  Completer<void>? _wortiseInitCompleter;

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
      'wortise' => AdsNetwork.wortise,
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
      AdsNetwork.wortise => cfg.wortise.enabled,
    };
  }

  (bool, String) _supportsNetwork(AdsConfig cfg, AdsNetwork network, _AdKind kind) {
    if (!_isNetworkEnabled(cfg, network)) return (false, 'disabled');
    return switch (network) {
      AdsNetwork.admob => (true, ''),
      AdsNetwork.applovin => _checkIds(cfg.applovin.sdkKey, kind == _AdKind.banner ? cfg.applovin.bannerId : kind == _AdKind.interstitial ? cfg.applovin.interstitialId : cfg.applovin.rewardedId, kind),
      AdsNetwork.unity => _checkIds(cfg.unity.gameId, kind == _AdKind.banner ? cfg.unity.bannerId : kind == _AdKind.interstitial ? cfg.unity.interstitialId : cfg.unity.rewardedId, kind),
      AdsNetwork.ironsource => _checkIds(cfg.ironsource.appKey, kind == _AdKind.banner ? cfg.ironsource.bannerId : kind == _AdKind.interstitial ? cfg.ironsource.interstitialId : cfg.ironsource.rewardedId, kind),
      AdsNetwork.wortise => _checkIds(cfg.wortise.appId, kind == _AdKind.banner ? cfg.wortise.bannerId : kind == _AdKind.interstitial ? cfg.wortise.interstitialId : cfg.wortise.rewardedId, kind),
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
    final candidates = <AdsNetwork>[AdsNetwork.unity, AdsNetwork.applovin, AdsNetwork.ironsource, AdsNetwork.wortise, AdsNetwork.admob];
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
      await admob_ads.MobileAds.instance.initialize();
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
    if (_supportsNetworkBool(cfg, AdsNetwork.wortise, _AdKind.banner) || _supportsNetworkBool(cfg, AdsNetwork.wortise, _AdKind.interstitial) || _supportsNetworkBool(cfg, AdsNetwork.wortise, _AdKind.rewarded)) {
      await _initWortise(cfg);
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
      final listener = _IronSourceInitListener(
        onSuccess: (config) {
          _log('[IronSource] init SUCCESS');
          _ironsourceInitialized = true;
          _ironsourceInterstitial = LevelPlayInterstitialAd(adUnitId: cfg.ironsource.interstitialId);
          _ironsourceRewarded = LevelPlayRewardedAd(adUnitId: cfg.ironsource.rewardedId);
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

  Future<void> _initWortise(AdsConfig cfg) async {
    if (_wortiseInitialized) {
      _log('[Wortise] init skipped (already initialized)');
      return;
    }
    final existing = _wortiseInitCompleter;
    if (existing != null) {
      _log('[Wortise] init in progress, waiting...');
      return existing.future;
    }
    final c = Completer<void>();
    _wortiseInitCompleter = c;
    _log('[Wortise] init start: appId=${cfg.wortise.appId}');
    try {
      // Inisialisasi resmi sesuai dokumentasi Wortise SDK Flutter: WortiseSdk.initialize(appId)
      await wortise_ads.WortiseSdk.initialize(cfg.wortise.appId);
      
      // Mengaktifkan mode test jika aplikasi berjalan di environment debug (kDebugMode)
      await wortise_ads.AdSettings.setTestEnabled(kDebugMode);

      _wortiseInitialized = true;
      _log('[Wortise] init SUCCESS');
    } catch (e, st) {
      _log('[Wortise] init FAILED: $e\n$st');
      _wortiseInitialized = false;
    } finally {
      if (!c.isCompleted) c.complete();
    }
    await c.future;
    _wortiseInitCompleter = null;
  }

  Future<bool> _waitReady(Future<bool> Function() check, {int attempts = 20, int delayMs = 250}) async {
    for (var i = 0; i < attempts; i++) {
      final ready = await check();
      if (ready) return true;
      await Future<void>.delayed(Duration(milliseconds: delayMs));
    }
    return false;
  }

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
      return ranked;
    }
    final fallbackOrder = <AdsNetwork>[AdsNetwork.unity, AdsNetwork.applovin, AdsNetwork.ironsource, AdsNetwork.wortise, AdsNetwork.admob];
    for (final n in fallbackOrder) {
      if (used.contains(n)) continue;
      final s = _supportsNetwork(cfg, n, kind);
      if (!s.$1) continue;
      ranked.add(n);
      used.add(n);
      if (ranked.length - 1 >= maxFallbacks) break;
    }
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
    if (ranked.isEmpty) return false;

    for (var i = 0; i < ranked.length; i++) {
      final network = ranked[i];
      final ok = await switch (network) {
        AdsNetwork.admob => _showAdmobInterstitial(cfg),
        AdsNetwork.applovin => _showApplovinInterstitial(cfg),
        AdsNetwork.unity => _showUnityInterstitial(cfg),
        AdsNetwork.ironsource => _showIronSourceInterstitial(cfg),
        AdsNetwork.wortise => _showWortiseInterstitial(cfg),
      };
      if (ok) return true;
    }
    return false;
  }

  Future<bool> showRewarded({required VoidCallback onEarnedReward, bool requireEarnedReward = true}) async {
    final cfg = _config;
    if (cfg == null) return false;
    if (kIsWeb) return false;
    if (!adsEnabled(cfg)) return false;

    _lastFullScreenAdShownAt = DateTime.now();

    final ranked = _rankedNetworksFor(_AdKind.rewarded);
    if (ranked.isEmpty) return false;

    var rewardGiven = false;
    void guardedOnEarned() {
      if (rewardGiven) return;
      rewardGiven = true;
      onEarnedReward();
    }

    for (var i = 0; i < ranked.length; i++) {
      final network = ranked[i];
      final ok = await switch (network) {
        AdsNetwork.admob => _showAdmobRewarded(cfg, onEarnedReward: guardedOnEarned, requireEarnedReward: requireEarnedReward),
        AdsNetwork.applovin => _showApplovinRewarded(cfg, onEarnedReward: guardedOnEarned, requireEarnedReward: requireEarnedReward),
        AdsNetwork.unity => _showUnityRewarded(cfg, onEarnedReward: guardedOnEarned, requireEarnedReward: requireEarnedReward),
        AdsNetwork.ironsource => _showIronSourceRewarded(cfg, onEarnedReward: guardedOnEarned, requireEarnedReward: requireEarnedReward),
        AdsNetwork.wortise => _showWortiseRewarded(cfg, onEarnedReward: guardedOnEarned, requireEarnedReward: requireEarnedReward),
      };
      if (ok) return true;
    }
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
    ad.fullScreenContentCallback = admob_ads.FullScreenContentCallback(
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

  Future<admob_ads.InterstitialAd?> _loadAdmobInterstitial(AdsConfig cfg) async {
    final c = Completer<admob_ads.InterstitialAd?>();
    final unitId = cfg.admob.effectiveInterstitialId(cfg.platform);
    admob_ads.InterstitialAd.load(
      adUnitId: unitId,
      request: const admob_ads.AdRequest(),
      adLoadCallback: admob_ads.InterstitialAdLoadCallback(
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
    ad.fullScreenContentCallback = admob_ads.FullScreenContentCallback(
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

  Future<admob_ads.RewardedAd?> _loadAdmobRewarded(AdsConfig cfg) async {
    final c = Completer<admob_ads.RewardedAd?>();
    final unitId = cfg.admob.effectiveRewardedId(cfg.platform);
    admob_ads.RewardedAd.load(
      adUnitId: unitId,
      request: const admob_ads.AdRequest(),
      rewardedAdLoadCallback: admob_ads.RewardedAdLoadCallback(
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
        onAdHiddenCallback: (_) {
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
        onAdHiddenCallback: (_) {
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
    applovin.AppLovinMAX.showRewardedAd(unitId);
    return c.future;
  }

  Future<bool> _showUnityInterstitial(AdsConfig cfg) async {
    await _initUnity(cfg);
    if (!_unityInitialized) return false;
    final placementId = cfg.unity.interstitialId;
    final ok = await _unityEnsureLoaded(placementId);
    if (!ok) return false;
    final c = Completer<bool>();
    _unityLoaded[placementId] = false;
    UnityAds.showVideoAd(
      placementId: placementId,
      onStart: (_) {},
      onComplete: (_) {
        unawaited(_unityEnsureLoaded(placementId));
        if (!c.isCompleted) c.complete(true);
      },
      onSkipped: (_) {
        unawaited(_unityEnsureLoaded(placementId));
        if (!c.isCompleted) c.complete(true);
      },
      onFailed: (_, __, ___) {
        unawaited(_unityEnsureLoaded(placementId));
        if (!c.isCompleted) c.complete(false);
      },
    );
    return c.future;
  }

  Future<bool> _showUnityRewarded(AdsConfig cfg, {required VoidCallback onEarnedReward, required bool requireEarnedReward}) async {
    await _initUnity(cfg);
    if (!_unityInitialized) return false;
    final placementId = cfg.unity.rewardedId;
    final ok = await _unityEnsureLoaded(placementId);
    if (!ok) return false;
    final c = Completer<bool>();
    var earned = false;
    var shownAt = DateTime.now();
    _unityLoaded[placementId] = false;
    UnityAds.showVideoAd(
      placementId: placementId,
      onStart: (_) => shownAt = DateTime.now(),
      onComplete: (_) {
        if (!earned) {
          earned = true;
          onEarnedReward();
        }
        unawaited(_unityEnsureLoaded(placementId));
        if (!c.isCompleted) c.complete(true);
      },
      onSkipped: (_) {
        unawaited(_unityEnsureLoaded(placementId));
        final seconds = DateTime.now().difference(shownAt).inSeconds;
        final completed = requireEarnedReward ? earned : (seconds >= 4);
        if (!c.isCompleted) c.complete(completed);
      },
      onFailed: (_, __, ___) {
        unawaited(_unityEnsureLoaded(placementId));
        if (!c.isCompleted) c.complete(false);
      },
    );
    return c.future;
  }

  Future<bool> _unityEnsureLoaded(String placementId) async {
    if (_unityLoaded[placementId] == true) return true;
    final c = Completer<bool>();
    UnityAds.load(
      placementId: placementId,
      onComplete: (_) {
        _unityLoaded[placementId] = true;
        if (!c.isCompleted) c.complete(true);
      },
      onFailed: (_, __, ___) {
        if (!c.isCompleted) c.complete(false);
      },
    );
    return c.future;
  }

  Future<bool> _showIronSourceInterstitial(AdsConfig cfg) async {
    await _initIronSource(cfg);
    if (!_ironsourceInitialized) return false;
    final ad = _ironsourceInterstitial;
    if (ad == null) return false;

    final loadedC = Completer<void>.sync();
    final failedC = Completer<void>.sync();
    final resultC = Completer<bool>();

    ad.setListener(
      _IronSourceInterstitialListener(
        onLoaded: (_) {
          if (!loadedC.isCompleted) loadedC.complete();
        },
        onDisplayed: (_) {},
        onClosed: (_) {
          if (!resultC.isCompleted) resultC.complete(true);
        },
        onDisplayFailed: (_, __) {
          if (!resultC.isCompleted) resultC.complete(false);
        },
        onLoadFailed: (_) {
          if (!failedC.isCompleted) failedC.complete();
        },
        onClicked: (_) {},
        onFailed: () {
          if (!failedC.isCompleted) failedC.complete();
          if (!resultC.isCompleted) resultC.complete(false);
        },
      ),
    );

    try {
      ad.loadAd();
    } catch (_) {
      if (!resultC.isCompleted) resultC.complete(false);
      return resultC.future;
    }

    const safetyTimeoutMs = 15000;
    const tickMs = 1000;
    var waited = 0;
    var loadedByCallback = false;

    while (waited < safetyTimeoutMs) {
      if (loadedC.isCompleted || failedC.isCompleted) {
        loadedByCallback = loadedC.isCompleted;
        break;
      }
      try {
        if (await ad.isAdReady()) {
          loadedByCallback = true;
          break;
        }
      } catch (_) {}
      await Future<void>.delayed(const Duration(milliseconds: tickMs));
      waited += tickMs;
    }

    if (!loadedByCallback) {
      if (!resultC.isCompleted) resultC.complete(false);
      return resultC.future;
    }

    try {
      ad.showAd();
    } catch (_) {
      if (!resultC.isCompleted) resultC.complete(false);
    }
    return resultC.future.timeout(const Duration(seconds: 45), onTimeout: () => true);
  }

  Future<bool> _showIronSourceRewarded(AdsConfig cfg, {required VoidCallback onEarnedReward, required bool requireEarnedReward}) async {
    await _initIronSource(cfg);
    if (!_ironsourceInitialized) return false;
    final ad = _ironsourceRewarded;
    if (ad == null) return false;

    final loadedC = Completer<void>.sync();
    final failedC = Completer<void>.sync();
    final resultC = Completer<bool>();

    var earned = false;
    var shownAt = DateTime.now();

    ad.setListener(
      _IronSourceRewardedListener(
        onLoaded: (_) {
          if (!loadedC.isCompleted) loadedC.complete();
        },
        onDisplayed: (_) => shownAt = DateTime.now(),
        onRewarded: () {
          if (earned) return;
          earned = true;
          onEarnedReward();
        },
        onClosed: (_) {
          final seconds = DateTime.now().difference(shownAt).inSeconds;
          final completed = requireEarnedReward ? earned : (seconds >= 4);
          if (!resultC.isCompleted) resultC.complete(completed);
        },
        onDisplayFailed: (_, __) {
          if (!resultC.isCompleted) resultC.complete(false);
        },
        onLoadFailed: (_) {
          if (!failedC.isCompleted) failedC.complete();
        },
        onClicked: (_) {},
        onFailed: () {
          if (!failedC.isCompleted) failedC.complete();
          if (!resultC.isCompleted) resultC.complete(false);
        },
        onDisplayedLegacy: () => shownAt = DateTime.now(),
      ),
    );

    try {
      ad.loadAd();
    } catch (_) {
      if (!resultC.isCompleted) resultC.complete(false);
      return resultC.future;
    }

    const safetyTimeoutMs = 15000;
    const tickMs = 1000;
    var waited = 0;
    var loadedByCallback = false;

    while (waited < safetyTimeoutMs) {
      if (loadedC.isCompleted || failedC.isCompleted) {
        loadedByCallback = loadedC.isCompleted;
        break;
      }
      try {
        if (await ad.isAdReady()) {
          loadedByCallback = true;
          break;
        }
      } catch (_) {}
      await Future<void>.delayed(const Duration(milliseconds: tickMs));
      waited += tickMs;
    }

    if (!loadedByCallback) {
      if (!resultC.isCompleted) resultC.complete(false);
      return resultC.future;
    }

    shownAt = DateTime.now();
    try {
      ad.showAd();
    } catch (_) {
      if (!resultC.isCompleted) resultC.complete(false);
    }
    return resultC.future.timeout(
      const Duration(seconds: 90),
      onTimeout: () => requireEarnedReward ? earned : true,
    );
  }

  Future<bool> _showWortiseInterstitial(AdsConfig cfg) async {
    await _initWortise(cfg);
    if (!_wortiseInitialized) return false;

    final unitId = cfg.wortise.interstitialId;
    if (unitId.trim().isEmpty) return false;

    final interstitialAd = wortise_ads.InterstitialAd(unitId: unitId);
    final c = Completer<bool>();

    interstitialAd.onLoaded = () => interstitialAd.show();
    interstitialAd.onFailedToLoad = (_) {
      if (!c.isCompleted) c.complete(false);
    };
    interstitialAd.onDismissed = () {
      if (!c.isCompleted) c.complete(true);
    };

    interstitialAd.load();
    return c.future.timeout(const Duration(seconds: 30), onTimeout: () => false);
  }

  Future<bool> _showWortiseRewarded(AdsConfig cfg, {required VoidCallback onEarnedReward, required bool requireEarnedReward}) async {
    await _initWortise(cfg);
    if (!_wortiseInitialized) return false;

    final unitId = cfg.wortise.rewardedId;
    if (unitId.trim().isEmpty) return false;

    final rewardedAd = wortise_ads.RewardedAd(unitId: unitId);
    final c = Completer<bool>();
    var earned = false;

    rewardedAd.onLoaded = () => rewardedAd.show();
    rewardedAd.onFailedToLoad = (_) {
      if (!c.isCompleted) c.complete(false);
    };
    rewardedAd.onRewarded = () {
      earned = true;
      onEarnedReward();
    };
    rewardedAd.onDismissed = () {
      final completed = requireEarnedReward ? earned : true;
      if (!c.isCompleted) c.complete(completed);
    };

    rewardedAd.load();
    return c.future.timeout(const Duration(seconds: 30), onTimeout: () => requireEarnedReward ? earned : false);
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
  final void Function(LevelPlayAdInfo adInfo) on`Displayed;
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
