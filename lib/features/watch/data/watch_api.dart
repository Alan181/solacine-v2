import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/data/dio_provider.dart';

class WatchSeriesDto {
  const WatchSeriesDto({
    required this.id,
    required this.slug,
    required this.title,
    required this.synopsis,
    required this.genres,
    required this.isPremium,
    required this.contentRating,
    required this.isDubbed,
    required this.freeEpisodes,
    required this.viewsCount,
    required this.posterUrl,
    required this.featuredImageUrl,
    required this.logoUrl,
    required this.likesCount,
    required this.isLiked,
    required this.isFavorited,
    required this.lastWatchedEpisodeNumber,
  });

  final int id;
  final String slug;
  final String title;
  final String synopsis;
  final List<String> genres;
  final bool isPremium;
  final String contentRating;
  final bool isDubbed;
  final int freeEpisodes;
  final int viewsCount;
  final String posterUrl;
  final String featuredImageUrl;
  final String logoUrl;
  final int likesCount;
  final bool isLiked;
  final bool isFavorited;
  final int lastWatchedEpisodeNumber;

  factory WatchSeriesDto.fromJson(Map<String, dynamic> json) {
    final rawGenres = json['genres'];
    final genres = rawGenres is List ? rawGenres.whereType<String>().toList(growable: false) : const <String>[];
    return WatchSeriesDto(
      id: (json['id'] as num?)?.toInt() ?? 0,
      slug: (json['slug'] as String?) ?? '',
      title: (json['title'] as String?) ?? '',
      synopsis: (json['synopsis'] as String?) ?? '',
      genres: genres,
      isPremium: json['is_premium'] == true,
      contentRating: ((json['content_rating'] as String?) ?? '').trim(),
      isDubbed: json['is_dubbed'] == true,
      freeEpisodes: (json['free_episodes'] as num?)?.toInt() ?? 0,
      viewsCount: (json['views_count'] as num?)?.toInt() ?? (json['initial_views'] as num?)?.toInt() ?? 0,
      posterUrl: (json['poster_url'] as String?) ?? '',
      featuredImageUrl: (json['featured_image_url'] as String?) ?? '',
      logoUrl: (json['logo_url'] as String?) ?? '',
      likesCount: (json['likes_count'] as num?)?.toInt() ?? 0,
      isLiked: json['is_liked'] == true,
      isFavorited: json['is_favorited'] == true,
      lastWatchedEpisodeNumber: (json['last_watched_episode_number'] as num?)?.toInt() ?? 1,
    );
  }
}

class WatchEpisodeDto {
  const WatchEpisodeDto({
    required this.id,
    required this.episodeNumber,
    required this.isFree,
    required this.isUnlocked,
    required this.videoUrl,
    required this.sources,
  });

  final int id;
  final int episodeNumber;
  final bool isFree;
  final bool isUnlocked;
  final String videoUrl;
  final List<Map<String, dynamic>> sources;

  factory WatchEpisodeDto.fromJson(Map<String, dynamic> json) {
    final rawSources = json['sources'];
    final list = rawSources is List ? rawSources : const [];
    return WatchEpisodeDto(
      id: (json['id'] as num?)?.toInt() ?? 0,
      episodeNumber: (json['episode_number'] as num?)?.toInt() ?? 0,
      isFree: json['is_free'] == true,
      isUnlocked: json['is_unlocked'] == true,
      videoUrl: (json['video_url'] as String?) ?? '',
      sources: list.whereType<Map>().map((e) => e.cast<String, dynamic>()).toList(growable: false),
    );
  }
}

class WatchUnlockDto {
  const WatchUnlockDto({
    required this.method,
    required this.cost,
    required this.allowVip,
    required this.dailyAdLimit,
    required this.adUnlocksToday,
  });

  final String method;
  final int cost;
  final bool allowVip;
  final int dailyAdLimit;
  final int adUnlocksToday;

  factory WatchUnlockDto.fromJson(Map<String, dynamic> json) {
    return WatchUnlockDto(
      method: (json['method'] as String?) ?? 'coins_ads',
      cost: (json['cost'] as num?)?.toInt() ?? 0,
      allowVip: json['allow_vip'] == true,
      dailyAdLimit: (json['daily_ad_limit'] as num?)?.toInt() ?? 0,
      adUnlocksToday: (json['ad_unlocks_today'] as num?)?.toInt() ?? 0,
    );
  }
}

class WatchDataDto {
  const WatchDataDto({
    required this.series,
    required this.episodes,
    required this.episodesPage,
    required this.episodesPerPage,
    required this.episodesTotal,
    required this.episodesPages,
    required this.activeEpisodeId,
    required this.activeEpisodeNumber,
    required this.unlock,
  });

  final WatchSeriesDto series;
  final List<WatchEpisodeDto> episodes;
  final int episodesPage;
  final int episodesPerPage;
  final int episodesTotal;
  final int episodesPages;
  final int activeEpisodeId;
  final int activeEpisodeNumber;
  final WatchUnlockDto unlock;

  factory WatchDataDto.fromJson(Map<String, dynamic> json) {
    final rawEpisodes = json['episodes'];
    final list = rawEpisodes is List ? rawEpisodes : const [];
    final active = (json['active_episode'] as Map?)?.cast<String, dynamic>() ?? const <String, dynamic>{};
    return WatchDataDto(
      series: WatchSeriesDto.fromJson((json['series'] as Map?)?.cast<String, dynamic>() ?? const <String, dynamic>{}),
      episodes: list.whereType<Map>().map((e) => WatchEpisodeDto.fromJson(e.cast<String, dynamic>())).toList(growable: false),
      episodesPage: (json['episodes_page'] as num?)?.toInt() ?? 1,
      episodesPerPage: (json['episodes_per_page'] as num?)?.toInt() ?? 0,
      episodesTotal: (json['episodes_total'] as num?)?.toInt() ?? 0,
      episodesPages: (json['episodes_pages'] as num?)?.toInt() ?? 0,
      activeEpisodeId: (active['id'] as num?)?.toInt() ?? 0,
      activeEpisodeNumber: (active['episode_number'] as num?)?.toInt() ?? 0,
      unlock: WatchUnlockDto.fromJson((json['unlock'] as Map?)?.cast<String, dynamic>() ?? const <String, dynamic>{}),
    );
  }
}

class RandomSeriesDto {
  const RandomSeriesDto({required this.slug, required this.title});
  final String slug;
  final String title;

  factory RandomSeriesDto.fromJson(Map<String, dynamic> json) {
    return RandomSeriesDto(
      slug: (json['slug'] as String?) ?? '',
      title: (json['title'] as String?) ?? '',
    );
  }
}

class WatchApi {
  WatchApi(this._dio);

  final Dio _dio;

  Future<WatchDataDto> show({
    required String slug,
    int? episodeNumber,
    int? episodesPage,
    int? episodesPerPage,
    Options? options,
  }) async {
    final qp = <String, dynamic>{};
    if (episodeNumber != null) qp['episode'] = episodeNumber;
    if (episodesPage != null) qp['episodes_page'] = episodesPage;
    if (episodesPerPage != null) qp['episodes_per_page'] = episodesPerPage;
    final res = await _dio.get<Map<String, dynamic>>(
      '/v1/watch/$slug',
      queryParameters: qp.isEmpty ? null : qp,
      options: options,
    );
    final map = res.data ?? const <String, dynamic>{};
    if (map['status'] != true) {
      throw Exception((map['message'] as String?) ?? 'Request failed');
    }
    final data = (map['data'] as Map?)?.cast<String, dynamic>() ?? const <String, dynamic>{};
    return WatchDataDto.fromJson(data);
  }

  Future<Map<String, dynamic>> toggleLike({required int seriesId}) async {
    final res = await _dio.post<Map<String, dynamic>>('/v1/series/$seriesId/like');
    final map = res.data ?? const <String, dynamic>{};
    if (map['status'] != true) {
      throw Exception((map['message'] as String?) ?? 'Request failed');
    }
    final data = (map['data'] as Map?)?.cast<String, dynamic>() ?? const <String, dynamic>{};
    return data;
  }

  Future<void> unlockEpisode({required int episodeId, required String method}) async {
    final res = await _dio.post<Map<String, dynamic>>(
      '/v1/episodes/$episodeId/unlock',
      data: {'method': method},
    );
    final map = res.data ?? const <String, dynamic>{};
    if (map['status'] != true) {
      throw Exception((map['message'] as String?) ?? 'Request failed');
    }
  }

  Future<RandomSeriesDto?> getRandomSeries({required String currentSlug}) async {
    try {
      final res = await _dio.get<Map<String, dynamic>>(
        '/v1/series/random',
        queryParameters: {'exclude': currentSlug},
      );
      final map = res.data ?? const <String, dynamic>{};
      if (map['status'] != true) return null;
      final data = (map['data'] as Map?)?.cast<String, dynamic>();
      if (data == null) return null;
      return RandomSeriesDto.fromJson(data);
    } catch (_) {
      return null;
    }
  }

  Future<Map<String, dynamic>> claimMinuteReward({required int seriesId}) async {
    final res = await _dio.post<Map<String, dynamic>>(
      '/v1/watch/claim-minute-reward',
      data: {'series_id': seriesId},
    );
    final map = res.data ?? const <String, dynamic>{};
    if (map['status'] != true) {
      throw Exception((map['message'] as String?) ?? 'Gagal mengklaim reward');
    }
    return (map['data'] as Map?)?.cast<String, dynamic>() ?? const <String, dynamic>{};
  }
}

final watchApiProvider = Provider<WatchApi>((ref) {
  return WatchApi(ref.watch(dioProvider));
});
