import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:extended_image/extended_image.dart';
import '../../../core/notifications/notification_service.dart';
import '../../../core/services/library_update_service.dart';
import '../../reader/providers/reader_provider.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final readerMode = ref.watch(readerModeProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings', style: TextStyle(fontWeight: FontWeight.w900)),
      ),
      body: ListView(
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Text(
              'READER SETTINGS',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.0,
                color: Color(0xFF00F0FF),
              ),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.chrome_reader_mode_outlined),
            title: const Text('Default Reading Mode'),
            subtitle: Text(
              readerMode == ReaderMode.webtoon
                  ? 'Webtoon (Continuous Vertical)'
                  : readerMode == ReaderMode.pagedRtl
                      ? 'Manga (Right to Left)'
                      : 'Comic (Left to Right)',
            ),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              showDialog(
                context: context,
                builder: (ctx) => SimpleDialog(
                  title: const Text('Select Default Mode'),
                  children: [
                    SimpleDialogOption(
                      onPressed: () {
                        ref.read(readerModeProvider.notifier).state = ReaderMode.webtoon;
                        Navigator.pop(ctx);
                      },
                      child: const Text('Webtoon (Vertical Continuous)'),
                    ),
                    SimpleDialogOption(
                      onPressed: () {
                        ref.read(readerModeProvider.notifier).state = ReaderMode.pagedRtl;
                        Navigator.pop(ctx);
                      },
                      child: const Text('Manga RTL (Right to Left)'),
                    ),
                    SimpleDialogOption(
                      onPressed: () {
                        ref.read(readerModeProvider.notifier).state = ReaderMode.pagedLtr;
                        Navigator.pop(ctx);
                      },
                      child: const Text('Comic LTR (Left to Right)'),
                    ),
                  ],
                ),
              );
            },
          ),
          const Divider(),

          const Padding(
            padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Text(
              'IOS SIDELOADING & INSTALLATION',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.0,
                color: Color(0xFF00F0FF),
              ),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.apple),
            title: const Text('Install on iOS (Non-AppStore)'),
            subtitle: const Text('AltStore, SideStore, TrollStore, Sideloadly'),
            trailing: const Icon(Icons.info_outline),
            onTap: () {
              showModalBottomSheet(
                context: context,
                isScrollControlled: true,
                shape: const RoundedRectangleBorder(
                  borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                ),
                builder: (ctx) => DraggableScrollableSheet(
                  initialChildSize: 0.65,
                  maxChildSize: 0.9,
                  minChildSize: 0.4,
                  expand: false,
                  builder: (_, scroll) => ListView(
                    controller: scroll,
                    padding: const EdgeInsets.all(20),
                    children: [
                      const Text(
                        'iOS Sideloading Guide',
                        style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Kuroku Flutter is configured with standard zero-restricted entitlements and can be installed without the Apple App Store:',
                        style: TextStyle(fontSize: 13, color: Colors.grey),
                      ),
                      const SizedBox(height: 16),
                      _buildStep(
                        '1. AltStore / SideStore',
                        'Download the Kuroku.ipa file from GitHub Releases, open AltStore or SideStore on your iPhone/iPad, click "+" and select Kuroku.ipa. Sign with your free Apple ID.',
                      ),
                      _buildStep(
                        '2. TrollStore (iOS 14.0 - 17.0)',
                        'Open TrollStore, tap "+" and install Kuroku.ipa directly. No 7-day expiration or revocations.',
                      ),
                      _buildStep(
                        '3. Sideloadly / Scarlet',
                        'Drag Kuroku.ipa into Sideloadly on Mac or PC, enter your Apple ID, and install via USB or Wi-Fi.',
                      ),
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFF00F0FF).withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: const Color(0xFF00F0FF).withValues(alpha: 0.3)),
                        ),
                        child: const Text(
                          'Note: On iOS 16+, make sure to enable Developer Mode in Settings > Privacy & Security > Developer Mode.',
                          style: TextStyle(fontSize: 12, color: Color(0xFF00F0FF)),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
          ListTile(
            leading: const Icon(Icons.badge_outlined),
            title: const Text('Bundle Identifier'),
            subtitle: const Text('com.rafylabs.kuroku'),
          ),
          const Divider(),

          const Padding(
            padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Text(
              'NOTIFICATIONS & UPDATES',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.0,
                color: Color(0xFF00F0FF),
              ),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.notifications_active_outlined),
            title: const Text('Check Chapter Updates'),
            subtitle: const Text('Scan favorited manga for newly released chapters'),
            trailing: const Icon(Icons.sync_rounded),
            onTap: () async {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Checking for new chapters...')),
              );
              final count = await LibraryUpdateService.instance.checkForUpdates(silent: false);
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(count > 0 ? 'Found $count new chapters!' : 'No new chapters found')),
                );
              }
            },
          ),
          ListTile(
            leading: const Icon(Icons.notification_add_outlined),
            title: const Text('Notification Permissions'),
            subtitle: const Text('Ensure system notifications are enabled'),
            onTap: () async {
              await NotificationService.instance.requestPermissions();
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Notification permission requested')),
                );
              }
            },
          ),
          const Divider(),

          const Padding(
            padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Text(
              'STORAGE & CACHE',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.0,
                color: Color(0xFF00F0FF),
              ),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.cleaning_services_outlined),
            title: const Text('Clear Image Cache'),
            subtitle: const Text('Free up memory and disk image cache'),
            onTap: () {
              clearMemoryImageCache();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Image cache cleared')),
              );
            },
          ),
          const Divider(),

          const Padding(
            padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Text(
              'ABOUT',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.0,
                color: Color(0xFF00F0FF),
              ),
            ),
          ),
          const ListTile(
            leading: Icon(Icons.info_outline),
            title: Text('Kuroku Cross-Platform'),
            subtitle: Text('Version 1.3.0 (Reverse Engineered Flutter Edition)'),
          ),
        ],
      ),
    );
  }

  Widget _buildStep(String title, String desc) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
          const SizedBox(height: 4),
          Text(desc, style: const TextStyle(fontSize: 12, height: 1.4, color: Colors.grey)),
        ],
      ),
    );
  }
}
