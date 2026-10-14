import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/data/dio_provider.dart';
import '../../home/domain/home_feed.dart';

class GenresApi {
  GenresApi(this._dio);

  final Dio _dio;

  Future<List<HomeSection>> getGenresSections({required String lang}) async {
    final res = await _dio.get<Map<String, dynamic>>(
      '/v1/genres',
      queryParameters: {
        if (lang.trim().isNotEmpty) 'lang': lang,
      },
    );
    final json = res.data ?? const <String, dynamic>{};
    final ok = json['status'] == true;
    if (!ok) {
      throw Exception((json['message'] as String?) ?? 'Failed to load genres');
    }
    final data = (json['data'] as Map<String, dynamic>?) ?? <String, dynamic>{};
    final raw = data['sections'];
    final list = raw is List ? raw : (raw is Map ? raw.values.toList(growable: false) : const []);
    return list.whereType<Map>().map((e) => HomeSection.fromJson(e.cast<String, dynamic>())).toList(growable: false);
  }
}

final genresApiProvider = Provider<GenresApi>((ref) {
  return GenresApi(ref.watch(dioProvider));
});

