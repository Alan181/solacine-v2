import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/data/dio_provider.dart';

class SupportTicketSummary {
  const SupportTicketSummary({
    required this.id,
    required this.subject,
    required this.status,
    required this.lastMessage,
    required this.lastMessageAt,
    required this.closedAt,
    required this.createdAt,
  });

  final int id;
  final String subject;
  final String status;
  final String lastMessage;
  final DateTime? lastMessageAt;
  final DateTime? closedAt;
  final DateTime? createdAt;

  bool get isClosed => status == 'closed' || closedAt != null;

  factory SupportTicketSummary.fromJson(Map<String, dynamic> json) {
    DateTime? parseDate(dynamic value) {
      if (value is! String || value.trim().isEmpty) return null;
      return DateTime.tryParse(value);
    }

    return SupportTicketSummary(
      id: (json['id'] as num?)?.toInt() ?? 0,
      subject: (json['subject'] as String?) ?? '',
      status: (json['status'] as String?) ?? 'open',
      lastMessage: (json['last_message'] as String?) ?? '',
      lastMessageAt: parseDate(json['last_message_at']),
      closedAt: parseDate(json['closed_at']),
      createdAt: parseDate(json['created_at']),
    );
  }
}

class SupportTicketPage {
  const SupportTicketPage({
    required this.items,
    required this.currentPage,
    required this.lastPage,
  });

  final List<SupportTicketSummary> items;
  final int currentPage;
  final int lastPage;

  bool get hasMore => currentPage < lastPage;

  factory SupportTicketPage.fromJson(Map<String, dynamic> json) {
    final itemsRaw = json['data'];
    final items = itemsRaw is List
        ? itemsRaw
            .whereType<Map>()
            .map((e) => SupportTicketSummary.fromJson(e.cast<String, dynamic>()))
            .toList()
        : <SupportTicketSummary>[];

    return SupportTicketPage(
      items: items,
      currentPage: (json['current_page'] as num?)?.toInt() ?? 1,
      lastPage: (json['last_page'] as num?)?.toInt() ?? 1,
    );
  }
}

class SupportTicketMessage {
  const SupportTicketMessage({
    required this.id,
    required this.sender,
    required this.body,
    required this.createdAt,
  });

  final int id;
  final String sender;
  final String body;
  final DateTime? createdAt;

  bool get isSupport => sender == 'support';

  factory SupportTicketMessage.fromJson(Map<String, dynamic> json) {
    DateTime? parseDate(dynamic value) {
      if (value is! String || value.trim().isEmpty) return null;
      return DateTime.tryParse(value);
    }

    return SupportTicketMessage(
      id: (json['id'] as num?)?.toInt() ?? 0,
      sender: (json['sender'] as String?) ?? 'user',
      body: (json['body'] as String?) ?? '',
      createdAt: parseDate(json['created_at']),
    );
  }
}

class SupportTicketDetails {
  const SupportTicketDetails({
    required this.id,
    required this.subject,
    required this.status,
    required this.closedAt,
    required this.createdAt,
    required this.messages,
  });

  final int id;
  final String subject;
  final String status;
  final DateTime? closedAt;
  final DateTime? createdAt;
  final List<SupportTicketMessage> messages;

  bool get isClosed => status == 'closed' || closedAt != null;

  factory SupportTicketDetails.fromJson(Map<String, dynamic> json) {
    DateTime? parseDate(dynamic value) {
      if (value is! String || value.trim().isEmpty) return null;
      return DateTime.tryParse(value);
    }

    final raw = json['messages'];
    final messages = raw is List
        ? raw.whereType<Map>().map((e) => SupportTicketMessage.fromJson(e.cast<String, dynamic>())).toList()
        : <SupportTicketMessage>[];

    return SupportTicketDetails(
      id: (json['id'] as num?)?.toInt() ?? 0,
      subject: (json['subject'] as String?) ?? '',
      status: (json['status'] as String?) ?? 'open',
      closedAt: parseDate(json['closed_at']),
      createdAt: parseDate(json['created_at']),
      messages: messages,
    );
  }
}

class SupportTicketApi {
  SupportTicketApi(this._dio);

  final Dio _dio;

  Future<SupportTicketPage> list({int page = 1}) async {
    final res = await _dio.get<Map<String, dynamic>>(
      '/v1/support/tickets',
      queryParameters: {'page': page},
    );
    final map = res.data ?? <String, dynamic>{};
    if (map['status'] != true) {
      throw Exception((map['message'] as String?) ?? 'Request failed');
    }
    final data = (map['data'] as Map<String, dynamic>?) ?? <String, dynamic>{};
    return SupportTicketPage.fromJson(data);
  }

  Future<int> create({required String subject, required String message}) async {
    final res = await _dio.post<Map<String, dynamic>>(
      '/v1/support/tickets',
      data: {'subject': subject, 'message': message},
    );
    final map = res.data ?? <String, dynamic>{};
    if (map['status'] != true) {
      throw Exception((map['message'] as String?) ?? 'Request failed');
    }
    final data = (map['data'] as Map<String, dynamic>?) ?? <String, dynamic>{};
    return (data['id'] as num?)?.toInt() ?? 0;
  }

  Future<SupportTicketDetails> get(int id) async {
    final res = await _dio.get<Map<String, dynamic>>('/v1/support/tickets/$id');
    final map = res.data ?? <String, dynamic>{};
    if (map['status'] != true) {
      throw Exception((map['message'] as String?) ?? 'Request failed');
    }
    final data = (map['data'] as Map<String, dynamic>?) ?? <String, dynamic>{};
    return SupportTicketDetails.fromJson(data);
  }

  Future<void> reply({required int id, required String message}) async {
    final res = await _dio.post<Map<String, dynamic>>(
      '/v1/support/tickets/$id/reply',
      data: {'message': message},
    );
    final map = res.data ?? <String, dynamic>{};
    if (map['status'] != true) {
      throw Exception((map['message'] as String?) ?? 'Request failed');
    }
  }

  Future<void> close(int id) async {
    final res = await _dio.post<Map<String, dynamic>>('/v1/support/tickets/$id/close');
    final map = res.data ?? <String, dynamic>{};
    if (map['status'] != true) {
      throw Exception((map['message'] as String?) ?? 'Request failed');
    }
  }
}

final supportTicketApiProvider = Provider<SupportTicketApi>((ref) {
  return SupportTicketApi(ref.watch(dioProvider));
});

