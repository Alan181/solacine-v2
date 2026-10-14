import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/data/dio_provider.dart';

class LanguageDto {
  const LanguageDto({
    required this.code,
    required this.name,
    required this.isDefault,
    this.flag,
  });

  final String code;
  final String name;
  final bool isDefault;
  final String? flag;

  static LanguageDto fromJson(Map<String, dynamic> json) {
    return LanguageDto(
      code: (json['code'] as String?) ?? '',
      name: (json['name'] as String?) ?? '',
      isDefault: json['is_default'] == true,
      flag: json['flag'] as String?,
    );
  }
}

class LocalizationApi {
  LocalizationApi(this._dio);

  final Dio _dio;

  Future<({String defaultCode, List<LanguageDto> languages})> getLanguages() async {
    final res = await _dio.get<Map<String, dynamic>>('/v1/languages');
    final json = res.data ?? const <String, dynamic>{};
    if (json['status'] != true) {
      throw Exception('Failed to load languages');
    }

    final data = (json['data'] as Map<String, dynamic>?) ?? const <String, dynamic>{};
    final def = (data['default'] as String?) ?? '';
    final list = (data['languages'] as List<dynamic>? ?? const <dynamic>[])
        .whereType<Map<String, dynamic>>()
        .map(LanguageDto.fromJson)
        .where((e) => e.code.isNotEmpty)
        .toList();

    return (defaultCode: def, languages: list);
  }

  Future<({String lang, Map<String, String> translations})> getTranslations(String lang) async {
    final res = await _dio.get<Map<String, dynamic>>(
      '/v1/translations',
      queryParameters: {'lang': lang},
    );

    final json = res.data ?? const <String, dynamic>{};
    if (json['status'] != true) {
      throw Exception('Failed to load translations');
    }

    final data = (json['data'] as Map<String, dynamic>?) ?? const <String, dynamic>{};
    final outLang = (data['lang'] as String?) ?? lang;
    final raw = (data['translations'] as Map<String, dynamic>?) ?? const <String, dynamic>{};
    final map = raw.map((k, v) => MapEntry(k, (v as String?) ?? v.toString()));

    return (lang: outLang, translations: map);
  }
}

final localizationApiProvider = Provider<LocalizationApi>((ref) {
  return LocalizationApi(ref.watch(dioProvider));
});

