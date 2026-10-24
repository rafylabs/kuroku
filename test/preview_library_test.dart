// ignore_for_file: avoid_print
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kuroku/core/database/models/manga.dart';
import 'package:kuroku/core/theme/app_theme.dart';
import 'package:kuroku/features/library/providers/library_provider.dart';
import 'package:kuroku/features/library/screens/library_screen.dart';

Future<void> _loadSystemFonts() async {
  try {
    final fontFile = File('/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf');
    if (fontFile.existsSync()) {
      final fontData = fontFile.readAsBytesSync();
      final fontLoader = FontLoader('Roboto')..addFont(Future.value(ByteData.view(fontData.buffer)));
      await fontLoader.load();
      final defaultLoader = FontLoader('DejaVuSans')..addFont(Future.value(ByteData.view(fontData.buffer)));
      await defaultLoader.load();
    }
    final fontBold = File('/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf');
    if (fontBold.existsSync()) {
      final data = fontBold.readAsBytesSync();
      final boldLoader = FontLoader('Roboto')..addFont(Future.value(ByteData.view(data.buffer)));
      await boldLoader.load();
    }
    final iconFile = File('/home/rafylabs/flutter/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf');
    if (iconFile.existsSync()) {
      final fontData = iconFile.readAsBytesSync();
      final fontLoader = FontLoader('MaterialIcons')..addFont(Future.value(ByteData.view(fontData.buffer)));
      await fontLoader.load();
    }
  } catch (_) {}
}

class MockLibraryNotifier extends StateNotifier<AsyncValue<List<Manga>>> implements LibraryNotifier {
  @override
  final Ref ref;

  MockLibraryNotifier(this.ref, List<Manga> initialData) : super(AsyncValue.data(initialData));

  @override
  Future<void> loadManga() async {}

  @override
  Future<bool> toggleFavorite(Manga manga) async => true;

  @override
  Future<int> checkUpdates({bool silent = false}) async => 0;
}

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    await _loadSystemFonts();
  });

  testWidgets('Render LibraryScreen into PNG', (tester) async {
    final GlobalKey boundaryKey = GlobalKey();

    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    final mockMangaList = [
      const Manga(
        id: 'm1',
        title: 'Became The Patron Of Villains',
        url: 'm1',
        coverUrl: '',
        sourceId: 'shinigami',
      ),
      const Manga(
        id: 'm2',
        title: 'Failure Frame - I Became the Strongest and Annihilated Everything with Low-Level Spells',
        url: 'm2',
        coverUrl: '',
        sourceId: 'shinigami',
      ),
      const Manga(
        id: 'm3',
        title: 'One Piece',
        url: 'm3',
        coverUrl: '',
        sourceId: 'shinigami',
      ),
      const Manga(
        id: 'm4',
        title: 'Overgeared',
        url: 'm4',
        coverUrl: '',
        sourceId: 'shinigami',
      ),
    ];

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          libraryProvider.overrideWith((ref) => MockLibraryNotifier(ref, mockMangaList)),
          libraryProgressProvider.overrideWith((ref) async => {'m1': 0.45, 'm3': 1.0}),
        ],
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: AppTheme.darkTheme.copyWith(
            appBarTheme: AppTheme.darkTheme.appBarTheme.copyWith(
              titleTextStyle: const TextStyle(
                fontFamily: 'DejaVuSans',
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            textTheme: AppTheme.darkTheme.textTheme.apply(fontFamily: 'DejaVuSans'),
          ),
          home: RepaintBoundary(
            key: boundaryKey,
            child: const LibraryScreen(),
          ),
        ),
      ),
    );

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    await tester.runAsync(() async {
      final RenderRepaintBoundary boundary =
          boundaryKey.currentContext!.findRenderObject() as RenderRepaintBoundary;
      final ui.Image image = await boundary.toImage(pixelRatio: 1.0);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      final bytes = byteData!.buffer.asUint8List();

      final file = File('/opt/data/profiles/dev-one/cache/scratch/library_screen_render.png');
      file.writeAsBytesSync(bytes);
      print('Saved Library preview: ${file.path}');
    });
  });
}
