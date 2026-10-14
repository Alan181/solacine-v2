import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import '../../../../../app/i18n.dart';

class WalletTypeTabs extends StatelessWidget {
  const WalletTypeTabs({
    super.key,
    required this.selected,
    required this.onSelect,
  });

  final String selected;
  final ValueChanged<String> onSelect;

  @override
  Widget build(BuildContext context) {
    final t = AppI18n.of(context);
    Widget tabChild({required bool isSelected, required String title, required String iconAsset}) {
      final fg = isSelected ? Colors.white.withValues(alpha: 0.96) : Colors.white.withValues(alpha: 0.70);
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Image.asset(
                iconAsset,
                width: 20,
                height: 20,
                fit: BoxFit.contain,
                filterQuality: FilterQuality.low,
                errorBuilder: (context, error, stackTrace) => const SizedBox(width: 20, height: 20),
              ),
              const SizedBox(width: 8),
              Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: fg,
                  fontSize: 13,
                  fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Container(
      height: 46,
      decoration: BoxDecoration(
        color: const Color(0xff0b0b0b),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
      ),
      padding: const EdgeInsets.all(3),
      child: CupertinoSlidingSegmentedControl<String>(
        groupValue: selected,
        backgroundColor: const Color(0xff0b0b0b),
        thumbColor: const Color(0xff1c1c1e),
        padding: const EdgeInsets.all(3),
        children: {
          'coins': tabChild(
            isSelected: selected == 'coins',
            title: t.t('coins'),
            iconAsset: 'assets/images/push_pro_icon.png',
          ),
          'membership': tabChild(
            isSelected: selected == 'membership',
            title: t.t('membership'),
            iconAsset: 'assets/images/ic_stone.png',
          ),
        },
        onValueChanged: (v) {
          if (v == null) return;
          if (v == selected) return;
          onSelect(v);
        },
      ),
    );
  }
}
