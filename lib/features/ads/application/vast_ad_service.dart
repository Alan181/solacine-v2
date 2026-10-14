import 'dart:async';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

class VastAdData {
  const VastAdData({
    required this.mediaUrl,
    required this.clickThroughUrl,
    required this.clickTrackingUrls,
    required this.impressions,
    required this.trackingEvents,
    required this.skipSeconds,
  });

  final String mediaUrl;
  final String clickThroughUrl;
  final List<String> clickTrackingUrls;
  final List<String> impressions;
  final Map<String, List<String>> trackingEvents;
  final int skipSeconds;
}

class VastAdService {
  VastAdService({Dio? dio}) : _dio = dio ?? Dio(
    BaseOptions(
      connectTimeout: const Duration(seconds: 4),
      receiveTimeout: const Duration(seconds: 4),
      headers: {
        'Accept': 'application/xml, text/xml, */*',
        'User-Agent': 'DrameReel-MobileApp/1.0',
      },
    ),
  );

  final Dio _dio;

  static String cleanXmlUrl(String raw) {
    var u = raw.trim();
    if (u.contains('<![CDATA[')) {
      u = u.replaceAll('<![CDATA[', '').replaceAll(']]>', '').trim();
    }
    u = u
        .replaceAll('&amp;', '&')
        .replaceAll('&quot;', '"')
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>');
    // Remove internal newlines and whitespace that XML feeds frequently contain
    u = u.replaceAll(RegExp(r'\s+'), '');
    return u;
  }

  static void sendPings(List<String> urls) {
    if (urls.isEmpty) return;
    final dio = Dio(
      BaseOptions(
        connectTimeout: const Duration(seconds: 4),
        receiveTimeout: const Duration(seconds: 4),
      ),
    );
    for (final raw in urls) {
      final u = cleanXmlUrl(raw);
      if (!u.startsWith('http://') && !u.startsWith('https://')) continue;
      unawaited(
        dio.get<void>(u).catchError((Object err) {
          debugPrint('[VAST Ping Error] $u: $err');
          return Response<void>(requestOptions: RequestOptions(path: u));
        }),
      );
    }
  }

  static VastAdData? _cachedAd;
  static DateTime? _cacheTimestamp;
  static bool _isPreloading = false;

  /// Preloads a VAST ad in the background so it is instantly ready in memory.
  static Future<void> preload(String tagUrl, {int defaultSkipSeconds = 5}) async {
    final clean = cleanXmlUrl(tagUrl);
    if (clean.isEmpty) return;
    if (_isPreloading) return;
    if (_cachedAd != null && _cacheTimestamp != null && DateTime.now().difference(_cacheTimestamp!).inMinutes < 10) {
      return;
    }
    _isPreloading = true;
    try {
      final ad = await VastAdService().loadVastAd(clean, defaultSkipSeconds: defaultSkipSeconds);
      if (ad != null) {
        _cachedAd = ad;
        _cacheTimestamp = DateTime.now();
      }
    } catch (_) {
    } finally {
      _isPreloading = false;
    }
  }

  /// Returns cached ad immediately (0ms), or fetches with a strict 1.5s timeout so episode clicks are never delayed.
  static Future<VastAdData?> getOrFetchVastAd(String tagUrl, {int defaultSkipSeconds = 5}) async {
    final clean = cleanXmlUrl(tagUrl);
    if (clean.isEmpty) return null;

    if (_cachedAd != null && _cacheTimestamp != null && DateTime.now().difference(_cacheTimestamp!).inMinutes < 10) {
      final ad = _cachedAd;
      _cachedAd = null;
      _cacheTimestamp = null;
      unawaited(preload(clean, defaultSkipSeconds: defaultSkipSeconds));
      return ad;
    }

    try {
      final ad = await VastAdService()
          .loadVastAd(clean, defaultSkipSeconds: defaultSkipSeconds)
          .timeout(const Duration(milliseconds: 1500));
      unawaited(preload(clean, defaultSkipSeconds: defaultSkipSeconds));
      return ad;
    } catch (_) {
      unawaited(preload(clean, defaultSkipSeconds: defaultSkipSeconds));
      return null;
    }
  }

  static Future<VastAdData?> fetchVastAd(String tagUrl, {int defaultSkipSeconds = 5}) {
    return getOrFetchVastAd(tagUrl, defaultSkipSeconds: defaultSkipSeconds);
  }

  Future<VastAdData?> loadVastAd(String tagUrl, {int defaultSkipSeconds = 5}) async {
    final cleanUrl = cleanXmlUrl(tagUrl);
    if (cleanUrl.isEmpty || (!cleanUrl.startsWith('http://') && !cleanUrl.startsWith('https://'))) {
      return null;
    }
    return _fetchAndParse(cleanUrl, defaultSkipSeconds: defaultSkipSeconds, depth: 0);
  }

  Future<VastAdData?> _fetchAndParse(String url, {required int defaultSkipSeconds, required int depth}) async {
    if (depth > 3) return null;
    try {
      final res = await _dio.get<String>(url);
      final xml = res.data ?? '';
      if (xml.trim().isEmpty) return null;

      // Check Wrapper redirect: <VASTAdTagURI>
      final wrapperMatch = RegExp(r'<VASTAdTagURI>([\s\S]*?)<\/VASTAdTagURI>', caseSensitive: false).firstMatch(xml);
      if (wrapperMatch != null) {
        final redirectUrl = cleanXmlUrl(wrapperMatch.group(1) ?? '');
        if (redirectUrl.isNotEmpty) {
          return _fetchAndParse(redirectUrl, defaultSkipSeconds: defaultSkipSeconds, depth: depth + 1);
        }
      }

      // Extract MediaFiles (favor video/mp4)
      final mediaFileMatches = RegExp(
        r'<MediaFile[^>]*>([\s\S]*?)<\/MediaFile>',
        caseSensitive: false,
      ).allMatches(xml);

      String chosenMedia = '';
      for (final m in mediaFileMatches) {
        final rawStr = m.group(0) ?? '';
        final fileUrl = cleanXmlUrl(m.group(1) ?? '');
        if (fileUrl.isEmpty || (!fileUrl.startsWith('http://') && !fileUrl.startsWith('https://'))) continue;
        if (rawStr.toLowerCase().contains('mp4')) {
          chosenMedia = fileUrl;
          break;
        }
        if (chosenMedia.isEmpty) {
          chosenMedia = fileUrl;
        }
      }

      if (chosenMedia.isEmpty) return null;

      // Extract ClickThrough
      final clickMatch = RegExp(
        r'<ClickThrough[^>]*>([\s\S]*?)<\/ClickThrough>',
        caseSensitive: false,
      ).firstMatch(xml);
      final clickThroughUrl = cleanXmlUrl(clickMatch?.group(1) ?? '');

      // Extract ClickTracking
      final clickTrackingUrls = <String>[];
      for (final m in RegExp(r'<ClickTracking[^>]*>([\s\S]*?)<\/ClickTracking>', caseSensitive: false).allMatches(xml)) {
        final u = cleanXmlUrl(m.group(1) ?? '');
        if (u.isNotEmpty) clickTrackingUrls.add(u);
      }

      // Extract Impressions
      final impressions = <String>[];
      for (final m in RegExp(r'<Impression[^>]*>([\s\S]*?)<\/Impression>', caseSensitive: false).allMatches(xml)) {
        final u = cleanXmlUrl(m.group(1) ?? '');
        if (u.isNotEmpty) impressions.add(u);
      }

      // Extract Tracking Events
      final trackingEvents = <String, List<String>>{};
      for (final m in RegExp(r'<Tracking\s+[^>]*event=["\x27]([^"\x27]+)["\x27][^>]*>([\s\S]*?)<\/Tracking>', caseSensitive: false).allMatches(xml)) {
        final evt = (m.group(1) ?? '').trim().toLowerCase();
        final u = cleanXmlUrl(m.group(2) ?? '');
        if (evt.isNotEmpty && u.isNotEmpty) {
          trackingEvents.putIfAbsent(evt, () => <String>[]).add(u);
        }
      }

      // Extract skipoffset
      int skipSeconds = defaultSkipSeconds;
      final skipMatch = RegExp(r'skipoffset=["\x27]([^"\x27]+)["\x27]', caseSensitive: false).firstMatch(xml);
      if (skipMatch != null) {
        final rawOffset = skipMatch.group(1)?.trim() ?? '';
        if (rawOffset.contains(':')) {
          final parts = rawOffset.split(':').map((s) => int.tryParse(s) ?? 0).toList();
          if (parts.length == 3) {
            skipSeconds = parts[0] * 3600 + parts[1] * 60 + parts[2];
          }
        } else {
          final parsed = int.tryParse(rawOffset.replaceAll(RegExp(r'[^0-9]'), ''));
          if (parsed != null) skipSeconds = parsed;
        }
      }

      return VastAdData(
        mediaUrl: chosenMedia,
        clickThroughUrl: clickThroughUrl,
        clickTrackingUrls: clickTrackingUrls,
        impressions: impressions,
        trackingEvents: trackingEvents,
        skipSeconds: skipSeconds.clamp(0, 120),
      );
    } catch (e) {
      debugPrint('[VAST Service Error] $e');
      return null;
    }
  }
}
