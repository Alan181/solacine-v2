import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/data/dio_provider.dart';

class UserDevice {
  const UserDevice({
    required this.id,
    required this.deviceUid,
    required this.platform,
    required this.brand,
    required this.model,
    required this.deviceName,
    required this.osVersion,
    required this.systemName,
    required this.appVersion,
    required this.appBuild,
    required this.isPhysicalDevice,
    required this.lastSeenAt,
    required this.createdAt,
  });

  final int id;
  final String deviceUid;
  final String platform;
  final String brand;
  final String model;
  final String deviceName;
  final String osVersion;
  final String systemName;
  final String appVersion;
  final String appBuild;
  final bool? isPhysicalDevice;
  final DateTime? lastSeenAt;
  final DateTime? createdAt;

  factory UserDevice.fromJson(Map<String, dynamic> json) {
    DateTime? parseDate(dynamic value) {
      if (value is! String || value.trim().isEmpty) return null;
      return DateTime.tryParse(value);
    }

    return UserDevice(
      id: (json['id'] as num?)?.toInt() ?? 0,
      deviceUid: (json['device_uid'] as String?) ?? '',
      platform: (json['platform'] as String?) ?? '',
      brand: (json['brand'] as String?) ?? '',
      model: (json['model'] as String?) ?? '',
      deviceName: (json['device_name'] as String?) ?? '',
      osVersion: (json['os_version'] as String?) ?? '',
      systemName: (json['system_name'] as String?) ?? '',
      appVersion: (json['app_version'] as String?) ?? '',
      appBuild: (json['app_build'] as String?) ?? '',
      isPhysicalDevice: json['is_physical_device'] as bool?,
      lastSeenAt: parseDate(json['last_seen_at']),
      createdAt: parseDate(json['created_at']),
    );
  }
}

class DevicesApi {
  DevicesApi(this._dio);

  final Dio _dio;

  Future<void> registerDevice({
    required String deviceUid,
    required String platform,
    String? brand,
    String? model,
    String? deviceName,
    String? osVersion,
    String? systemName,
    String? appVersion,
    String? appBuild,
    String? fcmToken,
    bool? isPhysicalDevice,
  }) async {
    final res = await _dio.post<Map<String, dynamic>>(
      '/v1/device/register',
      data: {
        'device_uid': deviceUid,
        'platform': platform,
        ...?(brand == null ? null : {'brand': brand}),
        ...?(model == null ? null : {'model': model}),
        ...?(deviceName == null ? null : {'device_name': deviceName}),
        ...?(osVersion == null ? null : {'os_version': osVersion}),
        ...?(systemName == null ? null : {'system_name': systemName}),
        ...?(appVersion == null ? null : {'app_version': appVersion}),
        ...?(appBuild == null ? null : {'app_build': appBuild}),
        ...?(fcmToken == null ? null : {'fcm_token': fcmToken}),
        ...?(isPhysicalDevice == null ? null : {'is_physical_device': isPhysicalDevice}),
      },
    );
    final map = res.data ?? <String, dynamic>{};
    if (map['status'] != true) {
      throw Exception((map['message'] as String?) ?? 'Request failed');
    }
  }

  Future<List<UserDevice>> listDevices() async {
    final res = await _dio.get<Map<String, dynamic>>('/v1/devices');
    final map = res.data ?? <String, dynamic>{};
    if (map['status'] != true) {
      throw Exception((map['message'] as String?) ?? 'Request failed');
    }
    final data = (map['data'] as Map<String, dynamic>?) ?? <String, dynamic>{};
    final itemsRaw = data['items'];
    return itemsRaw is List
        ? itemsRaw.whereType<Map>().map((e) => UserDevice.fromJson(e.cast<String, dynamic>())).toList()
        : <UserDevice>[];
  }
}

final devicesApiProvider = Provider<DevicesApi>((ref) {
  return DevicesApi(ref.watch(dioProvider));
});
