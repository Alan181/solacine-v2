import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/i18n.dart';
import '../../my_list/application/favorites_controller.dart';

Future<void> showSeriesActionSheet(
  BuildContext context, {
  required int seriesId,
  required String title,
  String subtitle = '',
  required VoidCallback onWatch,
}) {
  HapticFeedback.mediumImpact();

  return showCupertinoModalPopup<void>(
    context: context,
    barrierColor: Colors.black.withValues(alpha: 0.65),
    builder: (sheetContext) {
      return CupertinoTheme(
        data: const CupertinoThemeData(
          brightness: Brightness.dark,
          primaryColor: CupertinoColors.systemBlue,
        ),
        child: SeriesActionSheet(
          seriesId: seriesId,
          title: title,
          subtitle: subtitle,
          onWatch: onWatch,
        ),
      );
    },
  );
}

class SeriesActionSheet extends ConsumerWidget {
  final int seriesId;
  final String title;
  final String subtitle;
  final VoidCallback onWatch;

  const SeriesActionSheet({
    super.key,
    required this.seriesId,
    required this.title,
    this.subtitle = '',
    required this.onWatch,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = AppI18n.of(context);
    final isAr = t.locale.languageCode == 'ar';
    final favorites = ref.watch(favoritesIdsProvider).valueOrNull ?? const <int>{};
    final isFav = favorites.contains(seriesId);

    return CupertinoActionSheet(
      title: Text(
        title,
        style: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w700,
          color: Colors.white,
        ),
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        textAlign: TextAlign.center,
      ),
      message: subtitle.trim().isNotEmpty
          ? Text(
              subtitle,
              style: TextStyle(
                fontSize: 13,
                color: Colors.white.withValues(alpha: 0.60),
              ),
              textAlign: TextAlign.center,
            )
          : null,
      actions: [
        CupertinoActionSheetAction(
          onPressed: () {
            Navigator.of(context).pop();
            onWatch();
          },
          child: Text(
            isAr ? 'مشاهدة الآن' : 'Watch Now',
            style: const TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 18,
              color: CupertinoColors.systemBlue,
            ),
          ),
        ),
        CupertinoActionSheetAction(
          isDestructiveAction: isFav,
          onPressed: () async {
            Navigator.of(context).pop();
            try {
              final isNowFav =
                  (await ref.read(favoritesIdsProvider.notifier).toggle(seriesId)) == true;
              if (!context.mounted) return;
              HapticFeedback.lightImpact();
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    isNowFav
                        ? (isAr ? 'تمت الإضافة إلى المفضلة' : 'Added to Favorites')
                        : (isAr ? 'تمت الإزالة من المفضلة' : 'Removed from Favorites'),
                  ),
                  duration: const Duration(seconds: 2),
                  behavior: SnackBarBehavior.floating,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
              );
            } catch (_) {
              if (!context.mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text(t.t('request_failed'))),
              );
            }
          },
          child: Text(
            isFav
                ? (isAr ? 'إزالة من المفضلة' : 'Remove from Favorites')
                : (isAr ? 'إضافة إلى المفضلة' : 'Add to Favorites'),
            style: TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 18,
              color: isFav ? CupertinoColors.destructiveRed : CupertinoColors.systemBlue,
            ),
          ),
        ),
      ],
      cancelButton: CupertinoActionSheetAction(
        isDefaultAction: true,
        onPressed: () => Navigator.of(context).pop(),
        child: Text(
          isAr ? 'إلغاء' : 'Cancel',
          style: const TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 18,
            color: CupertinoColors.systemBlue,
          ),
        ),
      ),
    );
  }
}
