import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/i18n.dart';
import '../domain/home_feed.dart';
import 'series_more_bottom_sheet.dart';

Future<void> showGenresMoreBottomSheet(
  BuildContext context,
  WidgetRef ref, {
  required List<HomeCategory> categories,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    isDismissible: true,
    enableDrag: true,
    backgroundColor: Colors.transparent,
    builder: (sheetContext) {
      return _GenresMoreSheet(
        parentContext: context,
        categories: categories,
      );
    },
  );
}

class _GenresMoreSheet extends ConsumerWidget {
  const _GenresMoreSheet({
    required this.parentContext,
    required this.categories,
  });

  final BuildContext parentContext;
  final List<HomeCategory> categories;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = AppI18n.of(context);
    final media = MediaQuery.of(context);

    return SafeArea(
      top: false,
      child: Padding(
        padding: EdgeInsets.only(top: media.size.height * 0.18),
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
                          t.t('genres'),
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
                  child: ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 10, 16, 18),
                    itemBuilder: (context, index) {
                      final c = categories[index];
                      return InkWell(
                        onTap: () {
                          Navigator.of(context).pop();
                          Future.microtask(() {
                            if (!parentContext.mounted) return;
                            showSeriesMoreBottomSheet(
                              parentContext,
                              ref,
                              title: c.name,
                              query: {'category_slug': c.slug},
                            );
                          });
                        },
                        borderRadius: BorderRadius.circular(16),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.06),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  c.name,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w900,
                                    fontSize: 14,
                                  ),
                                ),
                              ),
                              const Icon(Icons.chevron_right_rounded, color: Colors.white),
                            ],
                          ),
                        ),
                      );
                    },
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemCount: categories.length,
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
