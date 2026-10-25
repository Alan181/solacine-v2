import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:solacine_mobile/shared/widgets/app_cached_image.dart';
import '../../../shared/widgets/app_loading_indicator.dart';
import '../../../app/i18n.dart';
import '../../home/domain/home_feed.dart';
import '../application/genres_controller.dart';

class GenresScreen extends ConsumerWidget {
  const GenresScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = AppI18n.of(context);
    final sections = ref.watch(genresSectionsProvider);

    return PopScope(
      canPop: Navigator.of(context).canPop(),
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        context.go('/home');
      },
      child: Scaffold(
        backgroundColor: const Color(0xff050505),
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          foregroundColor: Colors.white,
          title: Text(t.t('genres')),
        ),
        body: SafeArea(
          child: sections.when(
            data: (value) => ListView.separated(
              padding: const EdgeInsets.fromLTRB(0, 8, 0, 18),
              itemBuilder: (context, index) {
                final section = value[index];
                return _GenreSection(section: section);
              },
              separatorBuilder: (_, __) => const SizedBox(height: 16),
              itemCount: value.length,
            ),
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
                        onPressed: () => ref.invalidate(genresSectionsProvider),
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

class _GenreSection extends StatelessWidget {
  const _GenreSection({required this.section});

  final HomeSection section;

  @override
  Widget build(BuildContext context) {
    final t = AppI18n.of(context);
    _slugFromKey(section.key);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: Text(
            section.title.isEmpty ? t.t('title') : section.title,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w900,
              fontSize: 18,
            ),
          ),
        ),
        SizedBox(
          height: 210,
          child: ListView.separated(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            scrollDirection: Axis.horizontal,
            itemBuilder: (context, index) {
              final item = section.items[index];
              return _PosterCard(
                title: item.title,
                imageUrl: item.posterUrl,
                onTap: () {
                  final p = item.posterUrl.isNotEmpty
                      ? '&poster=${Uri.encodeComponent(item.posterUrl)}'
                      : '';
                  context.push('/watch/${item.slug}?title=${Uri.encodeComponent(item.title)}$p');
                },
              );
            },
            separatorBuilder: (_, __) => const SizedBox(width: 12),
            itemCount: section.items.length,
          ),
        ),
      ],
    );
  }
}

class _PosterCard extends StatelessWidget {
  const _PosterCard({required this.title, required this.imageUrl, this.onTap});

  final String title;
  final String imageUrl;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 130,
      child: GestureDetector(
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AspectRatio(
              aspectRatio: 2 / 3,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: AppCachedImage(
                  imageUrl: imageUrl,
                  fit: BoxFit.cover,
                  width: double.infinity,
                  height: double.infinity,
                  errorWidget: (_) => Container(
                    color: const Color(0xFF18181B),
                    alignment: Alignment.center,
                    child: const Icon(Icons.movie, size: 42, color: Color(0xFF3F3F46)),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
    );
  }
}

String _slugFromKey(String key) {
  final s = key.toLowerCase().replaceAll(RegExp(r'[^a-z0-9\s-]'), '').trim().replaceAll(RegExp(r'\s+'), '-');
  if (s.isEmpty) return key;
  return s;
}
