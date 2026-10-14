class AdsConfig {
  const AdsConfig({
    required this.platform,
    required this.monetization,
    required this.mediation,
    required this.admob,
    required this.applovin,
    required this.unity,
    required this.ironsource,
    required this.vast,
  });

  final String platform;
  final MonetizationAdsConfig monetization;
  final MediationAdsConfig mediation;
  final AdMobAdsConfig admob;
  final AppLovinAdsConfig applovin;
  final UnityAdsConfig unity;
  final IronSourceAdsConfig ironsource;
  final VastAdsConfig vast;

  static AdsConfig? fromAppConfig(Map<String, dynamic> data, {Map<String, dynamic> publicSettings = const <String, dynamic>{}}) {
    final platform = (data['platform'] as String?)?.trim().toLowerCase() ?? '';
    final ads = (data['ads'] as Map?)?.cast<String, dynamic>() ?? const <String, dynamic>{};
    final monetization = MonetizationAdsConfig.fromJson(
      (data['monetization'] as Map?)?.cast<String, dynamic>() ?? const <String, dynamic>{},
      publicSettings: (publicSettings['monetization'] as Map?)?.cast<String, dynamic>() ?? const <String, dynamic>{},
      adsMap: ads,
    );
    final mediation = MediationAdsConfig.fromJson((ads['mediation'] as Map?)?.cast<String, dynamic>() ?? const <String, dynamic>{});
    final admob = AdMobAdsConfig.fromJson((ads['admob'] as Map?)?.cast<String, dynamic>() ?? const <String, dynamic>{}, platform);
    final applovin = AppLovinAdsConfig.fromJson((ads['applovin'] as Map?)?.cast<String, dynamic>() ?? const <String, dynamic>{});
    final unity = UnityAdsConfig.fromJson((ads['unity'] as Map?)?.cast<String, dynamic>() ?? const <String, dynamic>{});
    final ironsource = IronSourceAdsConfig.fromJson((ads['ironsource'] as Map?)?.cast<String, dynamic>() ?? const <String, dynamic>{});
    final vast = VastAdsConfig.fromJson(
      (ads['vast'] as Map?)?.cast<String, dynamic>() ??
      (publicSettings['ads'] is Map ? ((publicSettings['ads'] as Map)['vast'] as Map?)?.cast<String, dynamic>() : null) ??
      const <String, dynamic>{},
    );
    if (platform.isEmpty) return null;

    if (!monetization.appAdsEnabled) {
      return AdsConfig(
        platform: platform,
        monetization: monetization,
        mediation: mediation,
        admob: const AdMobAdsConfig(
          status: AdsStatus.disabled,
          appId: '',
          bannerId: '',
          interstitialId: '',
          rewardedId: '',
        ),
        applovin: const AppLovinAdsConfig(
          enabled: false,
          sdkKey: '',
          bannerId: '',
          interstitialId: '',
          rewardedId: '',
        ),
        unity: const UnityAdsConfig(
          enabled: false,
          gameId: '',
          bannerId: '',
          interstitialId: '',
          rewardedId: '',
        ),
        ironsource: const IronSourceAdsConfig(
          enabled: false,
          appKey: '',
          bannerId: '',
          interstitialId: '',
          rewardedId: '',
        ),
        vast: const VastAdsConfig(
          enabled: false,
          url: '',
          skipSeconds: 5,
          frequency: 1,
        ),
      );
    }

    return AdsConfig(
      platform: platform,
      monetization: monetization,
      mediation: mediation,
      admob: admob,
      applovin: applovin,
      unity: unity,
      ironsource: ironsource,
      vast: vast,
    );
  }
}

class VastAdsConfig {
  const VastAdsConfig({
    required this.enabled,
    required this.url,
    required this.skipSeconds,
    required this.frequency,
  });

  final bool enabled;
  final String url;
  final int skipSeconds;
  final int frequency;

  static VastAdsConfig fromJson(Map<String, dynamic> json) {
    final statusRaw = (json['status'] as String?)?.trim().toLowerCase() ?? 'disabled';
    final isExplicitlyEnabled = json['enabled'] == true || statusRaw == 'enabled';
    final url = (json['url'] as String?)?.trim() ?? '';
    final skipSec = json['skip_seconds'] is int
        ? (json['skip_seconds'] as int)
        : int.tryParse(json['skip_seconds']?.toString() ?? '5') ?? 5;
    final freq = json['frequency'] is int
        ? (json['frequency'] as int)
        : int.tryParse(json['frequency']?.toString() ?? '1') ?? 1;

    return VastAdsConfig(
      enabled: isExplicitlyEnabled && url.isNotEmpty,
      url: url,
      skipSeconds: skipSec.clamp(0, 120),
      frequency: freq.clamp(1, 50),
    );
  }
}

class MonetizationAdsConfig {
  const MonetizationAdsConfig({
    required this.appAdProvider,
    required this.appAdType,
    required this.coinSystemEnabled,
    required this.episodeUnlockAllowVip,
    this.appAdsEnabledDirect,
  });

  final String appAdProvider;
  final String appAdType;
  final bool coinSystemEnabled;
  final bool episodeUnlockAllowVip;
  final bool? appAdsEnabledDirect;

  bool get appAdsEnabled {
    if (appAdsEnabledDirect != null) {
      return appAdsEnabledDirect! && appAdProvider != 'none';
    }
    return appAdProvider != 'none';
  }

  static MonetizationAdsConfig fromJson(
    Map<String, dynamic> json, {
    Map<String, dynamic> publicSettings = const <String, dynamic>{},
    Map<String, dynamic> adsMap = const <String, dynamic>{},
  }) {
    bool? explicitEnabled;
    final rawVal = json['app_ads_enabled'] ??
        publicSettings['app_ads_enabled'] ??
        adsMap['app_ads_enabled'] ??
        adsMap['enabled'];
    if (rawVal != null) {
      if (rawVal is bool) {
        explicitEnabled = rawVal;
      } else if (rawVal is num) {
        explicitEnabled = rawVal != 0;
      } else if (rawVal is String) {
        final s = rawVal.trim().toLowerCase();
        explicitEnabled = (s == '1' || s == 'true' || s == 'enabled');
      }
    } else if (adsMap['status'] != null) {
      final s = adsMap['status'].toString().trim().toLowerCase();
      explicitEnabled = (s == '1' || s == 'true' || s == 'enabled');
    }

    final provider = (json['app_ad_provider'] as String?)?.trim().toLowerCase() ?? 'admob';
    final type = (json['app_ad_type'] as String?)?.trim().toLowerCase() ?? 'rewarded';
    final coinEnabled = publicSettings['coin_system_enabled'] == true || json['coin_system_enabled'] == true;
    final allowVip = publicSettings['episode_unlock_allow_vip'] == true || publicSettings['allow_vip_unlock'] == true || json['episode_unlock_allow_vip'] == true;

    final effectiveProvider = (explicitEnabled == false) ? 'none' : (provider.isEmpty ? 'admob' : provider);

    return MonetizationAdsConfig(
      appAdProvider: effectiveProvider,
      appAdType: (type == 'interstitial') ? 'interstitial' : 'rewarded',
      coinSystemEnabled: coinEnabled,
      episodeUnlockAllowVip: allowVip,
      appAdsEnabledDirect: explicitEnabled,
    );
  }
}

enum AdsStatus {
  disabled,
  enabled,
  test,
}

enum AdsNetwork {
  admob,
  applovin,
  unity,
  ironsource,
}

enum MediationMode {
  rotation,
  single,
}

class MediationAdsConfig {
  const MediationAdsConfig({
    required this.mode,
    required this.weights,
  });

  final MediationMode mode;
  final Map<AdsNetwork, int> weights;

  static MediationAdsConfig fromJson(Map<String, dynamic> json) {
    final modeRaw = (json['mode'] as String?)?.trim().toLowerCase() ?? 'rotation';
    final mode = modeRaw == 'single' ? MediationMode.single : MediationMode.rotation;
    final weights = parseWeights((json['weights'] as String?) ?? '');
    return MediationAdsConfig(mode: mode, weights: weights);
  }

  static Map<AdsNetwork, int> parseWeights(String raw) {
    final out = <AdsNetwork, int>{};
    for (final part in raw.split(',')) {
      final p = part.trim();
      if (p.isEmpty) continue;
      final idx = p.indexOf(':');
      if (idx <= 0) continue;
      final k = p.substring(0, idx).trim().toLowerCase();
      final vRaw = p.substring(idx + 1).trim();
      final v = int.tryParse(vRaw) ?? 0;
      final key = switch (k) {
        'admob' => AdsNetwork.admob,
        'applovin' => AdsNetwork.applovin,
        'unity' => AdsNetwork.unity,
        'ironsource' => AdsNetwork.ironsource,
        _ => null,
      };
      if (key == null) continue;
      if (v <= 0) continue;
      out[key] = v;
    }
    return out;
  }
}

class AdMobAdsConfig {
  const AdMobAdsConfig({
    required this.status,
    required this.appId,
    required this.bannerId,
    required this.interstitialId,
    required this.rewardedId,
  });

  final AdsStatus status;
  final String appId;
  final String bannerId;
  final String interstitialId;
  final String rewardedId;

  bool get enabled => status != AdsStatus.disabled;
  bool get testMode => status == AdsStatus.test;

  String effectiveBannerId(String platform) {
    if (testMode || bannerId.trim().isEmpty) {
      return platform == 'ios' ? _kTestBannerIos : _kTestBannerAndroid;
    }
    return bannerId;
  }

  String effectiveInterstitialId(String platform) {
    if (testMode || interstitialId.trim().isEmpty) {
      return platform == 'ios' ? _kTestInterstitialIos : _kTestInterstitialAndroid;
    }
    return interstitialId;
  }

  String effectiveRewardedId(String platform) {
    if (testMode || rewardedId.trim().isEmpty) {
      return platform == 'ios' ? _kTestRewardedIos : _kTestRewardedAndroid;
    }
    return rewardedId;
  }

  static AdMobAdsConfig fromJson(Map<String, dynamic> json, String platform) {
    final statusRaw = (json['status'] as String?)?.trim().toLowerCase() ?? 'disabled';
    final status = switch (statusRaw) {
      'enabled' => AdsStatus.enabled,
      'test' => AdsStatus.test,
      _ => AdsStatus.disabled,
    };

    return AdMobAdsConfig(
      status: status,
      appId: (json['app_id'] as String?)?.trim() ?? '',
      bannerId: (json['banner_id'] as String?)?.trim() ?? '',
      interstitialId: (json['interstitial_id'] as String?)?.trim() ?? '',
      rewardedId: (json['rewarded_id'] as String?)?.trim() ?? '',
    );
  }
}

class AppLovinAdsConfig {
  const AppLovinAdsConfig({
    required this.enabled,
    required this.sdkKey,
    required this.bannerId,
    required this.interstitialId,
    required this.rewardedId,
  });

  final bool enabled;
  final String sdkKey;
  final String bannerId;
  final String interstitialId;
  final String rewardedId;

  static AppLovinAdsConfig fromJson(Map<String, dynamic> json) {
    final statusRaw = (json['status'] as String?)?.trim().toLowerCase() ?? 'disabled';
    final enabled = statusRaw == 'enabled';
    return AppLovinAdsConfig(
      enabled: enabled,
      sdkKey: (json['sdk_key'] as String?)?.trim() ?? '',
      bannerId: (json['banner_id'] as String?)?.trim() ?? '',
      interstitialId: (json['interstitial_id'] as String?)?.trim() ?? '',
      rewardedId: (json['rewarded_id'] as String?)?.trim() ?? '',
    );
  }
}

class UnityAdsConfig {
  const UnityAdsConfig({
    required this.enabled,
    required this.gameId,
    required this.bannerId,
    required this.interstitialId,
    required this.rewardedId,
  });

  final bool enabled;
  final String gameId;
  final String bannerId;
  final String interstitialId;
  final String rewardedId;

  static UnityAdsConfig fromJson(Map<String, dynamic> json) {
    final statusRaw = (json['status'] as String?)?.trim().toLowerCase() ?? 'disabled';
    final enabled = statusRaw == 'enabled';
    return UnityAdsConfig(
      enabled: enabled,
      gameId: (json['game_id'] as String?)?.trim() ?? '',
      bannerId: (json['banner_id'] as String?)?.trim() ?? '',
      interstitialId: (json['interstitial_id'] as String?)?.trim() ?? '',
      rewardedId: (json['rewarded_id'] as String?)?.trim() ?? '',
    );
  }
}

class IronSourceAdsConfig {
  const IronSourceAdsConfig({
    required this.enabled,
    required this.appKey,
    required this.bannerId,
    required this.interstitialId,
    required this.rewardedId,
  });

  final bool enabled;
  final String appKey;
  final String bannerId;
  final String interstitialId;
  final String rewardedId;

  static IronSourceAdsConfig fromJson(Map<String, dynamic> json) {
    final statusRaw = (json['status'] as String?)?.trim().toLowerCase() ?? 'disabled';
    final enabled = statusRaw == 'enabled';
    return IronSourceAdsConfig(
      enabled: enabled,
      appKey: (json['app_key'] as String?)?.trim() ?? '',
      bannerId: (json['banner_id'] as String?)?.trim() ?? '',
      interstitialId: (json['interstitial_id'] as String?)?.trim() ?? '',
      rewardedId: (json['rewarded_id'] as String?)?.trim() ?? '',
    );
  }
}

const _kTestBannerAndroid = 'ca-app-pub-3940256099942544/6300978111';
const _kTestInterstitialAndroid = 'ca-app-pub-3940256099942544/1033173712';
const _kTestRewardedAndroid = 'ca-app-pub-3940256099942544/5224354917';

const _kTestBannerIos = 'ca-app-pub-3940256099942544/2934735716';
const _kTestInterstitialIos = 'ca-app-pub-3940256099942544/4411468910';
const _kTestRewardedIos = 'ca-app-pub-3940256099942544/1712485313';
