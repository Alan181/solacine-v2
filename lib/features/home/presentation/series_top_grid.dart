import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:dramereel_mobile/shared/widgets/app_cached_image.dart';
import '../../../shared/widgets/app_loading_indicator.dart';
import '../../../app/i18n.dart';
import '../../../shared/data/dio_provider.dart';
import '../../bootstrap/application/bootstrap_controller.dart';
import '../domain/home_feed.dart';
 
class SeriesTopGrid extends ConsumerStatefulWidget {
  const SeriesTopGrid({
    super.key,
    required this.title,
    required this.query,
    this.count = 6,
  });
 
  final String title;
  final Map<String, dynamic> query;
  final int count;
 
  @override
  ConsumerState<SeriesTopGrid> createState() => _SeriesTopGridState();
}
 
class _SeriesTopGridState extends ConsumerState<SeriesTopGrid> {
  var _loading = true;
  Object? _error;
  List<HomeSeries> _items = const [];
 
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }
 
  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
      _items = const [];
    });
 
    try {
      final bootstrap = await ref.read(appBootstrapProvider.future);
      final lang = bootstrap.localeCode;
      final dio = ref.read(dioProvider);
 
      final res = await dio.get<Map<String, dynamic>>(
        '/v1/series',
        queryParameters: {
          ...widget.query,
          'page': 1,
          if (lang.trim().isNotEmpty) 'lang': lang,
        },
      );
 
      final json = res.data ?? const <String, dynamic>{};
      if (json['status'] != true) {
        throw Exception((json['message'] as String?) ?? 'Failed to load series');
      }
 
      final data = (json['data'] as Map<String, dynamic>?) ?? <String, dynamic>{};
      final rawItems = data['data'];
      final list = rawItems is List ? rawItems : (rawItems is Map ? rawItems.values.toList(growable: false) : const []);
      final parsed = list.whereType<Map>().map((e) => HomeSeries.fromJson(e.cast<String, dynamic>())).toList(growable: false);
 
      if (!mounted) return;
      setState(() => _items = parsed.take(widget.count).toList(growable: false));
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e);
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }
 
  @override
  Widget build(BuildContext context) {
    final t = AppI18n.of(context);
    final baseUrl = ref.read(dioProvider).options.baseUrl;
 
    if (_loading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 10),
        child: Center(
          child: AppLoadingIndicator(radius: 12),
        ),
      );
    }
 
    if (_error != null) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(
          children: [
            Expanded(
              child: Text(
                t.t('request_failed'),
                style: TextStyle(color: Colors.white.withValues(alpha: 0.65), fontWeight: FontWeight.w900),
              ),
            ),
            TextButton(
              onPressed: _load,
              style: TextButton.styleFrom(
                foregroundColor: const Color(0xffef233c),
                textStyle: const TextStyle(fontWeight: FontWeight.w900),
              ),
              child: Text(t.t('retry')),
            ),
          ],
        ),
      );
    }
 
    if (_items.isEmpty) return const SizedBox.shrink();
 
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              widget.title,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w900,
                fontSize: 18,
                letterSpacing: -.4,
              ),
            ),
          ),
          const SizedBox(height: 10),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                childAspectRatio: 2 / 1.15,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
              ),
              itemBuilder: (context, index) {
                final item = _items[index];
                return _TopTile(
                  index: index,
                  slug: item.slug,
                  title: item.title,
                  imageUrl: _normalizeImageUrl(item.posterUrl, baseUrl),
                  isPremium: item.isPremium,
                  isDubbed: item.isDubbed,
                );
              },
              itemCount: _items.length,
            ),
          ),
        ],
      ),
    );
  }
}
 
class _TopTile extends StatelessWidget {
  const _TopTile({
    required this.index,
    required this.slug,
    required this.title,
    required this.imageUrl,
    required this.isPremium,
    required this.isDubbed,
  });
 
  final int index;
  final String slug;
  final String title;
  final String imageUrl;
  final bool isPremium;
  final bool isDubbed;
 
  @override
  Widget build(BuildContext context) {
    final t = AppI18n.of(context);
    final rank = (index + 1).toString();
 
    return ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            final p = imageUrl.isNotEmpty ? '&poster=${Uri.encodeComponent(imageUrl)}' : '';
            context.push('/watch/$slug?title=${Uri.encodeComponent(title)}$p');
          },
          child: Stack(
            fit: StackFit.expand,
            children: [
          AppCachedImage(
            imageUrl: imageUrl,
            fit: BoxFit.cover,
            memCacheWidth: 400,
            memCacheHeight: 250,
            maxWidthDiskCache: 600,
            maxHeightDiskCache: 400,
          ),
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.black.withValues(alpha: 0.10),
                  Colors.black.withValues(alpha: 0.65),
                ],
              ),
            ),
          ),
          // Center Play Icon
          IgnorePointer(
            child: Center(
              child: Image.asset(
                'assets/images/favourite_play_icon.png',
                width: 32,
                height: 32,
                fit: BoxFit.contain,
                errorBuilder: (context, error, stackTrace) => const SizedBox.shrink(),
              ),
            ),
          ),
          PositionedDirectional(
            bottom: 10,
            start: 10,
            end: 54,
            child: Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w900,
                fontSize: 13,
                letterSpacing: -.2,
              ),
            ),
          ),
          PositionedDirectional(
            bottom: 8,
            end: 10,
            child: Text(
              rank,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.92),
                fontSize: 28,
                fontWeight: FontWeight.w900,
                height: 1,
                shadows: [
                  Shadow(
                    color: Colors.black.withValues(alpha: 0.6),
                    blurRadius: 14,
                  ),
                ],
              ),
            ),
          ),
          if (isDubbed)
            PositionedDirectional(
              top: 0,
              start: 0,
              child: Container(
                padding: const EdgeInsets.fromLTRB(8, 4, 10, 5),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xff2563eb), Color(0xff38bdf8)],
                  ),
                  borderRadius: const BorderRadiusDirectional.only(
                    bottomEnd: Radius.circular(12),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xff2563eb).withValues(alpha: 0.4),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Text(
                  t.t('badge_dubbed'),
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                    fontSize: 10,
                  ),
                ),
              ),
            ),
          PositionedDirectional(
            bottom: 10,
            end: 10,
            child: Container(
              width: 26,
              height: 26,
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.45),
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
              ),
              child: const Icon(Icons.play_arrow_rounded, color: Colors.white, size: 18),
            ),
          ),
            ],
          ),
        ),
      ),
    );
  }
}
 
String _normalizeImageUrl(String url, String baseUrl) {
  final input = url.trim();
  if (input.isEmpty) return input;
 
  final base = Uri.tryParse(baseUrl);
  final u = Uri.tryParse(input);
  if (base == null || u == null) return input;
 
  final host = (u.host).toLowerCase();
  if (host == '127.0.0.1' || host == 'localhost') {
    return u.replace(
      scheme: base.scheme.isNotEmpty ? base.scheme : u.scheme,
      host: base.host,
      port: base.hasPort ? base.port : u.port,
    ).toString();
  }
 
  if (input.startsWith('/')) {
    return base.replace(path: input).toString();
  }
 
  return input;
}
