import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:solacine_mobile/shared/widgets/app_cached_image.dart';
import '../../../shared/widgets/app_loading_indicator.dart';
import '../../../app/i18n.dart';
import '../application/genre_series_controller.dart';

class GenreSeriesScreen extends ConsumerWidget {
  const GenreSeriesScreen({
    super.key,
    required this.slug,
    required this.title,
  });

  final String slug;
  final String title;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = AppI18n.of(context);
    final series = ref.watch(genreSeriesProvider(slug));

    return PopScope(
      canPop: Navigator.of(context).canPop(),
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        context.go('/genres');
      },
      child: Scaffold(
        backgroundColor: const Color(0xff050505),
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          foregroundColor: Colors.white,
          title: Text(title.isNotEmpty ? title : t.t('genres')),
        ),
        body: SafeArea(
          child: series.when(
            data: (value) {
              return GridView.builder(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  childAspectRatio: 2 / 3.35,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 14,
                ),
                itemBuilder: (context, index) {
                  final item = value[index];
                  return _PosterTile(
                    title: item.title,
                    imageUrl: item.posterUrl,
                    isPremium: item.isPremium,
                    onTap: () {
                      final p = item.posterUrl.isNotEmpty
                          ? '&poster=${Uri.encodeComponent(item.posterUrl)}'
                          : '';
                      context.push('/watch/${item.slug}?title=${Uri.encodeComponent(item.title)}$p');
                    },
                  );
                },
                itemCount: value.length,
              );
            },
            loading: () => const Center(
              child: AppLoadingIndicator(radius: 13),
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
                        onPressed: () => ref.invalidate(genreSeriesProvider(slug)),
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
            flex: 9,
            child: Stack(
              children: [
                Positioned.fill(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: AppCachedImage(
                      imageUrl: imageUrl,
                      fit: BoxFit.cover,
                      width: double.infinity,
                      height: double.infinity,
                      errorWidget: (_) => Container(
                        color: const Color(0xFF18181B),
                        alignment: Alignment.center,
                        child: const Icon(Icons.movie, size: 32, color: Color(0xFF3F3F46)),
                      ),
                    ),
                  ),
                ),
                if (isPremium)
                  Positioned(
                    top: 6,
                    right: 6,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFCB05),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        t.t('premium'),
                        style: const TextStyle(color: Colors.black, fontWeight: FontWeight.w900, fontSize: 10),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 6),
          Text(
            title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}
