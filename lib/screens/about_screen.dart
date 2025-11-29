// screens/about_screen.dart
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../utils/app_colors.dart';

class AboutScreen extends StatefulWidget {
  const AboutScreen({super.key});

  @override
  State<AboutScreen> createState() => _AboutScreenState();
}

class _AboutScreenState extends State<AboutScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        leading: Padding(
          padding: const EdgeInsets.all(8.0),
          child: Container(
            decoration: BoxDecoration(
              color: AppColors.brown,
              borderRadius: BorderRadius.circular(12),
            ),
            child: IconButton(
              icon: Image.asset(
                'assets/images/back_icon.png',
                width: 24,
                height: 24,
                color: AppColors.white,
              ),
              onPressed: () {
                Navigator.pop(context);
              },
            ),
          ),
        ),
        title: Text(
          'About Terra',
          style: TextStyle(
            color: AppColors.primary,
            fontSize: 20,
            fontWeight: FontWeight.w700,
            fontFamily: "Poppins",
          ),
        ),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // App Logo and Title
            Center(
              child: Column(
                children: [
                  Container(
                    width: 100,
                    height: 100,
                    decoration: BoxDecoration(
                      color: AppColors.primary,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.primary.withValues(alpha: 0.3),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Icon(
                      Icons.agriculture,
                      size: 50,
                      color: AppColors.white,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Terra',
                    style: TextStyle(
                      color: AppColors.primary,
                      fontSize: 32,
                      fontWeight: FontWeight.w800,
                      fontFamily: "Poppins",
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'IoT-Enabled Melon Monitoring',
                    style: TextStyle(
                      color: AppColors.brown,
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                      fontFamily: "Poppins",
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),

            // App Summary
            _buildSection(
              title: 'App Summary',
              child: Text(
                'Terra is an IoT-enabled monitoring app for Japanese musk melon cultivation at UTAR Kampar Greenhouse. It shows real-time and historical data for soil moisture, temperature, and humidity, and it notifies you when readings cross configured thresholds.',
                style: TextStyle(
                  color: AppColors.primary,
                  fontSize: 14,
                  fontFamily: "Poppins",
                  fontWeight: FontWeight.w400,
                  height: 1.5,
                ),
              ),
            ),

            // Purpose & Value
            _buildSection(
              title: 'Purpose & Value',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildSubsection(
                    title: 'Why',
                    content:
                        'Reduce manual checks, save water, and improve crop consistency.',
                  ),
                  const SizedBox(height: 12),
                  _buildSubsection(
                    title: 'How',
                    content:
                        'Use ESP32 + sensors to stream greenhouse data to the cloud, then visualize and alert on mobile.',
                  ),
                  const SizedBox(height: 12),
                  _buildSubsection(
                    title: 'Goal',
                    content:
                        'Make precision farming practical and affordable for small-scale growers.',
                  ),
                ],
              ),
            ),

            // Key Features
            _buildSection(
              title: 'Key Features',
              child: Column(
                children: [
                  _buildFeatureItem(
                    'Live dashboard for T/RH and soil moisture (per channel/plant)',
                  ),
                  _buildFeatureItem('Trends (today/weekly/monthly)'),
                  _buildFeatureItem('Threshold-based alerts and notifications'),
                  _buildFeatureItem('Basket/plant organization and notes'),
                  _buildFeatureItem(
                    'Read-only schedules (watering, fertilizing, pest notes)',
                  ),
                ],
              ),
            ),

            // What Powers Terra
            _buildSection(
              title: 'What Powers Terra',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildTechItem(
                    category: 'Hardware',
                    items:
                        'ESP32, CD74HC4067 multiplexer, capacitive soil moisture sensors, DHT22, SSD1306 OLED',
                  ),
                  const SizedBox(height: 12),
                  _buildTechItem(
                    category: 'Network/Cloud',
                    items:
                        'Portable Wi-Fi router, Firebase Realtime Database + Cloud Functions',
                  ),
                  const SizedBox(height: 12),
                  _buildTechItem(
                    category: 'App',
                    items:
                        'Flutter (Android; iOS optional), push notifications',
                  ),
                ],
              ),
            ),

            // Data & Privacy
            _buildSection(
              title: 'Data & Privacy',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Sensor data (moisture, temperature, humidity) is sent securely to the project\'s Firebase database.',
                    style: TextStyle(
                      color: AppColors.primary,
                      fontSize: 14,
                      fontFamily: "Poppins",
                      fontWeight: FontWeight.w400,
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'No personal data beyond basic account credentials is collected.',
                    style: TextStyle(
                      color: AppColors.primary,
                      fontSize: 14,
                      fontFamily: "Poppins",
                      fontWeight: FontWeight.w400,
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Alerts are generated from your configured thresholds.',
                    style: TextStyle(
                      color: AppColors.primary,
                      fontSize: 14,
                      fontFamily: "Poppins",
                      fontWeight: FontWeight.w400,
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      _buildLinkButton(
                        'Privacy Policy',
                        () => _launchUrl('https://example.com/privacy'),
                      ),
                      const SizedBox(width: 16),
                      _buildLinkButton(
                        'Terms',
                        () => _launchUrl('https://example.com/terms'),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // Accuracy & Limitations
            _buildSection(
              title: 'Accuracy & Limitations',
              child: Text(
                'Sensor readings depend on installation, calibration, and environment. Use Terra to assist decisions, not as the sole basis for irrigation or safety-critical actions.',
                style: TextStyle(
                  color: AppColors.primary,
                  fontSize: 14,
                  fontFamily: "Poppins",
                  fontWeight: FontWeight.w400,
                  height: 1.5,
                ),
              ),
            ),

            // Acknowledgements
            _buildSection(
              title: 'Acknowledgements',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Project: "Terra: An IoT-Enabled Monitoring System for Japanese Musk Melon Cultivation."',
                    style: TextStyle(
                      color: AppColors.primary,
                      fontSize: 14,
                      fontFamily: "Poppins",
                      fontWeight: FontWeight.w600,
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Faculty of Information and Communication Technology, Universiti Tunku Abdul Rahman (UTAR).',
                    style: TextStyle(
                      color: AppColors.primary,
                      fontSize: 14,
                      fontFamily: "Poppins",
                      fontWeight: FontWeight.w400,
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Project Dev: Davin Cheong\nSupervisor: Ts. Dr. Saw Seow Hui\nGreenhouse team and collaborators—thank you.',
                    style: TextStyle(
                      color: AppColors.primary,
                      fontSize: 14,
                      fontFamily: "Poppins",
                      fontWeight: FontWeight.w400,
                      height: 1.5,
                    ),
                  ),
                ],
              ),
            ),

            // Version & Build Info
            _buildSection(
              title: 'Version & Build Info',
              child: Column(
                children: [
                  _buildInfoRow('App version', 'v1.0.0 (build 100)'),
                  _buildInfoRow('Firmware', 'ESP32 v1.0.0 (commit abc123)'),
                  _buildInfoRow('Data region', 'Asia-Southeast1'),
                  _buildInfoRow('Uptime / last sync', _getUptimeInfo()),
                ],
              ),
            ),

            // Support & Feedback
            _buildSection(
              title: 'Support & Feedback',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Email: davincheong27@1utar.my',
                    style: TextStyle(
                      color: AppColors.primary,
                      fontSize: 14,
                      fontFamily: "Poppins",
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                  const SizedBox(height: 12),
                  _buildLinkButton(
                    'Send Feedback',
                    () => _launchEmail('davincheong27@1utar.my'),
                  ),
                ],
              ),
            ),

            // Licenses
            _buildSection(
              title: 'Licenses',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'This app uses open-source components. View Open-Source Licenses for details (e.g., Firebase SDKs, fl_chart, etc.).',
                    style: TextStyle(
                      color: AppColors.primary,
                      fontSize: 14,
                      fontFamily: "Poppins",
                      fontWeight: FontWeight.w400,
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 12),
                  _buildLinkButton(
                    'Open-Source Licenses',
                    () => _launchUrl('https://example.com/licenses'),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildSection({required String title, required Widget child}) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 24),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.accent,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              color: AppColors.primary,
              fontSize: 18,
              fontWeight: FontWeight.w700,
              fontFamily: "Poppins",
            ),
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }

  Widget _buildSubsection({required String title, required String content}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
            color: AppColors.brown,
            fontSize: 14,
            fontWeight: FontWeight.w600,
            fontFamily: "Poppins",
          ),
        ),
        const SizedBox(height: 4),
        Text(
          content,
          style: TextStyle(
            color: AppColors.primary,
            fontSize: 14,
            fontFamily: "Poppins",
            fontWeight: FontWeight.w400,
            height: 1.5,
          ),
        ),
      ],
    );
  }

  Widget _buildFeatureItem(String feature) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            margin: const EdgeInsets.only(top: 6, right: 12),
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              color: AppColors.primary,
              shape: BoxShape.circle,
            ),
          ),
          Expanded(
            child: Text(
              feature,
              style: TextStyle(
                color: AppColors.primary,
                fontSize: 14,
                fontFamily: "Poppins",
                fontWeight: FontWeight.w400,
                height: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTechItem({required String category, required String items}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '$category:',
          style: TextStyle(
            color: AppColors.brown,
            fontSize: 14,
            fontWeight: FontWeight.w600,
            fontFamily: "Poppins",
          ),
        ),
        const SizedBox(height: 4),
        Text(
          items,
          style: TextStyle(
            color: AppColors.primary,
            fontSize: 14,
            fontFamily: "Poppins",
            fontWeight: FontWeight.w400,
            height: 1.5,
          ),
        ),
      ],
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              color: AppColors.brown,
              fontSize: 14,
              fontWeight: FontWeight.w500,
              fontFamily: "Poppins",
            ),
          ),
          Text(
            value,
            style: TextStyle(
              color: AppColors.primary,
              fontSize: 14,
              fontWeight: FontWeight.w600,
              fontFamily: "Poppins",
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLinkButton(String text, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: AppColors.primary.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: AppColors.primary.withValues(alpha: 0.3),
            width: 1,
          ),
        ),
        child: Text(
          text,
          style: TextStyle(
            color: AppColors.primary,
            fontSize: 12,
            fontWeight: FontWeight.w600,
            fontFamily: "Poppins",
          ),
        ),
      ),
    );
  }

  String _getUptimeInfo() {
    // This would typically be calculated from actual app start time
    // For now, return a placeholder
    return '2h 15m / 2 min ago';
  }

  Future<void> _launchUrl(String url) async {
    final Uri uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Could not launch $url'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _launchEmail(String email) async {
    final Uri emailUri = Uri(
      scheme: 'mailto',
      path: email,
      query: 'subject=Terra App Feedback',
    );
    if (await canLaunchUrl(emailUri)) {
      await launchUrl(emailUri);
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Could not launch email client'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}
