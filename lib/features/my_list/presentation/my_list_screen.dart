import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:dramereel_mobile/shared/widgets/app_bottom_nav_bar.dart';
import 'package:dramereel_mobile/shared/widgets/app_cached_image.dart';
import 'package:dramereel_mobile/shared/widgets/app_loading_indicator.dart';

import '../../../app/i18n.dart';
import '../../../shared/data/dio_provider.dart';
import '../../auth/application/auth_controller.dart';
import '../../bootstrap/application/bootstrap_controller.dart';
import '../../home/domain/home_feed.dart';
import '../application/favorites_controller.dart';

class MyListScreen extends ConsumerStatefulWidget {
  const MyListScreen({super.key});

  @override
  ConsumerState<MyListScreen> createState() => _MyListScreenState();
}

class _MyListScreenState extends ConsumerState<MyListScreen> {
  final _searchController = TextEditingController();
  final _searchFocus = FocusNode();
  Timer? _searchDebounce;
  var _searchOpen = false;
  var _searchQuery = '';
  var _effectiveQuery = '';

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _searchController.dispose();
    _searchFocus.dispose();
    super.dispose();
  }

  void _toggleSearch() {
    setState(() {
      _searchOpen = !_searchOpen;
      if (!_searchOpen) {
        _searchQuery = '';
        _effectiveQuery = '';
        _searchController.clear();
        _searchDebounce?.cancel();
        _searchFocus.unfocus();
      }
    });
    if (_searchOpen) {
      FocusScope.of(context).requestFocus(_searchFocus);
    }
  }

  void _onSearchChanged(String value) {
    setState(() => _searchQuery = value);
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 350), () {
      if (!mounted) return;
      setState(() => _effectiveQuery = _searchQuery.trim());
    });
  }

  void _clearSearch() {
    setState(() {
      _searchQuery = '';
      _effectiveQuery = '';
      _searchController.clear();
    });
    _searchDebounce?.cancel();
    FocusScope.of(context).requestFocus(_searchFocus);
  }

  @override
  Widget build(BuildContext context) {
    final t = AppI18n.of(context);
    return PopScope(
      canPop: Navigator.of(context).canPop(),
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        context.go('/reels');
      },
      child: Scaffold(
        backgroundColor: const Color(0xff050505),
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          foregroundColor: Colors.white,
          title: Text(t.t('nav_my_list')),
          actions: [
            IconButton(
              onPressed: _toggleSearch,
              icon: Icon(_searchOpen ? Icons.close_rounded : Icons.search_rounded),
              tooltip: t.t('search'),
            ),
          ],
          bottom: _searchOpen
              ? PreferredSize(
                  preferredSize: const Size.fromHeight(56),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
                    child: Container(
                      height: 44,
                      decoration: BoxDecoration(
                        color: const Color(0xff111111),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: const Color(0xff262626)),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.35),
                            blurRadius: 18,
                            offset: const Offset(0, 10),
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          const SizedBox(width: 12),
                          Icon(Icons.search_rounded, color: Colors.white.withValues(alpha: 0.72), size: 20),
                          const SizedBox(width: 6),
                          Expanded(
                            child: TextField(
                              controller: _searchController,
                              focusNode: _searchFocus,
                              onChanged: _onSearchChanged,
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
                                contentPadding: const EdgeInsets.only(top: 2),
                                hintText: t.t('search_my_list'),
                                hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.55)),
                                border: InputBorder.none,
                                enabledBorder: InputBorder.none,
                                focusedBorder: InputBorder.none,
                                disabledBorder: InputBorder.none,
                              ),
                              textInputAction: TextInputAction.search,
                            ),
                          ),
                          if (_searchQuery.trim().isNotEmpty)
                            IconButton(
                              onPressed: _clearSearch,
                              icon: Icon(Icons.close_rounded, color: Colors.white.withValues(alpha: 0.72)),
                              splashRadius: 18,
                              tooltip: t.t('search'),
                            )
                          else
                            const SizedBox(width: 48),
                        ],
                      ),
                    ),
                  ),
                )
              : null,
        ),
        body: SafeArea(child: _MyListGridView(filter: _effectiveQuery)),
        bottomNavigationBar: const AppBottomNavBar(currentIndex: 3), // Diubah dari 2 ke 3
      ),
    );
  }
}

class _MyListGridView extends ConsumerStatefulWidget {
  const _MyListGridView({required this.filter});

  final String filter;

  @override
  ConsumerState<_MyListGridView> createState() => _MyListGridViewState();
}

class _MyListGridViewState extends ConsumerState<_MyListGridView> with AutomaticKeepAliveClientMixin {
  final _controller = ScrollController();
  final _items = <HomeSeries>[];
  var _loading = true;
  var _loadingMore = false;
  var _page = 1;
  var _hasMore = true;
  Object? _error;
  var _generation = 0;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadInitial());
  }

  @override
  void didUpdateWidget(covariant _MyListGridView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.filter.trim() != widget.filter.trim()) {
      if (_controller.hasClients) {
        _controller.jumpTo(0);
      }
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

  Future<void> _loadInitial({bool silent = false}) async {
    final generation = ++_generation;
    final filterSnapshot = widget.filter.trim();
    if (!silent || _items.isEmpty) {
      setState(() {
        _loading = true;
        _error = null;
        if (!silent) _items.clear();
        _page = 1;
        _hasMore = true;
      });
    }
    await _loadPage(1, generation: generation, filter: filterSnapshot, isInitial: true, silent: silent);
  }

  Future<void> _loadMore() async {
    if (!_hasMore) return;
    final generation = _generation;
    final filterSnapshot = widget.filter.trim();
    setState(() {
      _loadingMore = true;
      _error = null;
    });
    await _loadPage(_page + 1, generation: generation, filter: filterSnapshot, isInitial: false);
    if (mounted && generation == _generation) {
      setState(() => _loadingMore = false);
    }
  }

  Future<void> _loadPage(
    int page, {
    required int generation,
    required String filter,
    required bool isInitial,
    bool silent = false,
  }) async {
    try {
      final bootstrap = await ref.read(appBootstrapProvider.future);
      final lang = bootstrap.localeCode;
      final dio = ref.read(dioProvider);

      final res = await dio.get<Map<String, dynamic>>(
        '/v1/my-list',
        queryParameters: {
          'page': page,
          if (lang.trim().isNotEmpty) 'lang': lang,
          if (filter.isNotEmpty) 'q': filter,
        },
      );

      final json = res.data ?? const <String, dynamic>{};
      if (json['status'] != true) {
        throw Exception((json['message'] as String?) ?? 'Failed to load my list');
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
    } on DioException catch (e) {
      final code = e.response?.statusCode ?? 0;
      if (code == 401 || code == 403) {
        await ref.read(authSessionProvider.notifier).logout();
        return;
      }
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

    // Reactively update MyList whenever favorites change anywhere in the app
    ref.listen<AsyncValue<Set<int>>>(favoritesIdsProvider, (previous, next) {
      final prevSet = previous?.valueOrNull;
      final nextSet = next.valueOrNull;
      if (nextSet == null) return;
      if (prevSet != null && setEquals(prevSet, nextSet)) return;

      // 1. If any items were removed, remove them immediately from the local list
      if (prevSet != null) {
        final removed = prevSet.difference(nextSet);
        if (removed.isNotEmpty && mounted) {
          setState(() {
            _items.removeWhere((it) => removed.contains(it.id));
          });
        }
      }

      // 2. If any items were added, silently reload page 1 in the background
      if (prevSet == null || nextSet.difference(prevSet).isNotEmpty) {
        _loadInitial(silent: true);
      }
    });

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
      return RefreshIndicator(
        onRefresh: () => _loadInitial(silent: false),
        color: Colors.white,
        backgroundColor: const Color(0xff111111),
        child: LayoutBuilder(
          builder: (context, constraints) => SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: constraints.maxHeight),
              child: Center(
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
              ),
            ),
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
            padding: const EdgeInsets.fromLTRB(8, 10, 8, 24),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              childAspectRatio: 0.57,
              crossAxisSpacing: 8,
              mainAxisSpacing: 12,
            ),
            itemBuilder: (context, index) {
              final item = _items[index];
              return _MyListPosterTile(
                id: item.id,
                slug: item.slug,
                title: item.title,
                imageUrl: _normalizeImageUrl(item.posterUrl, baseUrl),
                isPremium: item.isPremium,
                isFeatured: item.isFeatured,
                isDubbed: item.isDubbed,
                views: item.views,
                onRemoved: () {
                  setState(() => _items.removeWhere((e) => e.id == item.id));
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
}

class _MyListPosterTile extends ConsumerWidget {
  const _MyListPosterTile({
    required this.id,
    required this.slug,
    required this.title,
    required this.imageUrl,
    required this.isPremium,
    required this.isFeatured,
    required this.isDubbed,
    required this.views,
    required this.onRemoved,
  });

  final int id;
  final String slug;
  final String title;
  final String imageUrl;
  final bool isPremium;
  final bool isFeatured;
  final bool isDubbed;
  final int views;
  final VoidCallback onRemoved;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return _PosterTile(
      id: id,
      title: title,
      imageUrl: imageUrl,
      isPremium: isPremium,
      isFeatured: isFeatured,
      isDubbed: isDubbed,
      views: views,
      onTap: () => context.push('/watch/$slug?title=${Uri.encodeComponent(title)}&poster=${Uri.encodeComponent(imageUrl)}'),
      onToggled: (isFav) {
        if (isFav == false) onRemoved();
      },
    );
  }
}

class _PosterTile extends ConsumerWidget {
  const _PosterTile({
    required this.id,
    required this.title,
    required this.imageUrl,
    required this.isPremium,
    required this.isFeatured,
    required this.isDubbed,
    required this.views,
    required this.onTap,
    this.onToggled,
  });

  final int id;
  final String title;
  final String imageUrl;
  final bool isPremium;
  final bool isFeatured;
  final bool isDubbed;
  final int views;
  final VoidCallback onTap;
  final void Function(bool? isFavorited)? onToggled;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = AppI18n.of(context);
    final viewsLabel = _formatViews(views);
    final favorites = ref.watch(favoritesIdsProvider).valueOrNull ?? const <int>{};
    final isFav = favorites.contains(id);

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AspectRatio(
            aspectRatio: 2 / 3,
            child: ClipRRect(
              borderRadius: BorderRadius.zero,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  AppCachedImage(
                    imageUrl: imageUrl,
                    fit: BoxFit.cover,
                  ),
                  Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.black.withValues(alpha: 0.06),
                          Colors.black.withValues(alpha: 0.62),
                        ],
                      ),
                    ),
                  ),
                  if (isFeatured)
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
                    bottom: 6,
                    start: 10,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.play_arrow_rounded,
                          color: Colors.white.withValues(alpha: 0.92),
                          size: 20,
                          shadows: [
                            Shadow(color: Colors.black.withValues(alpha: 0.6), blurRadius: 18),
                          ],
                        ),
                        if (viewsLabel.isNotEmpty) ...[
                          const SizedBox(width: 4),
                          Text(
                            viewsLabel,
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.92),
                              fontWeight: FontWeight.w900,
                              fontSize: 12,
                              shadows: [
                                Shadow(color: Colors.black.withValues(alpha: 0.55), blurRadius: 12),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  PositionedDirectional(
                    bottom: 6,
                    end: 8,
                    child: GestureDetector(
                      onTap: () async {
                        try {
                          final isNowFav = await ref.read(favoritesIdsProvider.notifier).toggle(id);
                          onToggled?.call(isNowFav);
                          if (!context.mounted) return;
                        } catch (_) {
                          if (!context.mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text(t.t('request_failed'))),
                          );
                        }
                      },
                      child: Container(
                        width: 30,
                        height: 30,
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.35),
                          borderRadius: BorderRadius.circular(999),
                          border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
                        ),
                        child: Icon(
                          isFav ? Icons.bookmark_rounded : Icons.bookmark_border_rounded,
                          color: Colors.white.withValues(alpha: 0.95),
                          size: 18,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.90),
              fontWeight: FontWeight.w500,
              fontSize: 13,
              height: 1.2,
            ),
          ),
        ],
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
    return u
        .replace(
          scheme: base.scheme.isNotEmpty ? base.scheme : u.scheme,
          host: base.host,
          port: base.hasPort ? base.port : u.port,
        )
        .toString();
  }

  if (input.startsWith('/')) {
    return base.replace(path: input).toString();
  }

  return input;
}
