import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/theme/app_theme.dart';
import 'features/catalog/screens/catalog_screen.dart';
import 'features/library/screens/library_screen.dart';
import 'features/history/screens/history_screen.dart';
import 'features/settings/screens/settings_screen.dart';
import 'core/parser/parser_registry.dart';
import 'core/download/download_manager.dart';
import 'core/notifications/notification_service.dart';
import 'core/services/library_update_service.dart';
import 'core/services/app_update_service.dart';
import 'features/catalog/providers/catalog_provider.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Load user custom sources, offline cache, and notification services
  await ParserRegistry.instance.loadCustomSources();
  await DownloadManager.instance.init();
  await NotificationService.instance.init();
  await NotificationService.instance.requestPermissions();
  await LibraryUpdateService.instance.init();

  // Dark edge-to-edge system UI overlay
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      systemNavigationBarColor: Color(0xFF0A0E17),
      systemNavigationBarIconBrightness: Brightness.light,
    ),
  );

  runApp(const KurokuApp());
}

class KurokuApp extends StatelessWidget {
  const KurokuApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ProviderScope(
      child: MaterialApp(
        title: 'Kuroku',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.lightTheme,
        darkTheme: AppTheme.darkTheme,
        themeMode: ThemeMode.dark, // Default to dark cyber theme
        home: const MainNavigationScreen(),
      ),
    );
  }
}

class MainNavigationScreen extends ConsumerStatefulWidget {
  const MainNavigationScreen({super.key});

  @override
  ConsumerState<MainNavigationScreen> createState() => _MainNavigationScreenState();
}

class _MainNavigationScreenState extends ConsumerState<MainNavigationScreen> {
  @override
  void initState() {
    super.initState();
    _checkForAppUpdates();
  }

  Future<void> _checkForAppUpdates() async {
    await Future.delayed(const Duration(seconds: 3));
    if (!mounted) return;
    final update = await AppUpdateService.instance.checkUpdate();
    if (update != null && mounted) {
      AppUpdateService.instance.showUpdateDialog(context, update);
    }
  }

  final List<Widget> _screens = const [
    CatalogScreen(),
    LibraryScreen(),
    HistoryScreen(),
    SettingsScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    final currentIndex = ref.watch(bottomNavIndexProvider);

    return Scaffold(
      body: IndexedStack(
        index: currentIndex,
        children: _screens,
      ),
      bottomNavigationBar: ValueListenableBuilder<int>(
        valueListenable: LibraryUpdateService.instance.unseenUpdateCount,
        builder: (context, unseenCount, _) {
          return BottomNavigationBar(
            currentIndex: currentIndex,
            onTap: (index) {
              ref.read(bottomNavIndexProvider.notifier).state = index;
            },
            items: [
              const BottomNavigationBarItem(
                icon: Icon(Icons.explore_outlined),
                activeIcon: Icon(Icons.explore),
                label: 'Browse',
              ),
              const BottomNavigationBarItem(
                icon: Icon(Icons.collections_bookmark_outlined),
                activeIcon: Icon(Icons.collections_bookmark),
                label: 'Library',
              ),
              BottomNavigationBarItem(
                icon: Badge(
                  isLabelVisible: unseenCount > 0,
                  label: Text('$unseenCount', style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
                  backgroundColor: const Color(0xFFFF4081),
                  child: const Icon(Icons.history_outlined),
                ),
                activeIcon: Badge(
                  isLabelVisible: unseenCount > 0,
                  label: Text('$unseenCount', style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
                  backgroundColor: const Color(0xFFFF4081),
                  child: const Icon(Icons.history),
                ),
                label: 'History',
              ),
              const BottomNavigationBarItem(
                icon: Icon(Icons.settings_outlined),
                activeIcon: Icon(Icons.settings),
                label: 'Settings',
              ),
            ],
          );
        },
      ),
    );
  }
}
