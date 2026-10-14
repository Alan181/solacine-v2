import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/data/dio_provider.dart';
import '../domain/search_series.dart';

class SearchApi {
  SearchApi(this._dio);

  final Dio _dio;

  Future<List<SearchSeries>> trending({String lang = ''}) async {
    final res = await _dio.get<Map<String, dynamic>>(
      '/v1/search/trending',
      queryParameters: {
        if (lang.trim().isNotEmpty) 'lang': lang,
      },
    );
    final json = res.data ?? const <String, dynamic>{};
    if (json['status'] != true) {
      throw Exception((json['message'] as String?) ?? 'Failed to load trending');
    }
    final data = (json['data'] as Map<String, dynamic>?) ?? const <String, dynamic>{};
    final raw = data['items'];
    final list = raw is List ? raw : const [];
    return list.whereType<Map>().map((e) => SearchSeries.fromJson(e.cast<String, dynamic>())).toList();
  }

  Future<({List<SearchSeries> items, bool hasMore})> search({
    required String q,
    required int page,
    String lang = '',
  }) async {
    final res = await _dio.get<Map<String, dynamic>>(
      '/v1/search',
      queryParameters: {
        'q': q,
        'page': page,
        if (lang.trim().isNotEmpty) 'lang': lang,
      },
    );
    final json = res.data ?? const <String, dynamic>{};
    if (json['status'] != true) {
      throw Exception((json['message'] as String?) ?? 'Failed to search');
    }
    final data = (json['data'] as Map<String, dynamic>?) ?? const <String, dynamic>{};
    final raw = data['data'];
    final list = raw is List ? raw : const [];
    final items = list.whereType<Map>().map((e) => SearchSeries.fromJson(e.cast<String, dynamic>())).toList();
    final currentPage = (data['current_page'] as num?)?.toInt() ?? page;
    final lastPage = (data['last_page'] as num?)?.toInt() ?? currentPage;
    return (items: items, hasMore: currentPage < lastPage);
  }

  Future<void> track({required int seriesId, required String q}) async {
    await _dio.post<Map<String, dynamic>>(
      '/v1/search/track',
      data: {
        'series_id': seriesId,
        'q': q,
      },
    );
  }
}

final searchApiProvider = Provider<SearchApi>((ref) {
  return SearchApi(ref.watch(dioProvider));
});

