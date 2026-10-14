import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:shared_preferences/shared_preferences.dart';

import '../../../shared/data/dio_provider.dart';

class RewardsConfig {
  const RewardsConfig({
    required this.platform,
    required this.enabled,
    required this.checkinSchedule,
    required this.tasks,
    this.availableCoins = 0,
  });

  final String platform;
  final bool enabled;
  final List<int> checkinSchedule;
  final List<RewardTask> tasks;
  final int availableCoins;

  factory RewardsConfig.fromJson(Map<String, dynamic> json) {
    final scheduleRaw = json['checkin_schedule'];
    final schedule = scheduleRaw is List ? scheduleRaw.map((e) => (e as num?)?.toInt() ?? 0).toList() : <int>[];

    final tasksRaw = json['tasks'];
    final tasks = tasksRaw is List
        ? tasksRaw
            .whereType<Map>()
            .map((e) => RewardTask.fromJson(e.cast<String, dynamic>()))
            .toList()
        : <RewardTask>[];

    final tasksTotal = tasks.fold<int>(0, (sum, t) => sum + t.rewardCoins);
    final fallbackTotal = tasksTotal + (schedule.isNotEmpty ? schedule.first : 0);
    final parsedAvailable = (json['available_coins'] as num?)?.toInt() ?? fallbackTotal;

    return RewardsConfig(
      platform: (json['platform'] as String?) ?? 'android',
      enabled: json['enabled'] == true,
      checkinSchedule: schedule,
      tasks: tasks,
      availableCoins: parsedAvailable,
    );
  }
}

class RewardTask {
  const RewardTask({
    required this.id,
    required this.platform,
    required this.title,
    required this.type,
    required this.targetUrl,
    required this.rewardCoins,
    required this.typeLabel,
    required this.typeBadgeText,
    required this.typeBadgeIcon,
    required this.rewardText,
    required this.sortOrder,
    required this.isActive,
  });

  final int id;
  final String platform;
  final String title;
  final String type;
  final String targetUrl;
  final int rewardCoins;
  final String typeLabel;
  final String typeBadgeText;
  final String typeBadgeIcon;
  final String rewardText;
  final int sortOrder;
  final bool isActive;

  static String _defaultBadgeForType(String typeKey) {
    switch (typeKey) {
      case 'ad':
        return 'AD';
      case 'link':
        return 'LINK';
      case 'survey':
        return 'SURVEY';
      case 'bonus':
        return 'BONUS';
      case 'social':
        return 'SOCIAL';
      case 'download':
        return 'APP';
      default:
        return 'TASK';
    }
  }

  static String _defaultLabelForType(String typeKey) {
    switch (typeKey) {
      case 'ad':
        return 'Watch Ad';
      case 'link':
        return 'Visit Link';
      case 'survey':
        return 'Take Survey';
      case 'bonus':
        return 'Bonus Task';
      case 'social':
        return 'Social Follow';
      case 'download':
        return 'Install App';
      default:
        return 'Task';
    }
  }

  static String _defaultIconForType(String typeKey) {
    switch (typeKey) {
      case 'ad':
        return '🎬';
      case 'link':
        return '🔗';
      case 'survey':
        return '📋';
      case 'bonus':
        return '🎁';
      case 'social':
        return '👥';
      case 'download':
        return '📲';
      default:
        return '✨';
    }
  }

  factory RewardTask.fromJson(Map<String, dynamic> json) {
    final rawType = (json['type'] as String?) ?? 'link';
    final rawBadge = (json['type_badge_text'] as String?) ?? '';
    final rawLabel = (json['type_label'] as String?) ?? '';
    final rawIcon = (json['type_badge_icon'] as String?) ?? '';
    final rawRewardText = (json['reward_text'] as String?) ?? '';
    return RewardTask(
      id: (json['id'] as num?)?.toInt() ?? 0,
      platform: (json['platform'] as String?) ?? 'android',
      title: (json['title'] as String?) ?? '',
      type: rawType,
      targetUrl: (json['target_url'] as String?) ?? '',
      rewardCoins: (json['reward_coins'] as num?)?.toInt() ?? 0,
      typeLabel: rawLabel.trim().isNotEmpty ? rawLabel.trim() : _defaultLabelForType(rawType),
      typeBadgeText: rawBadge.trim().isNotEmpty ? rawBadge.trim() : _defaultBadgeForType(rawType),
      typeBadgeIcon: rawIcon.trim().isNotEmpty ? rawIcon.trim() : _defaultIconForType(rawType),
      rewardText: rawRewardText.trim(),
      sortOrder: (json['sort_order'] as num?)?.toInt() ?? 100,
      isActive: json['is_active'] != false,
    );
  }
}

class RewardsApi {
  RewardsApi(this._dio);

  final Dio _dio;

  Future<RewardsConfig> config() async {
    final p = _detectPlatform();
    final res = await _dio.get<Map<String, dynamic>>(
      '/v1/rewards/config',
      queryParameters: {'platform': p},
    );
    final map = res.data ?? <String, dynamic>{};
    if (map['status'] != true) {
      throw Exception((map['message'] as String?) ?? 'Request failed');
    }
    final data = (map['data'] as Map<String, dynamic>?) ?? <String, dynamic>{};
    return RewardsConfig.fromJson(data);
  }

  Future<Map<String, dynamic>> checkin() async {
    final p = _detectPlatform();
    final res = await _dio.post<Map<String, dynamic>>(
      '/v1/rewards/checkin',
      data: {'platform': p},
    );
    final map = res.data ?? <String, dynamic>{};
    if (map['status'] != true) {
      throw Exception((map['message'] as String?) ?? 'Request failed');
    }
    final data = (map['data'] as Map<String, dynamic>?) ?? <String, dynamic>{};
    return data;
  }

  Future<Map<String, dynamic>> claimTask({required int taskId}) async {
    final p = _detectPlatform();
    final res = await _dio.post<Map<String, dynamic>>(
      '/v1/rewards/tasks/$taskId/claim',
      data: {'platform': p},
    );
    final map = res.data ?? <String, dynamic>{};
    if (map['status'] != true) {
      throw Exception((map['message'] as String?) ?? 'Request failed');
    }
    final data = (map['data'] as Map<String, dynamic>?) ?? <String, dynamic>{};
    return data;
  }
}

String _detectPlatform() {
  if (kIsWeb) return 'web';
  return defaultTargetPlatform == TargetPlatform.iOS ? 'ios' : 'android';
}

final rewardsApiProvider = Provider<RewardsApi>((ref) {
  return RewardsApi(ref.watch(dioProvider));
});

class RewardsConfigNotifier extends StateNotifier<AsyncValue<RewardsConfig>> {
  RewardsConfigNotifier(this._api)
      : super(_cachedConfig != null
            ? AsyncValue.data(_cachedConfig!)
            : const AsyncValue.loading()) {
    _initAndRefresh();
  }

  final RewardsApi _api;
  static RewardsConfig? _cachedConfig;
  static int? _cachedAvailableCoins;

  static int get cachedAvailableCoins =>
      _cachedAvailableCoins ?? _cachedConfig?.availableCoins ?? 0;

  Future<void> _initAndRefresh() async {
    if (_cachedAvailableCoins == null) {
      try {
        final prefs = await SharedPreferences.getInstance();
        final stored = prefs.getInt('cached_reward_available_coins');
        if (stored != null && _cachedAvailableCoins == null) {
          _cachedAvailableCoins = stored;
        }
      } catch (_) {}
    }
    await refresh();
  }

  Future<void> refresh() async {
    if (_cachedConfig != null && state.valueOrNull == null) {
      state = AsyncValue.data(_cachedConfig!);
    }
    try {
      final cfg = await _api.config();
      _cachedConfig = cfg;
      _cachedAvailableCoins = cfg.availableCoins;
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setInt('cached_reward_available_coins', cfg.availableCoins);
      } catch (_) {}
      if (mounted) {
        state = AsyncValue.data(cfg);
      }
    } catch (e, st) {
      if (mounted) {
        if (_cachedConfig != null) {
          state = AsyncValue.data(_cachedConfig!);
        } else {
          state = AsyncValue.error(e, st);
        }
      }
    }
  }

  void updateConfig(RewardsConfig newConfig) {
    _cachedConfig = newConfig;
    _cachedAvailableCoins = newConfig.availableCoins;
    try {
      SharedPreferences.getInstance().then(
          (prefs) => prefs.setInt('cached_reward_available_coins', newConfig.availableCoins));
    } catch (_) {}
    state = AsyncValue.data(newConfig);
  }
}

final rewardsConfigProvider =
    StateNotifierProvider<RewardsConfigNotifier, AsyncValue<RewardsConfig>>((ref) {
  return RewardsConfigNotifier(ref.watch(rewardsApiProvider));
});
