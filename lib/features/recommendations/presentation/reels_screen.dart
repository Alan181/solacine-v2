import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:dramereel_mobile/shared/widgets/active_shell_branch_scope.dart';
import 'package:dramereel_mobile/shared/widgets/app_bottom_nav_bar.dart';
import 'package:dramereel_mobile/shared/widgets/app_cached_image.dart';
import 'package:dramereel_mobile/shared/widgets/app_loading_indicator.dart';
import '../../../app/i18n.dart';
import '../../ads/application/ads_initializer.dart';
import '../../ads/application/ads_providers.dart';
import '../../watch/presentation/watch_screen.dart';
import '../application/reels_preload_manager.dart';
import '../application/recommendations_controller.dart';
import '../domain/recommendations_feed.dart';

class ReelsScreen extends ConsumerStatefulWidget {
  const ReelsScreen({super.key});

  @override
  ConsumerState<ReelsScreen> createState() => _ReelsScreenState();
}

class _ReelsScreenState extends ConsumerState<ReelsScreen> with WidgetsBindingObserver {
  final _controller = PageController();
  var _index = 0;
  var _prefetchedIndex = -1;
  var _isAppForeground = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _controller.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final fg = state == AppLifecycleState.resumed;
    if (_isAppForeground != fg) {
      if (mounted) setState(() => _isAppForeground = fg);
    }
  }

  var _reelSwipeCount = 0;

  Future<void> _maybeShowInterstitialOnReelExit() async {
    if (!mounted) return;
    _reelSwipeCount++;
    if (_reelSwipeCount % 6 != 0) return;
    final isVip = ref.read(isVipProvider);
    if (isVip) return;
    final cfg = ref.read(adsConfigProvider);
    if (cfg == null) return;
    final service = ref.read(adsServiceProvider);
    if (!service.adsEnabled(cfg)) return;
    try {
      await service.showInterstitial();
    } catch (_) {}
  }

  void _prefetchAround(List<RecommendationItem> items, int index) {
    if (!mounted) return;
    if (items.isEmpty) return;
    if (_prefetchedIndex == index) return;
    _prefetchedIndex = index;

    final candidates = <int>{
      index,
      index + 1,
      index - 1,
      index + 2,
    };

    for (final i in candidates) {
      if (i < 0 || i >= items.length) continue;
      final it = items[i];
      final url = (it.posterUrl.trim().isNotEmpty ? it.posterUrl : it.featuredImageUrl).trim();
      if (url.isNotEmpty) {
        precacheImage(NetworkImage(url), context);
      }
      if (i >= index && i <= index + 2) {
        final slug = it.watchSlug.trim().isNotEmpty ? it.watchSlug : it.slug;
        final ep = it.watchEpisodeNumber > 0 ? it.watchEpisodeNumber : 1;
        ReelsPreloadManager.prefetch(ref: ref, slug: slug, episode: ep);
      }
    }
  }

  void _handleReelsTabReselected() {
    ref.invalidate(recommendationsFeedProvider);
    if (_controller.hasClients) {
      _controller.jumpToPage(0);
    }
    setState(() {
      _index = 0;
    });
  }

  @override
  Widget build(BuildContext context) {
    final t = AppI18n.of(context);
    final feed = ref.watch(recommendationsFeedProvider);

    final content = feed.when(
      data: (data) {
        final items = data.items;
        if (items.isEmpty) {
          return Center(
            child: Text(
              t.t('no_content'),
              style: TextStyle(color: Colors.white.withValues(alpha: 0.85)),
            ),
          );
        }

        if (_index >= items.length) {
          _index = 0;
        }

        WidgetsBinding.instance.addPostFrameCallback((_) {
          _prefetchAround(items, _index);
        });

        final activeBranch = ActiveShellBranchScope.maybeOf(context);
        final isReelsBranchActive = (activeBranch == null || activeBranch == 1);
        final isCurrentRoute = ModalRoute.of(context)?.isCurrent ?? true;
        final isVisible = isReelsBranchActive && isCurrentRoute && _isAppForeground;

        return PageView.builder(
          controller: _controller,
          scrollDirection: Axis.vertical,
          onPageChanged: (i) {
            final effectiveIdx = items.isEmpty ? 0 : (i % items.length);
            final prev = _index;
            setState(() => _index = i);
            _prefetchAround(items, effectiveIdx);
            if (i != prev) {
              Future.microtask(_maybeShowInterstitialOnReelExit);
            }
          },
          itemCount: items.isEmpty ? 0 : (items.length * 10),
          itemBuilder: (context, i) {
            final it = items[i % items.length];
            if (i != _index) {
              return _ReelsPlaceholder(item: it);
            }

            final slug = it.watchSlug.trim().isNotEmpty ? it.watchSlug : it.slug;
            final ep = it.watchEpisodeNumber > 0 ? it.watchEpisodeNumber : 1;
            final poster = (it.posterUrl.trim().isNotEmpty ? it.posterUrl : it.featuredImageUrl).trim();
            return WatchScreen(
              key: ValueKey('reels_${slug}_${ep}_$i'),
              slug: slug,
              title: it.title,
              episodeNumber: ep,
              reelsPreview: true,
              reelsBackdropUrl: poster,
              posterUrl: poster,
              isActive: isVisible,
            );
          },
        );
      },
      loading: () => const Center(
        child: AppLoadingIndicator(radius: 14),
      ),
      error: (e, st) {
        final err = appUserErrorFor(e);
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
                  onPressed: () => ref.invalidate(recommendationsFeedProvider),
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
      },
    );

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        context.go('/home');
      },
      child: Scaffold(
        backgroundColor: Colors.black,
        body: content,
        bottomNavigationBar: AppBottomNavBar(
          currentIndex: 1,
          onTabReselected: (index) {
            if (index == 1) {
              _handleReelsTabReselected();
            }
          },
        ),
      ),
    );
  }
}

class _ReelsPlaceholder extends StatelessWidget {
  const _ReelsPlaceholder({required this.item});

  final RecommendationItem item;

  @override
  Widget build(BuildContext context) {
    final bg = item.posterUrl.trim().isNotEmpty ? item.posterUrl : item.featuredImageUrl;
    return Stack(
      fit: StackFit.expand,
      children: [
        if (bg.trim().isNotEmpty)
          AppCachedImage(
            imageUrl: bg,
            fit: BoxFit.cover,
          )
        else
          Container(color: const Color(0xff0e0e0e)),
        Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Colors.black.withValues(alpha: 0.20),
                Colors.black.withValues(alpha: 0.85),
              ],
            ),
          ),
        ),
        const Center(
          child: AppLoadingIndicator(radius: 14),
        ),
      ],
    );
  }
}
