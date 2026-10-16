import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:dramereel_mobile/shared/widgets/app_cached_image.dart';
import 'package:dramereel_mobile/shared/widgets/app_loading_indicator.dart';
import '../../../app/i18n.dart';
import '../../../shared/data/dio_provider.dart';
import '../../bootstrap/application/bootstrap_controller.dart';
import '../data/series_grid_memory_cache.dart';
import '../domain/home_feed.dart';

class SeriesRankingListView extends ConsumerStatefulWidget {
  const SeriesRankingListView({
    super.key,
    required this.query,
  });

  final Map<String, dynamic> query;

  @override
  ConsumerState<SeriesRankingListView> createState() => _SeriesRankingListViewState();
}

class _SeriesRankingListViewState extends ConsumerState<SeriesRankingListView> with AutomaticKeepAliveClientMixin {
  var _loading = true;
  Object? _error;
  List<HomeSeries> _items = const [];

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();

    final cached = SeriesGridMemoryCache.get(widget.query);
    if (cached != null && cached.items.isNotEmpty) {
      _items = cached.items;
      _loading = false;
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _load();
    });
  }

  @override
  void didUpdateWidget(covariant SeriesRankingListView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_sameQuery(oldWidget.query, widget.query)) {
      _load();
    }
  }

  bool _sameQuery(Map<String, dynamic> a, Map<String, dynamic> b) {
    if (a.length != b.length) return false;
    for (final e in a.entries) {
      if (!b.containsKey(e.key)) return false;
      if (b[e.key].toString() != e.value.toString()) return false;
    }
    return true;
  }

  Future<void> _load({bool force = false}) async {
    final cached = force ? null : SeriesGridMemoryCache.get(widget.query);
    if (cached != null && cached.items.isNotEmpty) {
      if (mounted) {
        setState(() {
          _items = cached.items;
          _loading = false;
          _error = null;
        });
      }
      if (!cached.isExpired) return;
    } else {
      if (_items.isEmpty) {
        setState(() {
          _loading = true;
          _error = null;
        });
      }
    }

    try {
      final bootstrap = await ref.read(appBootstrapProvider.future);
      final lang = bootstrap.localeCode;
      final dio = ref.read(dioProvider);

      final endpointKey = widget.query['__endpoint']?.toString().trim().toLowerCase();
      final cleanedQuery = Map<String, dynamic>.of(widget.query)..removeWhere((k, _) => k == '__endpoint');

      final res = endpointKey == 'trending'
          ? await dio.get<Map<String, dynamic>>(
              '/v1/search/trending',
              queryParameters: {
                ...cleanedQuery,
                if (lang.trim().isNotEmpty) 'lang': lang,
              },
            )
          : await dio.get<Map<String, dynamic>>(
              '/v1/series',
              queryParameters: {
                ...cleanedQuery,
                'page': 1,
                if (lang.trim().isNotEmpty) 'lang': lang,
              },
            );

      final json = res.data ?? const <String, dynamic>{};
      if (json['status'] != true) {
        throw Exception((json['message'] as String?) ?? 'Failed to load series');
      }

      Object? rawItems;
      final data = json['data'];
      if (data is List) {
        rawItems = data;
      } else if (data is Map<String, dynamic>) {
        rawItems = data['data'];
      }

      final list =
          rawItems is List ? rawItems : (rawItems is Map ? rawItems.values.toList(growable: false) : const []);
      final parsed = list
          .whereType<Map>()
          .map((e) => HomeSeries.fromJson(e.cast<String, dynamic>()))
          .toList(growable: false);

      if (!mounted) return;
      setState(() => _items = parsed);

      SeriesGridMemoryCache.set(
        query: widget.query,
        lang: lang,
        items: parsed,
        page: 1,
        hasMore: false,
      );
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
    super.build(context);
    final t = AppI18n.of(context);
    final baseUrl = ref.read(dioProvider).options.baseUrl;
 
    if (_loading) {
      return const Center(
        child: AppLoadingIndicator(radius: 13),
      );
    }
 
    if (_error != null) {
      final err = appUserErrorFor(_error);
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                t.t(err.titleKey),
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 18),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 10),
              Text(
                t.t(err.descKey),
                style: TextStyle(color: Colors.white.withValues(alpha: 0.65)),
                textAlign: TextAlign.center,
                maxLines: 4,
              ),
              const SizedBox(height: 14),
              ElevatedButton(
                onPressed: _load,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xffef233c),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  textStyle: const TextStyle(fontWeight: FontWeight.w900),
                ),
                child: Text(t.t('retry')),
              ),
            ],
          ),
        ),
      );
    }
 
    if (_items.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            t.t('no_content'),
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.65),
              fontWeight: FontWeight.w800,
              fontSize: 14,
            ),
            textAlign: TextAlign.center,
          ),
        ),
      );
    }
 
    return RefreshIndicator(
      onRefresh: _load,
      color: Colors.white,
      backgroundColor: const Color(0xff111111),
      child: ListView.separated(
        physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 24),
        itemBuilder: (context, index) {
          final item = _items[index];
          return _RankingTile(
            rank: index + 1,
            title: item.title,
            imageUrl: _normalizeImageUrl(item.posterUrl, baseUrl),
            isPremium: item.isPremium,
            isDubbed: item.isDubbed,
            onTap: () {
              context.push('/watch/${item.slug}');
            },
          );
        },
        separatorBuilder: (_, __) => const SizedBox(height: 12),
        itemCount: _items.length,
      ),
    );
  }
}
 
class _RankingTile extends StatelessWidget {
  const _RankingTile({
    required this.rank,
    required this.title,
    required this.imageUrl,
    required this.isPremium,
    required this.isDubbed,
    required this.onTap,
  });
 
  final int rank;
  final String title;
  final String imageUrl;
  final bool isPremium;
  final bool isDubbed;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = AppI18n.of(context);
    return ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          child: Container(
            height: 96,
            color: Colors.white.withValues(alpha: 0.05),
            child: Stack(
              fit: StackFit.expand,
              children: [
                Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: AlignmentDirectional.centerStart,
                      end: AlignmentDirectional.centerEnd,
                      colors: [
                        const Color(0xffef233c).withValues(alpha: 0.20),
                        Colors.black.withValues(alpha: 0.0),
                      ],
                    ),
                  ),
                ),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
              child: Row(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Stack(
                      children: [
                        AppCachedImage(
                          imageUrl: imageUrl,
                          width: 66,
                          height: 72,
                          fit: BoxFit.cover,
                          memCacheWidth: 200,
                          memCacheHeight: 220,
                          maxWidthDiskCache: 400,
                          maxHeightDiskCache: 450,
                        ),
                        PositionedDirectional(
                          bottom: 6,
                          end: 6,
                          child: Container(
                            width: 24,
                            height: 24,
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.45),
                              borderRadius: BorderRadius.circular(999),
                              border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
                            ),
                            child: const Icon(Icons.play_arrow_rounded, color: Colors.white, size: 16),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w900,
                            fontSize: 14,
                            letterSpacing: -.2,
                            height: 1.15,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            if (isDubbed)
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                                decoration: BoxDecoration(
                                  color: const Color(0xff3b82f6),
                                  borderRadius: BorderRadius.circular(999),
                                ),
                                child: Text(
                                  t.t('badge_dubbed'),
                                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 11),
                                ),
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  Text(
                    '$rank',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.85),
                      fontWeight: FontWeight.w900,
                      fontSize: 28,
                      letterSpacing: -.6,
                      height: 1,
                    ),
                  ),
                ],
              ),
            ),
              ],
            ),
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
