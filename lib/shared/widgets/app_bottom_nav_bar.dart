import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../app/i18n.dart';
import 'water_fill_nav_icon.dart';

/// Unified bottom navigation bar across the application ensuring consistent styling,
/// animations, and instant tab switching.
class AppBottomNavBar extends StatefulWidget {
  const AppBottomNavBar({
    super.key,
    required this.currentIndex,
    this.onTabReselected,
  });

  final int currentIndex;
  final ValueChanged<int>? onTabReselected;

  @override
  State<AppBottomNavBar> createState() => _AppBottomNavBarState();
}

class _AppBottomNavBarState extends State<AppBottomNavBar> {
  int _tapKey = 0;

  @override
  Widget build(BuildContext context) {
    final t = AppI18n.of(context);
    return NavigationBarTheme(
      data: NavigationBarThemeData(
        backgroundColor: const Color(0xff090909).withValues(alpha: 0.98),
        indicatorColor: Colors.transparent,
        labelTextStyle: WidgetStateProperty.all(
          TextStyle(
            fontWeight: FontWeight.w800,
            fontSize: 11,
            color: Colors.white.withValues(alpha: 0.70),
          ),
        ),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return IconThemeData(
            color: selected ? const Color(0xffef233c) : Colors.white.withValues(alpha: 0.58),
            size: 22,
          );
        }),
      ),
      child: NavigationBar(
        selectedIndex: widget.currentIndex,
        onDestinationSelected: (index) {
          if (index == widget.currentIndex) {
            setState(() => _tapKey++);
            widget.onTabReselected?.call(index);
            return;
          }
          if (index == 0) {
            context.go('/home');
            return;
          }
          if (index == 1) {
            context.go('/reels');
            return;
          }
          if (index == 2) {
            context.go('/rewards');
            return;
          }
          if (index == 3) {
            context.go('/my-list');
            return;
          }
          if (index == 4) {
            context.go('/profile');
          }
        },
        destinations: [
          // Index 0: Home
          NavigationDestination(
            icon: Image.asset(
              'assets/images/ms_app_tabbar_icon_category.png',
              width: 28,
              height: 28,
              filterQuality: FilterQuality.low,
            ),
            selectedIcon: WaterFillNavIcon(
              key: ValueKey('nav_home_${widget.currentIndex == 0 ? _tapKey : 0}'),
              unselectedAssetPath: 'assets/images/ms_app_tabbar_icon_category.png',
              selectedAssetPath: 'assets/images/ms_app_tabbar_icon_sel_category.png',
              size: 28,
            ),
            label: t.t('nav_home'),
          ),
          // Index 1: Reels
          NavigationDestination(
            icon: Image.asset(
              'assets/images/ms_app_tabbar_icon_recommend.png',
              width: 28,
              height: 28,
              filterQuality: FilterQuality.low,
            ),
            selectedIcon: WaterFillNavIcon(
              key: ValueKey('nav_reels_${widget.currentIndex == 1 ? _tapKey : 0}'),
              unselectedAssetPath: 'assets/images/ms_app_tabbar_icon_recommend.png',
              selectedAssetPath: 'assets/images/ms_app_tabbar_icon_sel_recommend.png',
              size: 28,
            ),
            label: t.t('nav_reels'),
          ),
          // Index 2: Rewards (Menggunakan ikon mine/rewards .png)
          NavigationDestination(
            icon: Image.asset(
              'assets/images/ms_app_tabbar_icon_mine.png',
              width: 28,
              height: 28,
              filterQuality: FilterQuality.low,
            ),
            selectedIcon: WaterFillNavIcon(
              key: ValueKey('nav_rewards_${widget.currentIndex == 2 ? _tapKey : 0}'),
              unselectedAssetPath: 'assets/images/ms_app_tabbar_icon_mine.png',
              selectedAssetPath: 'assets/images/ms_app_tabbar_icon_sel_mine.png',
              size: 28,
            ),
            label: t.t('nav_rewards'),
          ),
          // Index 3: My List
          NavigationDestination(
            icon: Image.asset(
              'assets/images/ms_app_tabbar_icon_my_list.png',
              width: 28,
              height: 28,
              filterQuality: FilterQuality.low,
            ),
            selectedIcon: WaterFillNavIcon(
              key: ValueKey('nav_my_list_${widget.currentIndex == 3 ? _tapKey : 0}'),
              unselectedAssetPath: 'assets/images/ms_app_tabbar_icon_my_list.png',
              selectedAssetPath: 'assets/images/ms_app_tabbar_icon_sel_my_list.png',
              size: 28,
            ),
            label: t.t('nav_my_list'),
          ),
          // Index 4: Profile
          NavigationDestination(
            icon: Image.asset(
              'assets/images/ms_app_tabbar_icon_mine.png',
              width: 28,
              height: 28,
              filterQuality: FilterQuality.low,
            ),
            selectedIcon: WaterFillNavIcon(
              key: ValueKey('nav_profile_${widget.currentIndex == 4 ? _tapKey : 0}'),
              unselectedAssetPath: 'assets/images/ms_app_tabbar_icon_mine.png',
              selectedAssetPath: 'assets/images/ms_app_tabbar_icon_sel_mine.png',
              size: 28,
            ),
            label: t.t('nav_profile'),
          ),
        ],
      ),
    );
  }
}
