import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/data/dio_provider.dart';
import '../domain/home_feed.dart';

class HomeApi {
  HomeApi(this._dio);

  final Dio _dio;

  Future<HomeFeed> getHomeFeed({required String lang}) async {
    final res = await _dio.get<Map<String, dynamic>>(
      '/v1/home',
      queryParameters: {
        if (lang.trim().isNotEmpty) 'lang': lang,
      },
    );
    final json = res.data ?? const <String, dynamic>{};
    final ok = json['status'] == true;
    if (!ok) {
      throw Exception((json['message'] as String?) ?? 'Failed to load home');
    }
    final data = (json['data'] as Map<String, dynamic>?) ?? <String, dynamic>{};
    final feed = HomeFeed.fromJson(data);
    return feed;
  }
}

final homeApiProvider = Provider<HomeApi>((ref) {
  return HomeApi(ref.watch(dioProvider));
});
