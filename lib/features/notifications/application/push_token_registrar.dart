import 'dart:async';
import 'dart:io';
import 'dart:math';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../auth/application/auth_controller.dart';
import '../../devices/data/devices_api.dart';
import '../../../shared/data/shared_prefs_provider.dart';
import '../data/push_token_api.dart';

class PushTokenRegistrar extends ConsumerStatefulWidget {
  const PushTokenRegistrar({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<PushTokenRegistrar> createState() => _PushTokenRegistrarState();
}

class _PushTokenRegistrarState extends ConsumerState<PushTokenRegistrar> {
  StreamSubscription<String>? _sub;
  StreamSubscription<RemoteMessage>? _msgSub;
  StreamSubscription<RemoteMessage>? _openSub;
  String? _lastSentToken;
  String? _deviceUid;
  int? _deviceRegisteredUserId;
  bool _registeringDevice = false;
  bool _permissionRequestedInMemory = false;
  bool _localInit = false;
  final FlutterLocalNotificationsPlugin _local = FlutterLocalNotificationsPlugin();

  @override
  void initState() {
    super.initState();
    Future.microtask(_init);
  }

  @override
  void dispose() {
    _sub?.cancel();
    _msgSub?.cancel();
    _openSub?.cancel();
    super.dispose();
  }

  Future<void> _init() async {
    if (kIsWeb) return;

    await _initLocalNotifications();

    _sub ??= FirebaseMessaging.instance.onTokenRefresh.listen((token) {
      _trySend(token);
    });

    _msgSub ??= FirebaseMessaging.onMessage.listen(_onMessage);
    _openSub ??= FirebaseMessaging.onMessageOpenedApp.listen(_onMessageOpenedApp);

    try {
      final initial = await FirebaseMessaging.instance.getInitialMessage();
      if (initial != null) {
        await _onMessageOpenedApp(initial);
      }
    } catch (_) {}

    try {
      final token = await FirebaseMessaging.instance.getToken();
      if (token == null || token.trim().isEmpty) return;
      _trySend(token);
    } catch (_) {}
  }

  Future<void> _initLocalNotifications() async {
    if (_localInit) return;
    _localInit = true;

    const android = AndroidInitializationSettings('@drawable/ic_stat_notify');
    const ios = DarwinInitializationSettings();

    await _local.initialize(
      settings: const InitializationSettings(android: android, iOS: ios),
      onDidReceiveNotificationResponse: (resp) async {
        final payload = (resp.payload ?? '').trim();
        await _openUrl(payload);
      },
    );

    const channel = AndroidNotificationChannel(
      'high_importance_channel',
      'Notifications',
      description: 'High importance notifications',
      importance: Importance.high,
    );

    final androidImpl = _local.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    await androidImpl?.createNotificationChannel(channel);
  }

  Future<void> _onMessage(RemoteMessage message) async {
    final n = message.notification;
    final title = (n?.title ?? message.data['title'] ?? '').toString();
    final body = (n?.body ?? message.data['body'] ?? message.data['message'] ?? '').toString();
    if (title.trim().isEmpty && body.trim().isEmpty) return;

    final payload = (message.data['url'] ?? message.data['click_action'] ?? '').toString().trim();

    const details = NotificationDetails(
      android: AndroidNotificationDetails(
        'high_importance_channel',
        'Notifications',
        channelDescription: 'High importance notifications',
        importance: Importance.max,
        priority: Priority.high,
        icon: '@drawable/ic_stat_notify',
      ),
      iOS: DarwinNotificationDetails(),
    );

    await _local.show(
      id: DateTime.now().millisecondsSinceEpoch ~/ 1000,
      title: title,
      body: body,
      notificationDetails: details,
      payload: payload.isEmpty ? null : payload,
    );
  }

  Future<void> _onMessageOpenedApp(RemoteMessage message) async {
    final payload = (message.data['url'] ?? message.data['click_action'] ?? '').toString().trim();
    await _openUrl(payload);
  }

  Future<void> _openUrl(String value) async {
    final v = value.trim();
    if (v.isEmpty) return;
    final uri = Uri.tryParse(v);
    if (uri == null) return;
    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {}
  }

  Future<void> _maybeRequestPermissionOnce() async {
    if (kIsWeb) return;
    if (_permissionRequestedInMemory) return;
    _permissionRequestedInMemory = true;

    try {
      final prefs = await ref.read(sharedPrefsProvider.future);
      final requested = prefs.getBool('push_permission_requested') ?? false;
      if (requested) return;
      await FirebaseMessaging.instance.requestPermission();
      await prefs.setBool('push_permission_requested', true);
    } catch (_) {}
  }

  String _platform() {
    if (kIsWeb) return 'web';
    if (Platform.isIOS) return 'ios';
    return 'android';
  }

  String _randomUid() {
    const chars = 'abcdefghijklmnopqrstuvwxyz0123456789';
    final rand = Random.secure();
    final out = StringBuffer();
    for (var i = 0; i < 24; i++) {
      out.write(chars[rand.nextInt(chars.length)]);
    }
    out.write('-');
    out.write(DateTime.now().microsecondsSinceEpoch.toString());
    return out.toString();
  }

  Future<String?> _getOrCreateDeviceUid() async {
    if (kIsWeb) return null;
    final cached = (_deviceUid ?? '').trim();
    if (cached.isNotEmpty) return cached;

    final prefs = await ref.read(sharedPrefsProvider.future);
    final saved = (prefs.getString('device_uid') ?? '').trim();
    if (saved.isNotEmpty) {
      _deviceUid = saved;
      return saved;
    }

    var uid = '';
    try {
      final plugin = DeviceInfoPlugin();
      if (Platform.isAndroid) {
        final info = await plugin.androidInfo;
        uid = info.fingerprint.trim();
      } else if (Platform.isIOS) {
        final info = await plugin.iosInfo;
        uid = (info.identifierForVendor ?? '').trim();
      }
    } catch (_) {}

    if (uid.isEmpty) uid = _randomUid();
    await prefs.setString('device_uid', uid);
    _deviceUid = uid;
    return uid;
  }

  Future<void> _registerDevice({String? fcmToken}) async {
    if (kIsWeb) return;
    if (_registeringDevice) return;

    final session = ref.read(authSessionProvider).valueOrNull;
    if (session == null) return;

    final rawId = session.user?['id'];
    final userId = rawId is num ? rawId.toInt() : int.tryParse(rawId?.toString() ?? '');
    if (userId != null && _deviceRegisteredUserId == userId) return;

    _registeringDevice = true;
    try {
      final uid = await _getOrCreateDeviceUid();
      if (uid == null || uid.trim().isEmpty) return;

      final pkg = await PackageInfo.fromPlatform();
      final plugin = DeviceInfoPlugin();

      String? brand;
      String? model;
      String? deviceName;
      String? osVersion;
      String? systemName;
      bool? isPhysicalDevice;

      if (Platform.isAndroid) {
        final info = await plugin.androidInfo;
        brand = info.brand;
        model = info.model;
        deviceName = info.device;
        osVersion = info.version.release;
        systemName = 'Android';
        isPhysicalDevice = info.isPhysicalDevice;
      } else if (Platform.isIOS) {
        final info = await plugin.iosInfo;
        brand = 'Apple';
        model = info.utsname.machine;
        deviceName = info.name;
        osVersion = info.systemVersion;
        systemName = info.systemName;
        isPhysicalDevice = info.isPhysicalDevice;
      }

      await ref.read(devicesApiProvider).registerDevice(
            deviceUid: uid,
            platform: _platform(),
            brand: brand?.trim().isEmpty == true ? null : brand,
            model: model?.trim().isEmpty == true ? null : model,
            deviceName: deviceName?.trim().isEmpty == true ? null : deviceName,
            osVersion: osVersion?.trim().isEmpty == true ? null : osVersion,
            systemName: systemName?.trim().isEmpty == true ? null : systemName,
            appVersion: pkg.version.trim().isEmpty ? null : pkg.version,
            appBuild: pkg.buildNumber.trim().isEmpty ? null : pkg.buildNumber,
            fcmToken: (fcmToken ?? '').trim().isEmpty ? null : fcmToken,
            isPhysicalDevice: isPhysicalDevice,
          );

      if (userId != null) _deviceRegisteredUserId = userId;
    } catch (_) {
      return;
    } finally {
      _registeringDevice = false;
    }
  }

  Future<void> _trySend(String token) async {
    final session = ref.read(authSessionProvider).valueOrNull;
    if (session == null) return;
    if (token == _lastSentToken) return;

    try {
      final uid = await _getOrCreateDeviceUid();
      await ref.read(pushTokenApiProvider).register(token: token, platform: _platform(), deviceUid: uid);
      _lastSentToken = token;
    } catch (_) {
      return;
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(authSessionProvider, (previous, next) async {
      final session = next.valueOrNull;
      if (session == null) return;
      if (kIsWeb) return;
      await _maybeRequestPermissionOnce();
      try {
        final token = await FirebaseMessaging.instance.getToken();
        final normalized = (token ?? '').trim();
        await _registerDevice(fcmToken: normalized.isEmpty ? null : normalized);
        if (normalized.isEmpty) return;
        await _trySend(normalized);
      } catch (_) {}
    });

    return widget.child;
  }
}
