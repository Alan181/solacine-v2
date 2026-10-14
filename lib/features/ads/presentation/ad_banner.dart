import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:applovin_max/applovin_max.dart' as applovin;
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:unity_ads_plugin/unity_ads_plugin.dart' hide BannerSize;
import 'package:unity_levelplay_mediation/unity_levelplay_mediation.dart';

import '../application/ads_initializer.dart';
import '../application/ads_providers.dart';
import '../data/ads_config.dart';

void _log(String message) {}

class AdBanner extends ConsumerStatefulWidget {
  const AdBanner({super.key});

  @override
  ConsumerState<AdBanner> createState() => _AdBannerState();
}

class _AdBannerState extends ConsumerState<AdBanner> {
  BannerAd? _ad;
  bool _admobLoaded = false;
  AdsNetwork? _currentNetwork;
  final Map<AdsNetwork, Object> _failedNetworks = <AdsNetwork, Object>{};

  final GlobalKey<LevelPlayBannerAdViewState> _ironBannerKey =
      GlobalKey<LevelPlayBannerAdViewState>();
  bool _ironSdkReady = false;
  bool _ironLoadScheduled = false;
  bool _ironLoaded = false;
  double? _ironHeight;
  int _ironLoadAttempts = 0;
  static const int _kIronMaxLoadAttempts = 5;

  @override
  void dispose() {
    _ad?.dispose();
    super.dispose();
  }

  Future<void> _ensureIronInitialized() async {
    if (!mounted) return;
    final networkNow = _currentNetwork;
    if (networkNow != AdsNetwork.ironsource) {
      _log('IronSource banner: skipped init — current network is $networkNow, not ironsource');
      return;
    }
    if (_ironSdkReady) return;
    final cfg = ref.read(adsConfigProvider);
    if (cfg == null) return;
    final service = ref.read(adsServiceProvider);
    _log('IronSource banner: waiting for AdsService.ensureInitialized()');
    await service.ensureInitialized(cfg);
    if (!mounted) return;
    if (_currentNetwork != AdsNetwork.ironsource) {
      _log('IronSource banner: skipped post-init — network changed to $_currentNetwork');
      return;
    }
    setState(() => _ironSdkReady = true);
    _log('IronSource banner: SDK now ready');
    _ironLoadAttempts = 0;
    _scheduleIronLoadIfNeeded();
  }

  void _scheduleIronLoadIfNeeded() {
    if (!mounted) return;
    if (_currentNetwork != AdsNetwork.ironsource) {
      _log('IronSource banner: skipped schedule — current network is $_currentNetwork, not ironsource');
      return;
    }
    if (_ironLoadScheduled || !_ironSdkReady) return;

    if (_ironLoadAttempts >= _kIronMaxLoadAttempts) {
      _log(
        'IronSource banner: max load attempts reached ($_kIronMaxLoadAttempts). Marking ironsource as failed and falling back.',
      );
      _failedNetworks[AdsNetwork.ironsource] = 'max_load_attempts:$_ironLoadAttempts';
      if (mounted) setState(() {});
      return;
    }

    final state = _ironBannerKey.currentState;
    if (state == null) {
      _ironLoadAttempts++;
      final remaining = _kIronMaxLoadAttempts - _ironLoadAttempts;
      _log(
        'IronSource banner: widget not yet attached (attempt $_ironLoadAttempts/$_kIronMaxLoadAttempts) — will retry loadAd in 300ms ($remaining left)',
      );
      Future.delayed(const Duration(milliseconds: 300), () {
        if (!mounted) return;
        _ironLoadScheduled = false;
        _scheduleIronLoadIfNeeded();
      });
      return;
    }
    _ironLoadScheduled = true;
    _log('IronSource banner: calling loadAd() now');
    state.loadAd();
  }

  Future<void> _ensureLoadedAdmob() async {
    if (_ad != null) return;

    final cfg = ref.read(adsConfigProvider);
    if (cfg == null) return;

    final unitId = cfg.admob.effectiveBannerId(cfg.platform);
    _log('AdMob: load banner unitId=$unitId');
    final ad = BannerAd(
      adUnitId: unitId,
      request: const AdRequest(),
      size: AdSize.banner,
      listener: BannerAdListener(
        onAdLoaded: (ad) {
          _log(
            'AdMob: banner onAdLoaded (${AdSize.banner.width}x${AdSize.banner.height})',
          );
          if (!mounted) return;
          setState(() => _admobLoaded = true);
        },
        onAdFailedToLoad: (ad, error) {
          _log(
            'AdMob: banner onAdFailedToLoad: code=${error.code} message=${error.message} — marking AdMob as failed, fallback to next network',
          );
          ad.dispose();
          _failedNetworks[AdsNetwork.admob] = error.code;
          if (mounted) setState(() {});
        },
      ),
    );

    setState(() => _ad = ad);
    await ad.load();
  }

  @override
  Widget build(BuildContext context) {
    final cfg = ref.watch(adsConfigProvider);
    final isVip = ref.watch(isVipProvider);
    final service = ref.watch(adsServiceProvider);
    final shouldShow = !kIsWeb && cfg != null && service.adsEnabled(cfg) && !isVip;

    if (!shouldShow) {
      if (_ad != null) {
        _ad?.dispose();
        _ad = null;
        _admobLoaded = false;
      }
      _currentNetwork = null;
      _ironSdkReady = false;
      _ironLoadScheduled = false;
      _ironLoaded = false;
      _ironHeight = null;
      _ironLoadAttempts = 0;
      _failedNetworks.clear();
      return const SizedBox.shrink();
    }

    final cfgValue = cfg;

    final ranked = service.rankedBannerNetworks(maxFallbacks: 2);
    if (ranked.isEmpty) {
      _log('banner: no eligible networks (all disabled or missing IDs)');
      return const SizedBox.shrink();
    }

    AdsNetwork? network;
    for (final candidate in ranked) {
      if (!_failedNetworks.containsKey(candidate)) {
        network = candidate;
        break;
      }
    }
    if (network == null) {
      _log(
        'banner: all ${ranked.length} eligible networks failed during this session, hiding banner',
      );
      return const SizedBox.shrink();
    }

    if (network != _currentNetwork) {
      _log('banner network changed: $_currentNetwork -> $network. Resetting state');
      if (_ad != null) {
        _ad?.dispose();
        _ad = null;
        _admobLoaded = false;
      }
      _ironSdkReady = false;
      _ironLoadScheduled = false;
      _ironLoaded = false;
      _ironHeight = null;
      _ironLoadAttempts = 0;
      _currentNetwork = network;
    }

    if (network == AdsNetwork.admob) {
      Future.microtask(_ensureLoadedAdmob);
      final ad = _ad;
      if (ad == null || !_admobLoaded) return const SizedBox(height: 50);
      return SizedBox(
        height: ad.size.height.toDouble(),
        width: ad.size.width.toDouble(),
        child: AdWidget(ad: ad),
      );
    }

    if (network == AdsNetwork.applovin) {
      final adUnitId = cfgValue.applovin.bannerId;
      if (adUnitId.trim().isEmpty) {
        _log('AppLovin banner: adUnitId empty, marking as failed');
        _failedNetworks[AdsNetwork.applovin] = 'empty_adUnitId';
        if (mounted) setState(() {});
        return const SizedBox.shrink();
      }
      _log('AppLovin banner: adUnitId=$adUnitId');
      return SizedBox(
        height: 50,
        width: double.infinity,
        child: applovin.MaxAdView(
          adUnitId: adUnitId,
          adFormat: applovin.AdFormat.banner,
          listener: applovin.AdViewAdListener(
            onAdLoadedCallback: (_) => _log('AppLovin banner: onAdLoaded'),
            onAdLoadFailedCallback: (_, err) {
              _log(
                'AppLovin banner: onAdLoadFailed code=${err.code} message=${err.message} — fallback to next network',
              );
              _failedNetworks[AdsNetwork.applovin] = err.code;
              if (mounted) setState(() {});
            },
            onAdClickedCallback: (_) => _log('AppLovin banner: onAdClicked'),
            onAdExpandedCallback: (_) {},
            onAdCollapsedCallback: (_) {},
          ),
        ),
      );
    }

    if (network == AdsNetwork.unity) {
      final placementId = cfgValue.unity.bannerId;
      if (placementId.trim().isEmpty) {
        _log('Unity banner: placementId empty, marking as failed');
        _failedNetworks[AdsNetwork.unity] = 'empty_placementId';
        if (mounted) setState(() {});
        return const SizedBox.shrink();
      }
      _log('Unity banner: placementId=$placementId');
      return SizedBox(
        height: 50,
        width: double.infinity,
        child: UnityBannerAd(
          placementId: placementId,
          onFailed: (_, p, msg) {
            _log(
              'Unity banner: onFailed placement=$p msg=$msg — fallback to next network',
            );
            _failedNetworks[AdsNetwork.unity] = msg;
            if (mounted) setState(() {});
          },
          onLoad: (p) => _log('Unity banner: onLoaded placement=$p'),
          onClick: (p) => _log('Unity banner: onClick placement=$p'),
        ),
      );
    }

    if (network == AdsNetwork.ironsource) {
      final adUnitId = cfgValue.ironsource.bannerId;
      if (adUnitId.trim().isEmpty) {
        _log('IronSource banner: adUnitId empty, marking as failed');
        _failedNetworks[AdsNetwork.ironsource] = 'empty_adUnitId';
        if (mounted) setState(() {});
        return const SizedBox.shrink();
      }

      Future.microtask(_ensureIronInitialized);
      if (_ironSdkReady) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          _scheduleIronLoadIfNeeded();
        });
      }

      final banner = LevelPlayBannerAdView(
        key: _ironBannerKey,
        adUnitId: adUnitId,
        adSize: LevelPlayAdSize.BANNER,
        placementName: 'DefaultBanner',
        listener: _IronBannerListener(
          onLoaded: (info) {
            _log(
              'IronSource banner: onAdLoaded adUnitId=${info.adUnitId}',
            );
            if (!mounted) return;
            setState(() {
              _ironLoaded = true;
              _ironHeight = 50.0;
            });
          },
          onLoadFailed: (err) {
            _log(
              'IronSource banner: onAdLoadFailed code=${err.errorCode} message=${err.errorMessage} — fallback to next network',
            );
            _failedNetworks[AdsNetwork.ironsource] =
                '${err.errorCode}:${err.errorMessage}';
            if (mounted) setState(() {});
          },
          onDisplayed: (_) => _log('IronSource banner: onAdDisplayed'),
          onDisplayFailed: (_, err) {
            _log(
              'IronSource banner: onAdDisplayFailed code=${err.errorCode} message=${err.errorMessage} — fallback',
            );
            _failedNetworks[AdsNetwork.ironsource] =
                'display:${err.errorCode}:${err.errorMessage}';
            if (mounted) setState(() {});
          },
          onClicked: (_) => _log('IronSource banner: onAdClicked'),
          onCollapsed: (_) {},
          onExpanded: (_) {},
          onLeftApplication: (_) {},
        ),
      );

      if (!_ironLoaded || _ironHeight == null) {
        return SizedBox(
          height: 50,
          width: double.infinity,
          child: banner,
        );
      }

      return SizedBox(
        height: _ironHeight,
        width: double.infinity,
        child: banner,
      );
    }

    return const SizedBox.shrink();
  }
}

class _IronBannerListener with LevelPlayBannerAdViewListener {
  _IronBannerListener({
    required this.onLoaded,
    required this.onLoadFailed,
    required this.onDisplayed,
    required this.onDisplayFailed,
    required this.onClicked,
    required this.onCollapsed,
    required this.onExpanded,
    required this.onLeftApplication,
  });

  final void Function(LevelPlayAdInfo adInfo) onLoaded;
  final void Function(LevelPlayAdError error) onLoadFailed;
  final void Function(LevelPlayAdInfo adInfo) onDisplayed;
  final void Function(LevelPlayAdInfo adInfo, LevelPlayAdError error)
      onDisplayFailed;
  final void Function(LevelPlayAdInfo adInfo) onClicked;
  final void Function(LevelPlayAdInfo adInfo) onCollapsed;
  final void Function(LevelPlayAdInfo adInfo) onExpanded;
  final void Function(LevelPlayAdInfo adInfo) onLeftApplication;

  @override
  void onAdClicked(LevelPlayAdInfo adInfo) => onClicked(adInfo);

  @override
  void onAdCollapsed(LevelPlayAdInfo adInfo) => onCollapsed(adInfo);

  @override
  void onAdDisplayFailed(
    LevelPlayAdInfo adInfo,
    LevelPlayAdError error,
  ) => onDisplayFailed(adInfo, error);

  @override
  void onAdDisplayed(LevelPlayAdInfo adInfo) => onDisplayed(adInfo);

  @override
  void onAdExpanded(LevelPlayAdInfo adInfo) => onExpanded(adInfo);

  @override
  void onAdLeftApplication(LevelPlayAdInfo adInfo) => onLeftApplication(adInfo);

  @override
  void onAdLoadFailed(LevelPlayAdError error) => onLoadFailed(error);

  @override
  void onAdLoaded(LevelPlayAdInfo adInfo) => onLoaded(adInfo);
}
