import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:solacine_mobile/shared/widgets/app_cached_image.dart';
import '../../../shared/widgets/app_loading_indicator.dart';
import '../../../app/i18n.dart';
import '../../../shared/constants.dart';
import '../../my_list/application/favorites_controller.dart';
import '../data/search_api.dart';
import '../domain/search_series.dart';

class SearchScreen extends ConsumerStatefulWidget {
  const SearchScreen({super.key});

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen> {
  final _controller = TextEditingController();
  final _focus = FocusNode();
  Timer? _debounce;

  var _q = '';
  var _loading = false;
  var _loadingMore = false;
  Object? _error;
  var _page = 1;
  var _hasMore = false;
  final _items = <SearchSeries>[];
  final _trending = <SearchSeries>[];
  final _scroll = ScrollController();

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_onScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await _loadTrending();
      if (mounted) _focus.requestFocus();
    });
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    _focus.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_hasMore || _loadingMore || _loading) return;
    if (_scroll.position.pixels < _scroll.position.maxScrollExtent - 300) return;
    _loadMore();
  }

  Future<void> _loadTrending() async {
    setState(() {
      _error = null;
    });
    try {
      final api = ref.read(searchApiProvider);
      final items = await api.trending(lang: Localizations.localeOf(context).languageCode);
      if (!mounted) return;
      setState(() {
        _trending
          ..clear()
          ..addAll(items);
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e;
      });
    }
  }

  void _onChanged(String value) {
    setState(() {});
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), () {
      final next = value.trim();
      if (next == _q) return;
      _q = next;
      _loadInitial();
    });
  }

  Future<void> _loadInitial() async {
    if (_q.isEmpty) {
      setState(() {
        _items.clear();
        _page = 1;
        _hasMore = false;
        _loading = false;
        _loadingMore = false;
        _error = null;
      });
      return;
    }

    setState(() {
      _loading = true;
      _loadingMore = false;
      _error = null;
      _items.clear();
      _page = 1;
      _hasMore = false;
    });

    try {
      final api = ref.read(searchApiProvider);
      final res = await api.search(
        q: _q,
        page: 1,
        lang: Localizations.localeOf(context).languageCode,
      );
      if (!mounted) return;
      setState(() {
        _items.addAll(res.items);
        _hasMore = res.hasMore;
        _page = 1;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e;
      });
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  Future<void> _loadMore() async {
    if (_q.isEmpty) return;
    setState(() {
      _loadingMore = true;
      _error = null;
    });
    try {
      final api = ref.read(searchApiProvider);
      final nextPage = _page + 1;
      final res = await api.search(
        q: _q,
        page: nextPage,
        lang: Localizations.localeOf(context).languageCode,
      );
      if (!mounted) return;
      setState(() {
        _items.addAll(res.items);
        _page = nextPage;
        _hasMore = res.hasMore;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e;
      });
    } finally {
      if (mounted) {
        setState(() {
          _loadingMore = false;
        });
      }
    }
  }

  Future<void> _track(SearchSeries s) async {
    try {
      await ref.read(searchApiProvider).track(seriesId: s.id, q: _q);
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final t = AppI18n.of(context);
    final favorites = ref.watch(favoritesIdsProvider).valueOrNull ?? const <int>{};

    final items = _q.isEmpty ? _trending : _items;
    final showLoading = _loading && _q.isNotEmpty;

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          Positioned(
            left: 0,
            right: 0,
            top: 0,
            height: 240,
            child: IgnorePointer(
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Opacity(
                    opacity: 0.22,
                    child: Image.asset(
                      'assets/images/icon_subscribe_iaa_bg.png',
                      fit: BoxFit.cover,
                      alignment: Alignment.topCenter,
                      filterQuality: FilterQuality.low,
                    ),
                  ),
                ],
              ),
            ),
          ),
          SafeArea(
            bottom: false,
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
                  child: Row(
                    children: [
                      IconButton(
                        onPressed: () => context.pop(),
                        icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 20),
                        style: IconButton.styleFrom(
                          backgroundColor: Colors.white.withValues(alpha: 0.06),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Container(
                          height: 44,
                          decoration: BoxDecoration(
                            color: const Color(0xff111111),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: const Color(0xff262626)),
                          ),
                          child: Row(
                            children: [
                              const SizedBox(width: 12),
                              Icon(Icons.search_rounded, color: Colors.white.withValues(alpha: 0.72), size: 20),
                              const SizedBox(width: 6),
                              Expanded(
                                child: TextField(
                                  controller: _controller,
                                  focusNode: _focus,
                                  onChanged: _onChanged,
                                  textAlignVertical: TextAlignVertical.center,
                                  style: TextStyle(
                                    color: Colors.white.withValues(alpha: 0.92),
                                    fontSize: 14,
                                    fontWeight: FontWeight.w500,
                                  ),
                                  cursorColor: Colors.white,
                                  decoration: InputDecoration(
                                    isDense: true,
                                    filled: true,
                                    fillColor: Colors.transparent,
                                    contentPadding: const EdgeInsets.only(top: 1),
                                    hintText: t.t('search_all'),
                                    hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.55)),
                                    border: InputBorder.none,
                                    enabledBorder: InputBorder.none,
                                    focusedBorder: InputBorder.none,
                                    disabledBorder: InputBorder.none,
                                  ),
                                  textInputAction: TextInputAction.search,
                                ),
                              ),
                              if (_controller.text.trim().isNotEmpty)
                                IconButton(
                                  onPressed: () {
                                    _controller.clear();
                                    _onChanged('');
                                    _focus.requestFocus();
                                    setState(() {});
                                  },
                                  icon: Icon(Icons.close_rounded, color: Colors.white.withValues(alpha: 0.75)),
                                )
                              else
                                const SizedBox(width: 6),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                  child: Row(
                    children: [
                      Text(
                        t.t('people_searching'),
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.85),
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: Stack(
                    children: [
                  RefreshIndicator(
                    onRefresh: () async {
                      if (_q.isEmpty) {
                        await _loadTrending();
                        return;
                      }
                      await _loadInitial();
                    },
                    color: Colors.white,
                    backgroundColor: const Color(0xff111111),
                    child: ListView.separated(
                      controller: _scroll,
                      physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                      itemBuilder: (context, index) {
                        final s = items[index];
                        final isFav = favorites.contains(s.id);
                        final rank = _q.isEmpty ? (index + 1).toString() : '';
                        return _SearchRow(
                          item: s,
                          baseUrl: apiBaseUrl,
                          isFavorited: isFav,
                          rankLabel: rank,
                          onTap: () {
                            final slug = s.slug;
                            final title = s.title;
                            final ctx = context;
                            unawaited(Future<void>(() async {
                              await _track(s);
                              if (!mounted) return;
                              if (!ctx.mounted) return;
                              final posterNorm = _normalizeImageUrl(s.posterUrl, apiBaseUrl);
                              final p = posterNorm.isNotEmpty ? '&poster=${Uri.encodeComponent(posterNorm)}' : '';
                              ctx.push('/watch/$slug?title=${Uri.encodeComponent(title)}$p');
                            }));
                          },
                          onToggleFavorite: () => ref.read(favoritesIdsProvider.notifier).toggle(s.id),
                        );
                      },
                      separatorBuilder: (_, __) => const SizedBox(height: 12),
                      itemCount: items.length,
                    ),
                  ),
                  if (showLoading)
                    const Positioned.fill(
                      child: IgnorePointer(
                        child: Center(
                          child: AppLoadingIndicator(radius: 14),
                        ),
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
                  if (_error != null && !showLoading)
                    Positioned(
                      left: 16,
                      right: 16,
                      top: 70,
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.06),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
                        ),
                        child: Builder(builder: (context) {
                          final t = AppI18n.of(context);
                          final err = appUserErrorFor(_error);
                          return Text(
                            '${t.t(err.titleKey)} — ${t.t(err.descKey)}',
                            style: TextStyle(color: Colors.white.withValues(alpha: 0.70), fontSize: 12),
                          );
                        }),
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
    );
  }
}

class _SearchRow extends StatelessWidget {
  const _SearchRow({
    required this.item,
    required this.baseUrl,
    required this.isFavorited,
    required this.rankLabel,
    required this.onTap,
    required this.onToggleFavorite,
  });

  final SearchSeries item;
  final String baseUrl;
  final bool isFavorited;
  final String rankLabel;
  final VoidCallback onTap;
  final VoidCallback onToggleFavorite;

  @override
  Widget build(BuildContext context) {
    final poster = _normalizeImageUrl(item.posterUrl, baseUrl);
    final title = item.title.trim();
    final synopsis = item.synopsis.trim();
    final genre = item.genre.trim();
    final rank = int.tryParse(rankLabel.trim()) ?? 0;
    final rankAsset = switch (rank) {
      1 => 'assets/images/recommend_nub_first.webp',
      2 => 'assets/images/recommend_nub_second.webp',
      3 => 'assets/images/recommend_nub_third.webp',
      _ => '',
    };

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          IconButton(
            onPressed: onToggleFavorite,
            icon: Icon(
              isFavorited ? Icons.bookmark_rounded : Icons.bookmark_border_rounded,
              color: Colors.white.withValues(alpha: isFavorited ? 0.95 : 0.70),
              size: 26,
            ),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      if (rankLabel.isNotEmpty && rankAsset.isEmpty)
                        Padding(
                          padding: const EdgeInsetsDirectional.only(end: 8),
                          child: Text(
                            rankLabel,
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.30),
                              fontSize: 18,
                              fontWeight: FontWeight.w500,
                              height: 1.1,
                            ),
                          ),
                        ),
                      Expanded(
                        child: Text(
                          title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.92),
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            height: 1.2,
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (genre.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 180),
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.06),
                          borderRadius: BorderRadius.circular(999),
                          border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          child: Text(
                            genre,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.72),
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                              height: 1.0,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                  if (synopsis.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text(
                      synopsis,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.45),
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        height: 1.25,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(width: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(2),
            child: Stack(
              children: [
                AppCachedImage(
                  imageUrl: poster,
                  width: 84,
                  height: 120,
                  fit: BoxFit.cover,
                ),
                Container(
                  width: 84,
                  height: 120,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.black.withValues(alpha: 0.05),
                        Colors.black.withValues(alpha: 0.55),
                      ],
                    ),
                  ),
                ),
                if (rankAsset.isNotEmpty)
                  Positioned(
                    left: -6,
                    bottom: 0,
                    child: Image.asset(
                      rankAsset,
                      width: 34,
                      height: 34,
                      fit: BoxFit.contain,
                      filterQuality: FilterQuality.low,
                    ),
                  ),
              ],
            ),
          ),
        ],
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
