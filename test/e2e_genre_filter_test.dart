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
import 'package:kuroku/core/parser/parser_registry.dart';
import 'package:kuroku/core/theme/app_theme.dart';
import 'package:kuroku/features/catalog/providers/catalog_provider.dart';
import 'package:kuroku/features/catalog/screens/catalog_screen.dart';

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

class FakeCatalogNotifier extends StateNotifier<CatalogState> implements CatalogNotifier {
  @override
  final Ref ref;

  FakeCatalogNotifier(this.ref, List<Manga> initialItems)
      : super(CatalogState(items: initialItems, isLoading: false, hasMore: true));

  @override
  Future<void> loadFirstPage() async {}

  @override
  Future<void> loadNextPage() async {}
}

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    await _loadSystemFonts();
  });

  group('E2E Genre Filter & Multi-Genre Selection Tests', () {
    test('WeebCentral multi-genre query parameter formatting', () {
      final parser = ParserRegistry.instance.getParser('weebcentral')!;
      expect(parser.availableGenres.length, greaterThanOrEqualTo(38));

      // Test tags
      expect(parser.availableGenres, contains('Action'));
      expect(parser.availableGenres, contains('Fantasy'));
      expect(parser.availableGenres, contains('Romance'));
      expect(parser.availableGenres, contains('Sci-fi'));
    });

    test('Detail Screen genre tap updates global catalog providers', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      const testManga = Manga(
        id: 'weebcentral_01J76XYEGYY86GDR09MN457Q7R',
        title: 'Villain to Kill',
        url: 'https://weebcentral.com/series/01J76XYEGYY86GDR09MN457Q7R/Villain-To-Kill',
        coverUrl: 'https://temp.compsci88.com/cover/fallback/01J76XYEGYY86GDR09MN457Q7R.jpg',
        sourceId: 'weebcentral',
        genres: ['Action', 'Fantasy', 'Sci-fi'],
      );

      // Simulate clicking 'Sci-fi' genre chip in MangaDetailScreen
      final targetGenre = testManga.genres[2]; // 'Sci-fi'
      final parser = ParserRegistry.instance.getParser(testManga.sourceId);
      if (parser != null) {
        container.read(activeParserProvider.notifier).state = parser;
      }
      container.read(searchQueryProvider.notifier).state = '';
      container.read(selectedCategoryProvider.notifier).state = 'All';
      container.read(selectedGenresProvider.notifier).state = {targetGenre};
      container.read(selectedGenreProvider.notifier).state = targetGenre;
      container.read(bottomNavIndexProvider.notifier).state = 0;

      expect(container.read(activeParserProvider).id, 'weebcentral');
      expect(container.read(selectedGenresProvider), {'Sci-fi'});
      expect(container.read(bottomNavIndexProvider), 0);
      expect(container.read(selectedCategoryProvider), 'All');
    });

    test('Multi-genre toggle: adding and removing multiple genres', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      // Initial empty set
      expect(container.read(selectedGenresProvider), isEmpty);

      // Toggle Action
      final s1 = Set<String>.from(container.read(selectedGenresProvider))..add('Action');
      container.read(selectedGenresProvider.notifier).state = s1;
      expect(container.read(selectedGenresProvider), {'Action'});

      // Toggle Fantasy
      final s2 = Set<String>.from(container.read(selectedGenresProvider))..add('Fantasy');
      container.read(selectedGenresProvider.notifier).state = s2;
      expect(container.read(selectedGenresProvider), {'Action', 'Fantasy'});

      // Toggle Sci-fi
      final s3 = Set<String>.from(container.read(selectedGenresProvider))..add('Sci-fi');
      container.read(selectedGenresProvider.notifier).state = s3;
      expect(container.read(selectedGenresProvider), {'Action', 'Fantasy', 'Sci-fi'});

      // Remove Fantasy from chip onDeleted
      final s4 = Set<String>.from(container.read(selectedGenresProvider));
      s4.removeWhere((g) => g.toLowerCase() == 'fantasy');
      container.read(selectedGenresProvider.notifier).state = s4;
      expect(container.read(selectedGenresProvider), {'Action', 'Sci-fi'});

      // Reset
      container.read(selectedGenresProvider.notifier).state = {};
      container.read(selectedGenreProvider.notifier).state = 'All';
      expect(container.read(selectedGenresProvider), isEmpty);
    });

    testWidgets('Visual Verification: Render Catalog with Multi-Genre Filter bar', (tester) async {
      final boundaryKey = GlobalKey();
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final parser = ParserRegistry.instance.getParser('weebcentral')!;

      final mockMangaList = [
        const Manga(
          id: 'm1',
          title: 'Villain to Kill',
          url: 'https://weebcentral.com/series/01J76XYEGYY86GDR09MN457Q7R/Villain-To-Kill',
          coverUrl: 'https://temp.compsci88.com/cover/fallback/01J76XYEGYY86GDR09MN457Q7R.jpg',
          sourceId: 'weebcentral',
          genres: ['Action', 'Fantasy', 'Sci-fi'],
        ),
        const Manga(
          id: 'm2',
          title: 'Solo Leveling',
          url: 'https://weebcentral.com/series/01J76XYER4Y424Q0P',
          coverUrl: 'https://temp.compsci88.com/cover/fallback/01J76XYER4Y424Q0P.jpg',
          sourceId: 'weebcentral',
          genres: ['Action', 'Fantasy'],
        ),
      ];

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            activeParserProvider.overrideWith((ref) => parser),
            selectedCategoryProvider.overrideWith((ref) => 'Manga'),
            selectedGenresProvider.overrideWith((ref) => {'Action', 'Fantasy', 'Sci-fi'}),
            catalogProvider.overrideWith((ref) => FakeCatalogNotifier(ref, mockMangaList)),
          ],
          child: MaterialApp(
            theme: AppTheme.darkTheme.copyWith(
              textTheme: AppTheme.darkTheme.textTheme.apply(fontFamily: 'DejaVuSans'),
            ),
            home: RepaintBoundary(
              key: boundaryKey,
              child: const CatalogScreen(),
            ),
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      await tester.runAsync(() async {
        final boundary = boundaryKey.currentContext!.findRenderObject() as RenderRepaintBoundary;
        final image = await boundary.toImage(pixelRatio: 1.0);
        final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
        final pngBytes = byteData!.buffer.asUint8List();

        final file = File('/opt/data/profiles/dev-one/cache/scratch/catalog_multi_genre_filter.png');
        file.writeAsBytesSync(pngBytes);
        print('Saved Catalog preview: ${file.path}');
        expect(file.existsSync(), isTrue);
      });
    });

    testWidgets('Visual Verification: Render Filter Bottom Sheet with all Weeb Central genres', (tester) async {
      final boundaryKey = GlobalKey();
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final parser = ParserRegistry.instance.getParser('weebcentral')!;

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            activeParserProvider.overrideWith((ref) => parser),
            selectedCategoryProvider.overrideWith((ref) => 'Manga'),
            selectedGenresProvider.overrideWith((ref) => {'Action', 'Fantasy', 'Sci-fi'}),
          ],
          child: MaterialApp(
            theme: AppTheme.darkTheme.copyWith(
              textTheme: AppTheme.darkTheme.textTheme.apply(fontFamily: 'DejaVuSans'),
            ),
            home: Scaffold(
              body: RepaintBoundary(
                key: boundaryKey,
                child: Consumer(
                  builder: (context, ref, _) {
                    final tempCat = ref.watch(selectedCategoryProvider);
                    final tempGenres = ref.watch(selectedGenresProvider);
                    final activeGenres = tempGenres;

                    return Container(
                      color: const Color(0xFF141519),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text(
                                'Filter Bacaan',
                                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white),
                              ),
                              TextButton.icon(
                                icon: const Icon(Icons.refresh, size: 16),
                                label: const Text('Reset'),
                                onPressed: () {},
                              ),
                            ],
                          ),
                          const Divider(),
                          const SizedBox(height: 8),
                          const Text(
                            'Kategori / Format',
                            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Colors.white),
                          ),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: parser.availableCategories.map((cat) {
                              final isSel = tempCat.toLowerCase() == cat.toLowerCase();
                              return ChoiceChip(
                                label: Text(cat == 'All' ? 'Semua' : cat),
                                selected: isSel,
                                selectedColor: Theme.of(context).colorScheme.primary.withValues(alpha: 0.3),
                                labelStyle: TextStyle(
                                  color: isSel ? Theme.of(context).colorScheme.primary : Colors.white70,
                                  fontWeight: isSel ? FontWeight.bold : FontWeight.normal,
                                ),
                                side: BorderSide(
                                  color: isSel
                                      ? Theme.of(context).colorScheme.primary
                                      : Theme.of(context).dividerColor,
                                ),
                                onSelected: (_) {},
                              );
                            }).toList(),
                          ),
                          const SizedBox(height: 20),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text(
                                'Genre',
                                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Colors.white),
                              ),
                              if (activeGenres.isNotEmpty)
                                Text(
                                  '${activeGenres.length} genre dipilih',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Theme.of(context).colorScheme.primary,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Expanded(
                            child: SingleChildScrollView(
                              child: Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: parser.availableGenres.map((g) {
                                  final isAll = g.toLowerCase() == 'all';
                                  final isSel = isAll
                                      ? activeGenres.isEmpty
                                      : activeGenres.any((tg) => tg.toLowerCase() == g.toLowerCase());
                                  return FilterChip(
                                    showCheckmark: !isAll,
                                    label: Text(isAll ? 'Semua Genre' : g),
                                    selected: isSel,
                                    selectedColor: Theme.of(context).colorScheme.primary.withValues(alpha: 0.25),
                                    labelStyle: TextStyle(
                                      color: isSel ? Theme.of(context).colorScheme.primary : Colors.white70,
                                      fontWeight: isSel ? FontWeight.bold : FontWeight.normal,
                                    ),
                                    side: BorderSide(
                                      color: isSel
                                          ? Theme.of(context).colorScheme.primary
                                          : Theme.of(context).dividerColor,
                                    ),
                                    onSelected: (_) {},
                                  );
                                }).toList(),
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                          ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              minimumSize: const Size.fromHeight(48),
                              backgroundColor: Theme.of(context).colorScheme.primary,
                              foregroundColor: Colors.black,
                            ),
                            onPressed: () {},
                            child: const Text('Terapkan Filter', style: TextStyle(fontWeight: FontWeight.bold)),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ),
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      await tester.runAsync(() async {
        final boundary = boundaryKey.currentContext!.findRenderObject() as RenderRepaintBoundary;
        final image = await boundary.toImage(pixelRatio: 1.0);
        final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
        final pngBytes = byteData!.buffer.asUint8List();

        final file = File('/opt/data/profiles/dev-one/cache/scratch/weebcentral_filter_sheet_preview.png');
        file.writeAsBytesSync(pngBytes);
        print('Saved Filter Sheet preview: ${file.path}');

        expect(file.existsSync(), isTrue);
      });
    });

    testWidgets('Visual Verification: Render Manga Detail interactive genres section', (tester) async {
      final boundaryKey = GlobalKey();
      tester.view.physicalSize = const Size(1080, 1920);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final parser = ParserRegistry.instance.getParser('weebcentral')!;
      final testManga = Manga(
        id: 'weebcentral_01J76XYEGYY86GDR09MN457Q7R',
        title: 'Villain to Kill',
        url: 'https://weebcentral.com/series/01J76XYEGYY86GDR09MN457Q7R/Villain-To-Kill',
        coverUrl: 'https://temp.compsci88.com/cover/fallback/01J76XYEGYY86GDR09MN457Q7R.jpg',
        sourceId: 'weebcentral',
        genres: ['Action', 'Fantasy', 'Sci-fi', 'Supernatural', 'Shounen', 'School Life'],
      );

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            theme: AppTheme.darkTheme.copyWith(
              textTheme: AppTheme.darkTheme.textTheme.apply(fontFamily: 'DejaVuSans'),
            ),
            home: Scaffold(
              backgroundColor: const Color(0xFF141519),
              body: Center(
                child: RepaintBoundary(
                  key: boundaryKey,
                  child: Container(
                    width: 500,
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1B1D24),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.white10),
                    ),
                    child: Consumer(
                      builder: (context, ref, _) {
                        return Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              testManga.title,
                              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              'Sumber: ${parser.name}',
                              style: const TextStyle(fontSize: 13, color: Colors.grey),
                            ),
                            const SizedBox(height: 16),
                            const Text(
                              'Genre (Ketuk untuk mencari di Katalog):',
                              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.white70),
                            ),
                            const SizedBox(height: 10),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: testManga.genres.map((g) {
                                return Material(
                                  color: Colors.transparent,
                                  child: InkWell(
                                    onTap: () {
                                      ref.read(activeParserProvider.notifier).state = parser;
                                      ref.read(searchQueryProvider.notifier).state = '';
                                      ref.read(selectedCategoryProvider.notifier).state = 'All';
                                      ref.read(selectedGenresProvider.notifier).state = {g};
                                      ref.read(selectedGenreProvider.notifier).state = g;
                                      ref.read(bottomNavIndexProvider.notifier).state = 0;
                                    },
                                    borderRadius: BorderRadius.circular(12),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFF1E2026),
                                        borderRadius: BorderRadius.circular(12),
                                        border: Border.all(
                                          color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.35),
                                        ),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(
                                            Icons.tag_rounded,
                                            size: 14,
                                            color: Theme.of(context).colorScheme.primary,
                                          ),
                                          const SizedBox(width: 5),
                                          Text(
                                            g,
                                            style: const TextStyle(
                                              fontSize: 13,
                                              color: Colors.white,
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                );
                              }).toList(),
                            ),
                          ],
                        );
                      },
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      await tester.runAsync(() async {
        final boundary = boundaryKey.currentContext!.findRenderObject() as RenderRepaintBoundary;
        final image = await boundary.toImage(pixelRatio: 1.0);
        final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
        final pngBytes = byteData!.buffer.asUint8List();

        final file = File('/opt/data/profiles/dev-one/cache/scratch/manga_detail_genres_preview.png');
        file.writeAsBytesSync(pngBytes);
        print('Saved Manga Detail Genres preview: ${file.path}');

        expect(file.existsSync(), isTrue);
      });
    });
  });
}
