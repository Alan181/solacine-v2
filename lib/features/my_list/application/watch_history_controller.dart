import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/data/dio_provider.dart';
import '../../auth/application/auth_controller.dart';
import '../../bootstrap/application/bootstrap_controller.dart';

class WatchHistoryEntry {
  final int seriesId;
  final String slug;
  final String title;
  final String posterUrl;
  final String subtitle;
  final int episodeNumber;
  final int totalEpisodes;
  final DateTime watchedAt;

  const WatchHistoryEntry({
    required this.seriesId,
    required this.slug,
    required this.title,
    required this.posterUrl,
    required this.subtitle,
    required this.episodeNumber,
    required this.totalEpisodes,
    required this.watchedAt,
  });

  factory WatchHistoryEntry.fromJson(Map<String, dynamic> json) {
    final epNum = (json['episode_number'] as num?)?.toInt() ?? 1;
    final safeEpNum = epNum > 0 ? epNum : 1;
    final totalEpRaw = (json['total_episodes'] as num?)?.toInt() ?? safeEpNum;
    final safeTotalEp = totalEpRaw >= safeEpNum ? totalEpRaw : safeEpNum;
    final rawPoster =
        (json['poster_url'] ?? json['featured_image_url'] ?? '').toString();

    return WatchHistoryEntry(
      seriesId: (json['series_id'] as num?)?.toInt() ?? 0,
      slug: (json['slug'] ?? '').toString(),
      title: (json['title'] ?? '').toString(),
      posterUrl: rawPoster,
      subtitle: (json['subtitle'] ?? '').toString(),
      episodeNumber: safeEpNum,
      totalEpisodes: safeTotalEp,
      watchedAt:
          DateTime.tryParse((json['watched_at'] ?? '').toString())?.toLocal() ??
              DateTime.now(),
    );
  }

  String get episodeProgressLabel => 'Ep.$episodeNumber / Ep.$totalEpisodes';

  String get timeGroupLabel {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final watchedDay =
        DateTime(watchedAt.year, watchedAt.month, watchedAt.day);
    final diffDays = today.difference(watchedDay).inDays;

    if (diffDays <= 0) return 'Hari Ini';
    if (diffDays == 1) return 'Kemarin';
    return 'Sebelumnya';
  }
}

class WatchHistoryNotifier extends AsyncNotifier<List<WatchHistoryEntry>> {
  @override
  Future<List<WatchHistoryEntry>> build() async {
    final session = await ref.watch(authSessionProvider.future);
    if (session == null) return const [];
    return _fetchHistory();
  }

  Future<List<WatchHistoryEntry>> _fetchHistory({String query = ''}) async {
    final bootstrap = await ref.read(appBootstrapProvider.future);
    final lang = bootstrap.localeCode;
    final dio = ref.read(dioProvider);

    final res = await dio.get>(
      '/v1/my-list/history',
      queryParameters: {
        if (lang.trim().isNotEmpty) 'lang': lang,
        if (query.trim().isNotEmpty) 'q': query.trim(),
      },
    );

    final json = res.data ?? const <String, dynamic>{};
    if (json['status'] != true) {
      throw Exception(
        (json['message'] as String?) ?? 'Failed to load watch history',
      );
    }

    final data =
        (json['data'] as Map<String, dynamic>?) ?? const <String, dynamic>{};
    final rawList = data['data'];
    final list = rawList is List
        ? rawList
        : (rawList is Map ? rawList.values.toList(growable: false) : const []);

    return list
        .whereType()
        .map((e) => WatchHistoryEntry.fromJson(e.cast<String, dynamic>()))
        .toList(growable: false);
  }

  Future<void> refresh({String query = ''}) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() => _fetchHistory(query: query));
  }

  Future<void> removeBySlug(String slug) async {
    final current = state.valueOrNull ?? const <WatchHistoryEntry>[];
    state = AsyncData(
      current.where((e) => e.slug != slug).toList(growable: false),
    );

    try {
      final dio = ref.read(dioProvider);
      await dio.delete<void>('/v1/my-list/history/$slug');
    } catch (_) {
      state = AsyncData(current);
    }
  }

  Future<void> clearAll() async {
    final current = state.valueOrNull ?? const <WatchHistoryEntry>[];
    state = const AsyncData([]);

    try {
      final dio = ref.read(dioProvider);
      await dio.delete<void>('/v1/my-list/history');
    } catch (_) {
      state = AsyncData(current);
    }
  }
}

final watchHistoryProvider =
    AsyncNotifierProvider<WatchHistoryNotifier, List<WatchHistoryEntry>>(
  WatchHistoryNotifier.new,
);
