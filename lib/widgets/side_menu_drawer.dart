// widgets/side_menu_drawer.dart
import 'package:flutter/material.dart';
import '../utils/app_colors.dart';
import '../screens/alerts_notifications_screen.dart';
import '../screens/about_screen.dart';

class SideMenuDrawer extends StatelessWidget {
  const SideMenuDrawer({super.key});

  @override
  Widget build(BuildContext context) {
    return Drawer(
      backgroundColor: AppColors.brown,
      child: SafeArea(
        child: Column(
          children: [
            // User Profile Section
            Container(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 30,
                        backgroundColor: AppColors.neutral,
                        child: Icon(
                          Icons.person_outline,
                          color: AppColors.primary,
                          size: 32,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Melon Keeper',
                              style: TextStyle(
                                color: AppColors.white,
                                fontSize: 18,
                                fontFamily: "Poppins",
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'user@example.com',
                              style: TextStyle(
                                color: AppColors.white.withValues(alpha: 0.8),
                                fontSize: 14,
                                fontFamily: "Poppins",
                                fontWeight: FontWeight.w400,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '+60123456789',
                              style: TextStyle(
                                color: AppColors.white.withValues(alpha: 0.8),
                                fontSize: 14,
                                fontFamily: "Poppins",
                                fontWeight: FontWeight.w400,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // Divider
            Container(
              height: 1,
              color: AppColors.white,
              margin: const EdgeInsets.symmetric(horizontal: 24),
            ),

            const SizedBox(height: 24),

            // Menu Items
            _buildMenuItem(
              iconPath: "assets/images/alert_icon.png",
              title: 'Alerts & Notifications',
              onTap: () {
                Navigator.pop(context); // Close drawer
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const AlertsNotificationsScreen(),
                  ),
                );
              },
            ),

            _buildMenuItem(
              iconPath: "assets/images/about_icon.png",
              title: 'About',
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const AboutScreen()),
                );
              },
            ),

            const Spacer(),

            // Divider
            Container(
              height: 1,
              color: AppColors.white,
              margin: const EdgeInsets.symmetric(horizontal: 24),
            ),

            // Exit Button
            Padding(
              padding: const EdgeInsets.all(24),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  TextButton.icon(
                    onPressed: () {
                      Navigator.pop(context);
                    },
                    icon: Image.asset(
                      "assets/images/exit_icon.png",
                      width: 24,
                      height: 24,
                      color: AppColors.white,
                    ),
                    label: Text(
                      'Exit',
                      style: TextStyle(
                        color: AppColors.white,
                        fontSize: 16,
                        fontFamily: "Poppins",
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMenuItem({
    required String iconPath,
    required String title,
    required VoidCallback onTap,
  }) {
    return ListTile(
      leading: Image.asset(
        iconPath,
        width: 24,
        height: 24,
        color: AppColors.white,
      ),
      title: Text(
        title,
        style: TextStyle(
          color: AppColors.white,
          fontSize: 16,
          fontFamily: "Poppins",
          fontWeight: FontWeight.w400,
        ),
      ),
      onTap: onTap,
    );
  }
}
