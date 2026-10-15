import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/i18n.dart';
import '../../shared/widgets/app_bottom_nav_bar.dart';
import '../../shared/widgets/app_loading_indicator.dart';
import '../bootstrap/application/bootstrap_controller.dart';
import '../ads/presentation/ad_banner.dart';
import 'application/home_controller.dart';
import 'presentation/series_grid_view.dart';
import 'presentation/series_ranking_list_view.dart';
import '../recommendations/application/recommendations_controller.dart';
import '../recommendations/application/reels_preload_manager.dart';
import '../ads/application/ads_providers.dart';
import '../ads/application/vast_ad_service.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> with TickerProviderStateMixin {
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: 5,
      vsync: this,
      animationDuration: const Duration(milliseconds: 520),
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // 1. Warm up Reels feed and preload first reel in background so Reels tab opens instantly
      ref.read(recommendationsFeedProvider.future).then((feed) {
        if (feed.items.isNotEmpty) {
          final first = feed.items.first;
          final slug = first.watchSlug.trim().isNotEmpty ? first.watchSlug : first.slug;
          final ep = first.watchEpisodeNumber > 0 ? first.watchEpisodeNumber : 1;
          ReelsPreloadManager.prefetch(ref: ref, slug: slug, episode: ep);
        }
      }).catchError((_) {});

      // 2. Preload VAST ad in background so tapping any poster never stalls
      final adsCfg = ref.read(adsConfigProvider);
      if (adsCfg != null && adsCfg.vast.enabled && adsCfg.vast.url.trim().isNotEmpty) {
        VastAdService.preload(adsCfg.vast.url.trim(), defaultSkipSeconds: adsCfg.vast.skipSeconds);
      }
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = AppI18n.of(context);
    final bootstrap = ref.watch(appBootstrapProvider).valueOrNull;
    final appName = (bootstrap?.publicSettings['app_name'] as String?) ?? t.t('app_name');
    final topPadding = MediaQuery.paddingOf(context).top;

    return PopScope(
      canPop: false, // Mencegah langsung keluar aplikasi saat tombol back ditekan
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        // Saat tombol back HP ditekan di Home, arahkan kembali ke Reels
        context.go('/reels');
      },
      child: Scaffold(
        backgroundColor: const Color(0xff050505),
        body: Stack(
          children: [
            Positioned(
              left: 0,
              right: 0,
              top: 0,
              height: 280,
              child: IgnorePointer(
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    Opacity(
                      opacity: 0.25,
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
            Column(
              children: [
                Padding(
                  padding: EdgeInsets.fromLTRB(16, topPadding + 6, 16, 10),
                  child: _ExploreTopBar(appName: appName),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 6),
                  child: Align(
                    alignment: AlignmentDirectional.centerStart,
                    child: TabBar(
                      controller: _tabController,
                      isScrollable: true,
                      tabAlignment: TabAlignment.start,
                      dividerColor: Colors.transparent,
                      indicatorColor: const Color(0xffef233c),
                      indicatorSize: TabBarIndicatorSize.label,
                      labelColor: Colors.white,
                      unselectedLabelColor: Colors.white.withValues(alpha: 0.55),
                      labelStyle: const TextStyle(fontWeight: FontWeight.w900, fontSize: 15),
                      unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
                      tabs: [
                        Tab(text: t.t('discover')),
                        Tab(text: t.t('new_releases')),
                        Tab(text: t.t('categories')),
                        Tab(text: t.t('ranking')),
                        Tab(text: t.t('dubbed')),
                      ],
                    ),
                  ),
                ),
                Expanded(
                  child: TabBarView(
                    controller: _tabController,
                    children: const [
                      _DiscoverTab(),
                      _NewReleasesTab(),
                      _CategoriesTab(),
                      _RankingTab(),
                      _DubbedTab(),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
        bottomNavigationBar: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              color: const Color(0xff050505),
              alignment: Alignment.center,
              child: const SafeArea(
                top: false,
                child: AdBanner(),
              ),
            ),
            const AppBottomNavBar(currentIndex: 0),
          ],
        ),
      ),
    );
  }
}

class _ExploreTopBar extends ConsumerStatefulWidget {
  const _ExploreTopBar({required this.appName});

  final String appName;

  @override
  ConsumerState<_ExploreTopBar> createState() => _ExploreTopBarState();
}

class _ExploreTopBarState extends ConsumerState<_ExploreTopBar> {
  bool _showSearchHint = false;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 3), (_) {
      if (!mounted) return;
      setState(() => _showSearchHint = !_showSearchHint);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = AppI18n.of(context);
    final text = _showSearchHint ? t.t('search_drama_hint') : widget.appName;

    return Row(
      children: [
        InkWell(
          onTap: () => context.push('/membership'),
          borderRadius: BorderRadius.circular(14),
          child: Container(
            width: 44,
            height: 44,
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
            ),
            child: Image.asset(
              'assets/images/vip_config_icon.webp',
              fit: BoxFit.contain,
              filterQuality: FilterQuality.low,
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: GestureDetector(
            onTap: () => context.push('/search'),
            behavior: HitTestBehavior.opaque,
            child: Container(
              height: 44,
              padding: const EdgeInsets.symmetric(horizontal: 14),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
              ),
              child: Row(
                children: [
                  Icon(Icons.search_rounded, color: Colors.white.withValues(alpha: 0.70), size: 20),
                  const SizedBox(width: 10),
                  Expanded(
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 260),
                      switchInCurve: Curves.easeOutCubic,
                      switchOutCurve: Curves.easeInCubic,
                      layoutBuilder: (currentChild, previousChildren) {
                        return Stack(
                          alignment: AlignmentDirectional.centerStart,
                          children: <Widget>[
                            ...previousChildren,
                            currentChild ?? const SizedBox.shrink(),
                          ],
                        );
                      },
                      transitionBuilder: (child, anim) {
                        final slide = Tween<Offset>(
                          begin: const Offset(0, -0.12),
                          end: Offset.zero,
                        ).animate(anim);
                        return FadeTransition(
                          opacity: anim,
                          child: SlideTransition(position: slide, child: child),
                        );
                      },
                      child: Text(
                        text,
                        key: ValueKey(text),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.72),
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -.2,
                        ),
                      ),
                    ),
                  ),
                  Text(
                    t.t('discover'),
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.25),
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -.2,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _DiscoverTab extends StatelessWidget {
  const _DiscoverTab();
 
  @override
  Widget build(BuildContext context) {
    return const SeriesGridView(query: {'sort': 'popular'});
  }
}
 
class _NewReleasesTab extends StatelessWidget {
  const _NewReleasesTab();
 
  @override
  Widget build(BuildContext context) {
    return const SeriesGridView(query: {});
  }
}

class _RankingTab extends StatefulWidget {
  const _RankingTab();

  @override
  State<_RankingTab> createState() => _RankingTabState();
}

class _RankingTabState extends State<_RankingTab> with AutomaticKeepAliveClientMixin {
  var _index = 0;

  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final t = AppI18n.of(context);
    final query = switch (_index) {
      0 => const {'sort': 'popular'},
      1 => const <String, dynamic>{},
      2 => const {'__endpoint': 'trending'},
      _ => const <String, dynamic>{},
    };

    return Column(
      children: [
        SizedBox(
          height: 38,
          child: ListView(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            scrollDirection: Axis.horizontal,
            children: [
              _FilterChip(
                label: t.t('popular'),
                selected: _index == 0,
                onTap: () => setState(() => _index = 0),
              ),
              const SizedBox(width: 10),
              _FilterChip(
                label: t.t('new_releases'),
                selected: _index == 1,
                onTap: () => setState(() => _index = 1),
              ),
              const SizedBox(width: 10),
              _FilterChip(
                label: t.t('top_now'),
                selected: _index == 2,
                onTap: () => setState(() => _index = 2),
              ),
            ],
          ),
        ),
        const SizedBox(height: 6),
        Expanded(
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 480),
            switchInCurve: Curves.easeOutCubic,
            switchOutCurve: Curves.easeInCubic,
            transitionBuilder: (child, animation) {
              final slide = Tween<Offset>(
                begin: const Offset(0.06, 0),
                end: Offset.zero,
              ).animate(animation);
              return FadeTransition(
                opacity: animation,
                child: SlideTransition(position: slide, child: child),
              );
            },
            child: SeriesRankingListView(
              key: ValueKey(_index),
              query: query,
            ),
          ),
        ),
      ],
    );
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: Container(
        alignment: Alignment.center,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? Colors.white.withValues(alpha: 0.12) : Colors.white.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: selected ? Colors.white.withValues(alpha: 0.20) : Colors.white.withValues(alpha: 0.10),
          ),
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Colors.white,
            fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
            fontSize: 12,
          ),
        ),
      ),
    );
  }
}

class _DubbedTab extends StatelessWidget {
  const _DubbedTab();

  @override
  Widget build(BuildContext context) {
    return const SeriesGridView(query: {'dubbed': true, 'sort': 'popular'});
  }
}
 
class _CategoriesTab extends ConsumerStatefulWidget {
  const _CategoriesTab();
 
  @override
  ConsumerState<_CategoriesTab> createState() => _CategoriesTabState();
}
 
class _CategoriesTabState extends ConsumerState<_CategoriesTab> with AutomaticKeepAliveClientMixin {
  String _selectedSlug = '';

  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final feed = ref.watch(homeFeedProvider);
 
    return feed.when(
      data: (value) {
        final categories = value.categories;
        if (_selectedSlug.isEmpty && categories.isNotEmpty) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted) return;
            setState(() => _selectedSlug = categories.first.slug);
          });
        }
 
        return Column(
          children: [
            if (categories.isNotEmpty)
              const SizedBox(height: 10),
            if (categories.isNotEmpty)
              SizedBox(
                height: 38,
                child: ListView.separated(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  scrollDirection: Axis.horizontal,
                  itemBuilder: (context, index) {
                    final c = categories[index];
                    final selected = c.slug == _selectedSlug;
                    return InkWell(
                      onTap: () => setState(() => _selectedSlug = c.slug),
                      borderRadius: BorderRadius.circular(999),
                      child: Container(
                        alignment: Alignment.center,
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: selected ? Colors.white.withValues(alpha: 0.12) : Colors.white.withValues(alpha: 0.06),
                          borderRadius: BorderRadius.circular(999),
                          border: Border.all(
                            color: selected ? Colors.white.withValues(alpha: 0.20) : Colors.white.withValues(alpha: 0.10),
                          ),
                        ),
                        child: Text(
                          c.name,
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    );
                  },
                  separatorBuilder: (_, __) => const SizedBox(width: 10),
                  itemCount: categories.length,
                ),
              ),
            const SizedBox(height: 6),
            Expanded(
              child: SeriesGridView(
                query: _selectedSlug.isEmpty ? const {} : {'category_slug': _selectedSlug},
              ),
            ),
          ],
        );
      },
      loading: () => const Center(
        child: AppLoadingIndicator(radius: 13),
      ),
      error: (e, st) {
        final err = appUserErrorFor(e);
        return _HomeError(
          titleKey: err.titleKey,
          descKey: err.descKey,
          onRetry: () => ref.invalidate(homeFeedProvider),
        );
      },
    );
  }
}

class _HomeError extends StatelessWidget {
  const _HomeError({
    required this.titleKey,
    required this.descKey,
    required this.onRetry,
  });

  final String titleKey;
  final String descKey;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final t = AppI18n.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              t.t(titleKey),
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 18),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              t.t(descKey),
              style: TextStyle(color: Colors.white.withValues(alpha: 0.65)),
              textAlign: TextAlign.center,
              maxLines: 4,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 14),
            ElevatedButton(
              onPressed: onRetry,
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
}
