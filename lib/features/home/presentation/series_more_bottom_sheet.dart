import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:dramereel_mobile/shared/widgets/app_cached_image.dart';
import '../../../shared/widgets/app_loading_indicator.dart';
import '../../../app/i18n.dart';
import '../../../shared/data/dio_provider.dart';
import '../../bootstrap/application/bootstrap_controller.dart';
import '../domain/home_feed.dart';

Future<void> showSeriesMoreBottomSheet(
  BuildContext context,
  WidgetRef ref, {
  required String title,
  required Map<String, dynamic> query,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    isDismissible: true,
    enableDrag: true,
    backgroundColor: Colors.transparent,
    builder: (context) {
      return _SeriesMoreSheet(
        title: title,
        query: query,
      );
    },
  );
}

class _SeriesMoreSheet extends ConsumerStatefulWidget {
  const _SeriesMoreSheet({
    required this.title,
    required this.query,
  });

  final String title;
  final Map<String, dynamic> query;

  @override
  ConsumerState<_SeriesMoreSheet> createState() => _SeriesMoreSheetState();
}

class _SeriesMoreSheetState extends ConsumerState<_SeriesMoreSheet> {
  final _controller = ScrollController();
  final _items = <HomeSeries>[];
  var _loading = true;
  var _loadingMore = false;
  var _page = 1;
  var _hasMore = true;
  Object? _error;

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadInitial());
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
    if (position.maxScrollExtent - position.pixels < 320) {
      _loadMore();
    }
  }

  Future<void> _loadInitial() async {
    setState(() {
      _loading = true;
      _error = null;
      _items.clear();
      _page = 1;
      _hasMore = true;
    });
    await _loadPage(1);
  }

  Future<void> _loadMore() async {
    if (!_hasMore) return;
    setState(() {
      _loadingMore = true;
      _error = null;
    });
    await _loadPage(_page + 1);
    if (mounted) {
      setState(() => _loadingMore = false);
    }
  }

  Future<void> _loadPage(int page) async {
    try {
      final bootstrap = await ref.read(appBootstrapProvider.future);
      final lang = bootstrap.localeCode;
      final dio = ref.read(dioProvider);

      final res = await dio.get<Map<String, dynamic>>(
        '/v1/series',
        queryParameters: {
          ...widget.query,
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

      if (mounted) {
        setState(() {
          _page = page;
          _items.addAll(parsed);
          if (lastPage != null) {
            _hasMore = page < lastPage;
          } else {
            _hasMore = parsed.isNotEmpty;
          }
        });
      }
    } catch (e) {
      if (!mounted) return;
      if (page == 1) {
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
      if (mounted && page == 1) {
        setState(() => _loading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = AppI18n.of(context);
    final media = MediaQuery.of(context);

    return SafeArea(
      top: false,
      child: Padding(
        padding: EdgeInsets.only(top: media.size.height * 0.10),
        child: ClipRRect(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(34)),
          child: Container(
            color: const Color(0xff111111),
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          widget.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w900,
                            fontSize: 16,
                            letterSpacing: -.2,
                          ),
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.of(context).pop(),
                        icon: const Icon(Icons.close_rounded, color: Colors.white),
                        style: IconButton.styleFrom(
                          backgroundColor: Colors.white.withValues(alpha: 0.06),
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: _loading
                      ? const Center(
                          child: AppLoadingIndicator(radius: 13),
                        )
                      : _error != null
                          ? Center(
                              child: Padding(
                                padding: const EdgeInsets.all(24),
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Builder(builder: (context) {
                                      final t = AppI18n.of(context);
                                      final err = appUserErrorFor(_error);
                                      return Text(
                                        t.t(err.titleKey),
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.w900,
                                          fontSize: 18,
                                        ),
                                      );
                                    }),
                                    const SizedBox(height: 10),
                                    Builder(builder: (context) {
                                      final t = AppI18n.of(context);
                                      final err = appUserErrorFor(_error);
                                      return Text(
                                        t.t(err.descKey),
                                        style: TextStyle(color: Colors.white.withValues(alpha: 0.65)),
                                        maxLines: 4,
                                        textAlign: TextAlign.center,
                                      );
                                    }),
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
                            )
                          : GridView.builder(
                              controller: _controller,
                              padding: const EdgeInsets.fromLTRB(16, 10, 16, 18),
                              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: 3,
                                childAspectRatio: 2 / 3.35,
                                crossAxisSpacing: 12,
                                mainAxisSpacing: 14,
                              ),
                              itemBuilder: (context, index) {
                                final item = _items[index];
                                return _PosterTile(
                                  title: item.title,
                                  imageUrl: item.posterUrl,
                                  isPremium: item.isPremium,
                                  onTap: () {
                                    context.push('/watch/${item.slug}');
                                  },
                                );
                              },
                              itemCount: _items.length,
                            ),
                ),
                if (_loadingMore)
                  const Padding(
                    padding: EdgeInsets.only(bottom: 12),
                    child: AppLoadingIndicator(radius: 9),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _PosterTile extends StatelessWidget {
  const _PosterTile({
    required this.title,
    required this.imageUrl,
    required this.isPremium,
    required this.onTap,
  });

  final String title;
  final String imageUrl;
  final bool isPremium;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = AppI18n.of(context);
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(18),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  AppCachedImage(
                    imageUrl: imageUrl,
                    fit: BoxFit.cover,
                    memCacheWidth: 360,
                    memCacheHeight: 540,
                    maxWidthDiskCache: 720,
                    maxHeightDiskCache: 1080,
                  ),
                  if (isPremium)
                    PositionedDirectional(
                      top: 8,
                      start: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                        decoration: BoxDecoration(
                          color: const Color(0xffef233c),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          t.t('badge_pro'),
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 11),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.86),
              fontWeight: FontWeight.w800,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}
