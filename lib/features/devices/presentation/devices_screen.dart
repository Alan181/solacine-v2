import 'dart:io';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../app/i18n.dart';
import '../../../shared/data/shared_prefs_provider.dart';
import '../../auth/application/auth_controller.dart';
import '../data/devices_api.dart';

class DevicesScreen extends ConsumerStatefulWidget {
  const DevicesScreen({super.key});

  @override
  ConsumerState<DevicesScreen> createState() => _DevicesScreenState();
}

class _DevicesScreenState extends ConsumerState<DevicesScreen> {
  List<UserDevice> _items = const <UserDevice>[];
  String? _currentUid;
  Object? _error;
  bool _loading = true;
  bool _refreshing = false;

  @override
  void initState() {
    super.initState();
    Future.microtask(() => _load(showLoader: true));
  }

  Future<void> _loadCurrentUid() async {
    try {
      final prefs = await ref.read(sharedPrefsProvider.future);
      var uid = (prefs.getString('device_uid') ?? '').trim();
      if (uid.isEmpty && !kIsWeb) {
        final plugin = DeviceInfoPlugin();
        if (Platform.isAndroid) {
          final info = await plugin.androidInfo;
          uid = info.fingerprint.trim();
        } else if (Platform.isIOS) {
          final info = await plugin.iosInfo;
          uid = (info.identifierForVendor ?? '').trim();
        }
      }
      if (mounted && uid.isNotEmpty) {
        setState(() => _currentUid = uid);
      }
    } catch (_) {}
  }

  Future<void> _load({required bool showLoader}) async {
    setState(() {
      _error = null;
      _loading = showLoader;
      _refreshing = !showLoader;
    });

    await _loadCurrentUid();

    try {
      final res = await ref.read(devicesApiProvider).listDevices();
      if (!mounted) return;
      setState(() => _items = res);
    } on DioException catch (e) {
      final code = e.response?.statusCode ?? 0;
      if (code == 401 || code == 403) {
        await ref.read(authSessionProvider.notifier).logout();
        return;
      }
      if (!mounted) return;
      setState(() => _error = e);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e);
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
          _refreshing = false;
        });
      }
    }
  }

  bool _isCurrentDevice(UserDevice d, int index) {
    if (_currentUid != null && _currentUid!.trim().isNotEmpty) {
      if (d.deviceUid.trim() == _currentUid!.trim()) return true;
    }
    // Fallback: if only one device or no uid matched, the first most recent device
    if ((_currentUid == null || _currentUid!.isEmpty) && index == 0) {
      return true;
    }
    return false;
  }

  String _formatTime(BuildContext context, DateTime? dt) {
    if (dt == null) return '';
    final now = DateTime.now();
    final local = dt.toLocal();
    final diff = now.difference(local);

    final t = AppI18n.of(context);
    if (diff.inMinutes.abs() < 10) {
      return t.t('active_now');
    }

    final locale = Localizations.localeOf(context).languageCode;
    final timeStr = DateFormat('hh:mm a', locale).format(local);
    final isSameDay = now.year == local.year && now.month == local.month && now.day == local.day;

    if (isSameDay) {
      return timeStr;
    }

    final dateStr = DateFormat('yyyy-MM-dd', locale).format(local);
    return '$dateStr $timeStr';
  }

  String _titleOf(UserDevice d) {
    final name = d.deviceName.trim();
    final brand = d.brand.trim();
    final model = d.model.trim();

    if (brand.isNotEmpty && model.isNotEmpty) {
      if (model.toLowerCase().contains(brand.toLowerCase())) {
        return model;
      }
      return '$brand $model';
    }
    if (name.isNotEmpty) return name;
    if (brand.isNotEmpty) return brand;
    if (model.isNotEmpty) return model;
    return d.platform.trim().isEmpty ? 'Device' : d.platform;
  }

  IconData _iconOf(UserDevice d) {
    final p = d.platform.trim().toLowerCase();
    final m = d.model.trim().toLowerCase();
    final b = d.brand.trim().toLowerCase();

    if (m.contains('ipad') || m.contains('tablet') || b.contains('tablet')) {
      return p == 'ios' ? Icons.tablet_mac_rounded : Icons.tablet_android_rounded;
    }
    if (p == 'android') {
      return Icons.phone_android_rounded;
    }
    if (p == 'ios') {
      return Icons.phone_iphone_rounded;
    }
    if (p == 'web') {
      return Icons.laptop_chromebook_rounded;
    }
    return Icons.devices_rounded;
  }

  void _showDeviceDetails(UserDevice d, bool isCurrent) {
    final t = AppI18n.of(context);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xff0b0b0b),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 36,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.18),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                Row(
                  children: [
                    Container(
                      width: 46,
                      height: 46,
                      decoration: BoxDecoration(
                        color: isCurrent
                            ? const Color(0xff22c55e).withValues(alpha: 0.12)
                            : Colors.white.withValues(alpha: 0.06),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: isCurrent
                              ? const Color(0xff22c55e).withValues(alpha: 0.28)
                              : Colors.white.withValues(alpha: 0.08),
                        ),
                      ),
                      child: Icon(
                        _iconOf(d),
                        color: isCurrent ? const Color(0xff22c55e) : Colors.white.withValues(alpha: 0.85),
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _titleOf(d),
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.95),
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Container(
                                width: 7,
                                height: 7,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: isCurrent ? const Color(0xff22c55e) : Colors.white.withValues(alpha: 0.35),
                                ),
                              ),
                              const SizedBox(width: 6),
                              Text(
                                isCurrent
                                    ? '${t.t('this_device')} • ${t.t('current_session')}'
                                    : t.t('registered_session'),
                                style: TextStyle(
                                  color: isCurrent ? const Color(0xff22c55e) : Colors.white.withValues(alpha: 0.55),
                                  fontSize: 12,
                                  fontWeight: isCurrent ? FontWeight.w600 : FontWeight.w400,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: Icon(Icons.close_rounded, color: Colors.white.withValues(alpha: 0.6)),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Divider(color: Colors.white.withValues(alpha: 0.07), height: 1),
                const SizedBox(height: 14),
                _buildInfoTile(
                  icon: Icons.info_outline_rounded,
                  label: t.t('operating_system'),
                  value: '${d.platform.toUpperCase()} ${d.osVersion}'.trim(),
                ),
                if (d.brand.isNotEmpty || d.model.isNotEmpty)
                  _buildInfoTile(
                    icon: Icons.phone_android_outlined,
                    label: t.t('brand_and_model'),
                    value: '${d.brand} ${d.model}'.trim(),
                  ),
                if (d.appVersion.isNotEmpty)
                  _buildInfoTile(
                    icon: Icons.apps_rounded,
                    label: t.t('app_version'),
                    value: 'v${d.appVersion}${d.appBuild.isNotEmpty ? ' (${d.appBuild})' : ''}',
                  ),
                _buildInfoTile(
                  icon: Icons.access_time_rounded,
                  label: t.t('last_active'),
                  value: _formatTime(context, d.lastSeenAt),
                ),
                if (d.createdAt != null)
                  _buildInfoTile(
                    icon: Icons.login_rounded,
                    label: t.t('first_sign_in'),
                    value: _formatTime(context, d.createdAt),
                  ),
                if (d.deviceUid.isNotEmpty)
                  _buildInfoTile(
                    icon: Icons.fingerprint_rounded,
                    label: t.t('device_identifier'),
                    value: d.deviceUid.length > 20
                        ? '${d.deviceUid.substring(0, 10)}...${d.deviceUid.substring(d.deviceUid.length - 8)}'
                        : d.deviceUid,
                  ),
                const SizedBox(height: 18),
                if (!isCurrent) ...[
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xffef233c).withValues(alpha: 0.10),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: const Color(0xffef233c).withValues(alpha: 0.22)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.shield_outlined, color: Color(0xffef233c), size: 20),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            t.t('unrecognized_device_warning'),
                            style: const TextStyle(color: Color(0xffef233c), fontSize: 12),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    height: 44,
                    child: OutlinedButton.icon(
                      onPressed: () {
                        Navigator.pop(context);
                        context.push('/account/password');
                      },
                      icon: const Icon(Icons.lock_reset_rounded, size: 18),
                      label: Text(t.t('change_password_secure')),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.white.withValues(alpha: 0.95),
                        side: BorderSide(color: Colors.white.withValues(alpha: 0.20)),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ),
                ] else ...[
                  SizedBox(
                    width: double.infinity,
                    height: 44,
                    child: FilledButton.tonal(
                      onPressed: () => Navigator.pop(context),
                      style: FilledButton.styleFrom(
                        backgroundColor: Colors.white.withValues(alpha: 0.08),
                        foregroundColor: Colors.white.withValues(alpha: 0.92),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: Text(t.t('close')),
                    ),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildInfoTile({required IconData icon, required String label, required String value}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Icon(icon, size: 18, color: Colors.white.withValues(alpha: 0.40)),
          const SizedBox(width: 12),
          Text(
            label,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.55),
              fontSize: 13,
            ),
          ),
          const Spacer(),
          Text(
            value,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.90),
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = AppI18n.of(context);
    final hasData = _items.isNotEmpty;

    // Split current device vs other devices
    UserDevice? currentDevice;
    final otherDevices = <UserDevice>[];

    for (var i = 0; i < _items.length; i++) {
      final item = _items[i];
      if (_isCurrentDevice(item, i) && currentDevice == null) {
        currentDevice = item;
      } else {
        otherDevices.add(item);
      }
    }

    return Scaffold(
      backgroundColor: const Color(0xff050505),
      appBar: AppBar(
        backgroundColor: const Color(0xff050505),
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
        foregroundColor: Colors.white.withValues(alpha: 0.92),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => context.pop(),
        ),
        title: Text(
          t.t('devices'),
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: Colors.white.withValues(alpha: 0.95),
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: t.t('retry'),
            onPressed: _refreshing ? null : () => _load(showLoader: false),
          ),
        ],
      ),
      body: _loading
          ? Center(
              child: SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white.withValues(alpha: 0.8),
                ),
              ),
            )
          : RefreshIndicator(
              color: Colors.white,
              backgroundColor: const Color(0xff121212),
              onRefresh: () => _load(showLoader: false),
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
                children: [
                  // App Security Overview Header
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xff0e0e0e),
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: Colors.white.withValues(alpha: 0.07)),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.06),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
                          ),
                          child: Icon(
                            Icons.shield_outlined,
                            color: Colors.white.withValues(alpha: 0.88),
                            size: 22,
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                t.t('where_youre_signed_in'),
                                style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.95),
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                t.t('devices_security_desc'),
                                style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.60),
                                  fontSize: 12.5,
                                  height: 1.4,
                                ),
                              ),
                              const SizedBox(height: 10),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: const Color(0xff22c55e).withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(color: const Color(0xff22c55e).withValues(alpha: 0.28)),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(Icons.check_circle_rounded, color: Color(0xff22c55e), size: 14),
                                    const SizedBox(width: 6),
                                    Text(
                                      _items.length == 1
                                          ? t.t('one_device_count')
                                          : t.t('devices_count', params: {'count': _items.length.toString()}),
                                      style: const TextStyle(
                                        color: Color(0xff22c55e),
                                        fontSize: 11.5,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 18),

                  if (_error != null)
                    Container(
                      margin: const EdgeInsets.only(bottom: 16),
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: const Color(0xffef233c).withValues(alpha: 0.10),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: const Color(0xffef233c).withValues(alpha: 0.25)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.error_outline_rounded, color: Color(0xffef233c), size: 22),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              t.t('request_failed'),
                              style: const TextStyle(color: Color(0xffef233c), fontSize: 13),
                            ),
                          ),
                          TextButton(
                            onPressed: _refreshing ? null : () => _load(showLoader: false),
                            style: TextButton.styleFrom(foregroundColor: Colors.white),
                            child: Text(t.t('retry')),
                          ),
                        ],
                      ),
                    ),

                  if (!hasData && _error == null)
                    Padding(
                      padding: const EdgeInsets.only(top: 40),
                      child: Center(
                        child: Column(
                          children: [
                            Icon(Icons.devices_other_rounded, size: 48, color: Colors.white.withValues(alpha: 0.25)),
                            const SizedBox(height: 12),
                            Text(
                              t.t('no_devices'),
                              style: TextStyle(color: Colors.white.withValues(alpha: 0.45), fontSize: 14),
                            ),
                          ],
                        ),
                      ),
                    ),

                  // Section: Current Device
                  if (currentDevice != null) ...[
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8, right: 4, left: 4),
                      child: Row(
                        children: [
                          Container(
                            width: 6,
                            height: 6,
                            decoration: const BoxDecoration(
                              shape: BoxShape.circle,
                              color: Color(0xff22c55e),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            t.t('current_session'),
                            style: const TextStyle(
                              color: Color(0xff22c55e),
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              letterSpacing: 0.2,
                            ),
                          ),
                        ],
                      ),
                    ),
                    _buildGoogleDeviceCard(
                      context: context,
                      device: currentDevice,
                      isCurrent: true,
                    ),
                    const SizedBox(height: 18),
                  ],

                  // Section: Other Devices
                  if (otherDevices.isNotEmpty) ...[
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8, right: 4, left: 4),
                      child: Text(
                        t.t('other_devices'),
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.65),
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.2,
                        ),
                      ),
                    ),
                    ...otherDevices.map(
                      (d) => Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: _buildGoogleDeviceCard(
                          context: context,
                          device: d,
                          isCurrent: false,
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                  ],

                  // Security Tip Card at bottom
                  if (hasData)
                    Container(
                      margin: const EdgeInsets.only(top: 8),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: const Color(0xff0e0e0e),
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(color: Colors.white.withValues(alpha: 0.07)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.lock_outline_rounded, color: Colors.white.withValues(alpha: 0.85), size: 20),
                              const SizedBox(width: 10),
                              Text(
                                t.t('dont_recognize_device'),
                                style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.95),
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            t.t('dont_recognize_device_desc'),
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.55),
                              fontSize: 12,
                              height: 1.4,
                            ),
                          ),
                          const SizedBox(height: 14),
                          SizedBox(
                            width: double.infinity,
                            height: 38,
                            child: OutlinedButton(
                              onPressed: () => context.push('/account/password'),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: Colors.white.withValues(alpha: 0.92),
                                side: BorderSide(color: Colors.white.withValues(alpha: 0.12)),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              ),
                              child: Text(
                                t.t('change_password'),
                                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
    );
  }

  Widget _buildGoogleDeviceCard({
    required BuildContext context,
    required UserDevice device,
    required bool isCurrent,
  }) {
    final t = AppI18n.of(context);
    final title = _titleOf(device);
    final icon = _iconOf(device);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => _showDeviceDetails(device, isCurrent),
        borderRadius: BorderRadius.circular(18),
        child: Container(
          decoration: BoxDecoration(
            color: const Color(0xff0e0e0e),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: isCurrent
                  ? const Color(0xff22c55e).withValues(alpha: 0.35)
                  : Colors.white.withValues(alpha: 0.07),
              width: isCurrent ? 1.2 : 1.0,
            ),
          ),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Device Brand/Platform Icon Container
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: isCurrent
                          ? const Color(0xff22c55e).withValues(alpha: 0.12)
                          : Colors.white.withValues(alpha: 0.06),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: isCurrent
                            ? const Color(0xff22c55e).withValues(alpha: 0.22)
                            : Colors.white.withValues(alpha: 0.06),
                      ),
                    ),
                    child: Icon(
                      icon,
                      color: isCurrent ? const Color(0xff22c55e) : Colors.white.withValues(alpha: 0.85),
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 14),
                  // Device Title & Metadata
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                title,
                                style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.95),
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            if (isCurrent) ...[
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: const Color(0xff22c55e).withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: const Color(0xff22c55e).withValues(alpha: 0.30),
                                  ),
                                ),
                                child: Text(
                                  t.t('this_device'),
                                  style: const TextStyle(
                                    color: Color(0xff22c55e),
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: 4),
                        // Subtitle row (System info • App version)
                        Text(
                          [
                            device.platform.trim().toUpperCase(),
                            if (device.osVersion.trim().isNotEmpty) device.osVersion.trim(),
                            if (device.appVersion.trim().isNotEmpty) 'v${device.appVersion.trim()}',
                          ].where((s) => s.isNotEmpty).join(' • '),
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.50),
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Divider(color: Colors.white.withValues(alpha: 0.06), height: 1),
              const SizedBox(height: 10),
              // Activity Row & Chevron
              Row(
                children: [
                  Icon(
                    Icons.access_time_rounded,
                    size: 14,
                    color: isCurrent ? const Color(0xff22c55e) : Colors.white.withValues(alpha: 0.35),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    isCurrent
                        ? t.t('active_now_on_device')
                        : '${t.t('last_active')}: ${_formatTime(context, device.lastSeenAt)}',
                    style: TextStyle(
                      color: isCurrent ? const Color(0xff22c55e) : Colors.white.withValues(alpha: 0.45),
                      fontSize: 12,
                      fontWeight: isCurrent ? FontWeight.w500 : FontWeight.w400,
                    ),
                  ),
                  const Spacer(),
                  Icon(
                    Icons.chevron_right_rounded,
                    color: Colors.white.withValues(alpha: 0.30),
                    size: 20,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
