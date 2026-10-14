import 'package:flutter/material.dart';
import '../../../../shared/widgets/app_bottom_nav_bar.dart';

class ProfileBottomNavigation extends StatelessWidget {
  const ProfileBottomNavigation({super.key});

  @override
  Widget build(BuildContext context) {
    return const AppBottomNavBar(currentIndex: 3);
  }
}
