import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dio/dio.dart';

import '../../../shared/data/dio_provider.dart';
import '../../auth/application/auth_controller.dart';

class FavoritesController extends AsyncNotifier<Set<int>> {
  @override
  Future<Set<int>> build() async {
    final session = await ref.watch(authSessionProvider.future);
    if (session == null) return <int>{};

    final dio = ref.read(dioProvider);
    Response<Map<String, dynamic>> res;
    try {
      res = await dio.get<Map<String, dynamic>>('/v1/my-list/ids');
    } on DioException catch (e) {
      final code = e.response?.statusCode ?? 0;
      if (code == 401 || code == 403) {
        await ref.read(authSessionProvider.notifier).logout();
        return <int>{};
      }
      rethrow;
    }
    final json = res.data ?? const <String, dynamic>{};
    if (json['status'] != true) {
      throw Exception((json['message'] as String?) ?? 'Failed to load favorites');
    }

    final data = (json['data'] as Map<String, dynamic>?) ?? const <String, dynamic>{};
    final raw = data['ids'];
    final list = raw is List ? raw : const [];
    return list.whereType<num>().map((e) => e.toInt()).toSet();
  }

  Future<bool?> toggle(int seriesId) async {
    final session = ref.read(authSessionProvider).valueOrNull;
    if (session == null) return null;

    final current = state.valueOrNull ?? <int>{};
    final next = <int>{...current};
    final wasFavorited = next.contains(seriesId);
    if (wasFavorited) {
      next.remove(seriesId);
    } else {
      next.add(seriesId);
    }
    state = AsyncData(next);

    try {
      final dio = ref.read(dioProvider);
      final res = await dio.post<Map<String, dynamic>>('/v1/my-list/$seriesId/toggle');
      final json = res.data ?? const <String, dynamic>{};
      if (json['status'] != true) {
        throw Exception((json['message'] as String?) ?? 'Failed to toggle favorite');
      }
      final data = (json['data'] as Map<String, dynamic>?) ?? const <String, dynamic>{};
      final isFav = data['is_favorited'] == true;

      final updated = <int>{...state.valueOrNull ?? next};
      if (isFav) {
        updated.add(seriesId);
      } else {
        updated.remove(seriesId);
      }
      state = AsyncData(updated);
      return isFav;
    } on DioException catch (e, st) {
      final code = e.response?.statusCode ?? 0;
      if (code == 401 || code == 403) {
        await ref.read(authSessionProvider.notifier).logout();
        state = AsyncData(current);
        return null;
      }
      state = AsyncError(e, st);
      state = AsyncData(current);
      rethrow;
    } catch (e, st) {
      state = AsyncError(e, st);
      state = AsyncData(current);
      rethrow;
    }
  }
}

final favoritesIdsProvider = AsyncNotifierProvider<FavoritesController, Set<int>>(
  FavoritesController.new,
);
