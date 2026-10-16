import 'package:flutter/foundation.dart';
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
import 'series_action_sheet.dart';

class SeriesGridView extends ConsumerStatefulWidget {
  const SeriesGridView({
    super.key,
    required this.query,
    this.padding = const EdgeInsets.fromLTRB(8, 10, 8, 24),
  });

  final Map<String, dynamic> query;
  final EdgeInsets padding;

  @override
  ConsumerState<SeriesGridView> createState() => _SeriesGridViewState();
}

class _SeriesGridViewState extends ConsumerState<SeriesGridView> with AutomaticKeepAliveClientMixin {
  final _controller = ScrollController();
  final _items = <HomeSeries>[];
  var _loading = true;
  var _loadingMore = false;
  var _page = 1;
  var _hasMore = true;
  Object? _error;
  var _generation = 0;


  @override
  void initState() {
    super.initState();
    _controller.addListener(_onScroll);

    // Populate instantly from in-memory cache if available (0ms delay, no spinner)
    final cached = SeriesGridMemoryCache.get(widget.query);
    if (cached != null && cached.items.isNotEmpty) {
      _items.addAll(cached.items);
      _page = cached.page;
      _hasMore = cached.hasMore;
      _loading = false;
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _loadInitial();
    });
  }

  @override
  void didUpdateWidget(covariant SeriesGridView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!mapEquals(oldWidget.query, widget.query)) {
      _loadInitial();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_hasMore || _loading || _loadingMore) return;
    final position = _controller.position;
    if (!position.hasPixels) return;
    if (position.maxScrollExtent - position.pixels < 360) {
      _loadMore();
    }
  }

  Future<void> _loadInitial({bool force = false}) async {
    final generation = ++_generation;
    final querySnapshot = Map<String, dynamic>.from(widget.query);

    final cached = force ? null : SeriesGridMemoryCache.get(querySnapshot);
    if (cached != null && cached.items.isNotEmpty) {
      if (mounted) {
        setState(() {
          _items
            ..clear()
            ..addAll(cached.items);
          _page = cached.page;
          _hasMore = cached.hasMore;
          _loading = false;
          _error = null;
        });
      }
      // If cached data is still fresh, do not trigger duplicate network request
      if (!cached.isExpired) return;
    } else {
      if (_items.isEmpty) {
        setState(() {
          _loading = true;
          _error = null;
          _page = 1;
          _hasMore = true;
        });
      }
    }

    await _loadPage(1, generation: generation, querySnapshot: querySnapshot, isInitial: true);
  }

  Future<void> _loadMore() async {
    if (!_hasMore) return;
    final generation = _generation;
    final querySnapshot = Map<String, dynamic>.from(widget.query);
    setState(() {
      _loadingMore = true;
      _error = null;
    });
    await _loadPage(_page + 1, generation: generation, querySnapshot: querySnapshot, isInitial: false);
    if (mounted && generation == _generation) {
      setState(() => _loadingMore = false);
    }
  }

  Future<void> _loadPage(
    int page, {
    required int generation,
    required Map<String, dynamic> querySnapshot,
    required bool isInitial,
  }) async {
    try {
      final bootstrap = await ref.read(appBootstrapProvider.future);
      final lang = bootstrap.localeCode;
      final dio = ref.read(dioProvider);

      final res = await dio.get<Map<String, dynamic>>(
        '/v1/series',
        queryParameters: {
          ...querySnapshot,
          'page': page,
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
      final lastPage = (data['last_page'] as num?)?.toInt();

      if (!mounted || generation != _generation) return;
      setState(() {
        _page = page;
        if (isInitial) {
          _items
            ..clear()
            ..addAll(parsed);
        } else {
          _items.addAll(parsed);
        }
        if (lastPage != null) {
          _hasMore = page < lastPage;
        } else {
          _hasMore = parsed.isNotEmpty;
        }
        _loading = false;
        _error = null;
      });

      // Update in-memory cache
      SeriesGridMemoryCache.set(
        query: querySnapshot,
        lang: lang,
        items: _items,
        page: _page,
        hasMore: _hasMore,
      );
    } catch (e) {
      if (!mounted || generation != _generation) return;
      if (page == 1 && _items.isEmpty) {
        setState(() {
          _error = e;
          _hasMore = false;
        });
      } else {
        setState(() => _hasMore = false);
        final t = AppI18n.of(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(t.t('request_failed'))),
        );
      }
    } finally {
      if (mounted && generation == _generation && page == 1) {
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
                onPressed: _loadInitial,
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
 
    return Stack(
      children: [
        RefreshIndicator(
          onRefresh: _loadInitial,
          color: Colors.white,
          backgroundColor: const Color(0xff111111),
          child: GridView.builder(
            controller: _controller,
            physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
            padding: widget.padding.copyWith(bottom: widget.padding.bottom + (_loadingMore ? 34 : 0)),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              childAspectRatio: 2 / 3.35,
              crossAxisSpacing: 8,
              mainAxisSpacing: 10,
            ),
            itemBuilder: (context, index) {
              final item = _items[index];
              return _PosterTile(
                id: item.id,
                title: item.title,
                imageUrl: _normalizeImageUrl(item.posterUrl, baseUrl),
                isPremium: item.isPremium,
                isFeatured: item.isFeatured,
                isDubbed: item.isDubbed,
                views: item.views,
                onTap: () {
                  context.push('/watch/${item.slug}');
                },
              );
            },
            itemCount: _items.length,
          ),
        ),
        if (_loadingMore)
          const Positioned(
            left: 0,
            right: 0,
            bottom: 10,
            child: Center(
              child: AppLoadingIndicator(radius: 9),
            ),
          ),
      ],
    );
  }
 
  @override
  bool get wantKeepAlive => true;
}
 
class _PosterTile extends ConsumerStatefulWidget {
  const _PosterTile({
    required this.id,
    required this.title,
    required this.imageUrl,
    required this.isPremium,
    required this.isFeatured,
    required this.isDubbed,
    required this.views,
    required this.onTap,
  });

  final int id;
  final String title;
  final String imageUrl;
  final bool isPremium;
  final bool isFeatured;
  final bool isDubbed;
  final int views;
  final VoidCallback onTap;

  @override
  ConsumerState<_PosterTile> createState() => _PosterTileState();
}

class _PosterTileState extends ConsumerState<_PosterTile> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    final t = AppI18n.of(context);
    final viewsLabel = _formatViews(widget.views);

    // Dynamic slight rotation tilt on touch: subtle tilt of ~0.005 turns (approx 1.8 degrees)
    final tiltTurn = widget.id.isEven ? 0.005 : -0.005;

    return GestureDetector(
      onTapDown: (_) => setState(() => _isPressed = true),
      onTapUp: (_) => setState(() => _isPressed = false),
      onTapCancel: () => setState(() => _isPressed = false),
      onTap: widget.onTap,
      onLongPress: () {
        setState(() => _isPressed = false);
        showSeriesActionSheet(
          context,
          seriesId: widget.id,
          title: widget.title,
          subtitle: viewsLabel,
          onWatch: widget.onTap,
        );
      },
      behavior: HitTestBehavior.opaque,
      child: AnimatedScale(
        scale: _isPressed ? 0.96 : 1.0,
        duration: const Duration(milliseconds: 140),
        curve: Curves.easeOutCubic,
        child: AnimatedRotation(
          turns: _isPressed ? tiltTurn : 0.0,
          duration: const Duration(milliseconds: 140),
          curve: Curves.easeOutCubic,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.50),
                        blurRadius: 8,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        AppCachedImage(
                          imageUrl: widget.imageUrl,
                          fit: BoxFit.cover,
                          memCacheWidth: 360,
                          memCacheHeight: 540,
                          maxWidthDiskCache: 720,
                          maxHeightDiskCache: 1080,
                        ),
                        // Multistop gradient overlay for enhanced readability
                        Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                Colors.transparent,
                                Colors.black.withValues(alpha: 0.15),
                                Colors.black.withValues(alpha: 0.85),
                              ],
                              stops: const [0.45, 0.70, 1.0],
                            ),
                          ),
                        ),
                        // Thin border for a polished glassmorphism look
                        Container(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.10),
                              width: 0.8,
                            ),
                          ),
                        ),
                        // Center Play Icon
                        IgnorePointer(
                          child: Center(
                            child: Image.asset(
                              'assets/images/favourite_play_icon.png',
                              width: 34,
                              height: 34,
                              fit: BoxFit.contain,
                              errorBuilder: (context, error, stackTrace) => const SizedBox.shrink(),
                            ),
                          ),
                        ),
                        if (widget.isFeatured)
                          PositionedDirectional(
                            top: 0,
                            end: 0,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                  colors: [
                                    Color(0xffff5722),
                                    Color(0xffff9100),
                                  ],
                                ),
                                borderRadius: const BorderRadiusDirectional.only(
                                  bottomStart: Radius.circular(12),
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: const Color(0xffff5722).withValues(alpha: 0.45),
                                    blurRadius: 8,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: const Text(
                                'HOT',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w900,
                                  fontSize: 10,
                                  letterSpacing: 0.4,
                                ),
                              ),
                            ),
                          ),
                        if (widget.isDubbed)
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
                          bottom: 6,
                          start: 7,
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.play_arrow_rounded,
                                color: Colors.white.withValues(alpha: 0.95),
                                size: 16,
                                shadows: [
                                  Shadow(color: Colors.black.withValues(alpha: 0.7), blurRadius: 10),
                                ],
                              ),
                              if (viewsLabel.isNotEmpty) ...[
                                const SizedBox(width: 2),
                                Text(
                                  viewsLabel,
                                  style: TextStyle(
                                    color: Colors.white.withValues(alpha: 0.95),
                                    fontWeight: FontWeight.w900,
                                    fontSize: 11,
                                    shadows: [
                                      Shadow(color: Colors.black.withValues(alpha: 0.7), blurRadius: 10),
                                    ],
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                widget.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  fontSize: 12,
                  letterSpacing: -0.2,
                  height: 1.15,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
 
String _formatViews(int value) {
  if (value <= 0) return '';
  if (value >= 1000000000) return '${(value / 1000000000).toStringAsFixed(1)}B';
  if (value >= 1000000) return '${(value / 1000000).toStringAsFixed(1)}M';
  if (value >= 1000) return '${(value / 1000).toStringAsFixed(1)}k';
  return value.toString();
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
