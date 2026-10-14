import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/data/dio_provider.dart';

class InboxItem {
  const InboxItem({
    required this.id,
    required this.title,
    required this.body,
    required this.imageUrl,
    required this.actionUrl,
    required this.readAt,
    required this.createdAt,
  });

  final String id;
  final String title;
  final String body;
  final String imageUrl;
  final String actionUrl;
  final DateTime? readAt;
  final DateTime? createdAt;

  bool get isUnread => readAt == null;

  factory InboxItem.fromJson(Map<String, dynamic> json) {
    DateTime? parseDate(dynamic value) {
      if (value is! String || value.trim().isEmpty) return null;
      return DateTime.tryParse(value);
    }

    return InboxItem(
      id: (json['id'] as String?) ?? '',
      title: (json['title'] as String?) ?? '',
      body: (json['body'] as String?) ?? '',
      imageUrl: (json['image_url'] as String?) ?? '',
      actionUrl: (json['action_url'] as String?) ?? '',
      readAt: parseDate(json['read_at']),
      createdAt: parseDate(json['created_at']),
    );
  }
}

class InboxPage {
  const InboxPage({
    required this.items,
    required this.currentPage,
    required this.lastPage,
  });

  final List<InboxItem> items;
  final int currentPage;
  final int lastPage;

  bool get hasMore => currentPage < lastPage;

  factory InboxPage.fromJson(Map<String, dynamic> json) {
    final itemsRaw = json['data'];
    final items = itemsRaw is List
        ? itemsRaw.whereType<Map>().map((e) => InboxItem.fromJson(e.cast<String, dynamic>())).toList()
        : <InboxItem>[];

    return InboxPage(
      items: items,
      currentPage: (json['current_page'] as num?)?.toInt() ?? 1,
      lastPage: (json['last_page'] as num?)?.toInt() ?? 1,
    );
  }
}

class InboxApi {
  InboxApi(this._dio);

  final Dio _dio;

  Future<InboxPage> list({int page = 1}) async {
    final res = await _dio.get<Map<String, dynamic>>(
      '/v1/inbox',
      queryParameters: {'page': page},
    );
    final map = res.data ?? <String, dynamic>{};
    if (map['status'] != true) {
      throw Exception((map['message'] as String?) ?? 'Request failed');
    }
    final data = (map['data'] as Map<String, dynamic>?) ?? <String, dynamic>{};
    return InboxPage.fromJson(data);
  }

  Future<int> unreadCount() async {
    final res = await _dio.get<Map<String, dynamic>>('/v1/inbox/unread-count');
    final map = res.data ?? <String, dynamic>{};
    if (map['status'] != true) {
      throw Exception((map['message'] as String?) ?? 'Request failed');
    }
    final data = (map['data'] as Map<String, dynamic>?) ?? <String, dynamic>{};
    return (data['count'] as num?)?.toInt() ?? 0;
  }

  Future<void> read(String id) async {
    final res = await _dio.post<Map<String, dynamic>>('/v1/inbox/$id/read');
    final map = res.data ?? <String, dynamic>{};
    if (map['status'] != true) {
      throw Exception((map['message'] as String?) ?? 'Request failed');
    }
  }

  Future<void> readAll() async {
    final res = await _dio.post<Map<String, dynamic>>('/v1/inbox/read-all');
    final map = res.data ?? <String, dynamic>{};
    if (map['status'] != true) {
      throw Exception((map['message'] as String?) ?? 'Request failed');
    }
  }

  Future<void> delete(String id) async {
    final res = await _dio.delete<Map<String, dynamic>>('/v1/inbox/$id');
    final map = res.data ?? <String, dynamic>{};
    if (map['status'] != true) {
      throw Exception((map['message'] as String?) ?? 'Request failed');
    }
  }
}

final inboxApiProvider = Provider<InboxApi>((ref) {
  return InboxApi(ref.watch(dioProvider));
});

