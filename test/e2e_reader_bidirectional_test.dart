// ignore_for_file: avoid_print
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kuroku/core/database/models/manga.dart';
import 'package:kuroku/core/database/models/chapter.dart';
import 'package:kuroku/core/database/models/manga_page.dart';
import 'package:kuroku/core/parser/manga_parser.dart';
import 'package:kuroku/core/parser/parser_registry.dart';
import 'package:kuroku/core/theme/app_theme.dart';
import 'package:kuroku/features/reader/providers/reader_provider.dart';
import 'package:kuroku/features/reader/screens/manga_reader_screen.dart';

final kTransparentImage = Uint8List.fromList(<int>[
  0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 0x00, 0x00, 0x00, 0x0D, 0x49,
  0x48, 0x44, 0x52, 0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01, 0x08, 0x06,
  0x00, 0x00, 0x00, 0x1F, 0x15, 0xC4, 0x89, 0x00, 0x00, 0x00, 0x0A, 0x49, 0x44,
  0x41, 0x54, 0x78, 0x9C, 0x63, 0x00, 0x01, 0x00, 0x00, 0x05, 0x00, 0x01, 0x0D,
  0x0A, 0x2D, 0xB4, 0x00, 0x00, 0x00, 0x00, 0x49, 0x45, 0x4E, 0x44, 0xAE, 0x42,
  0x60, 0x82,
]);

late String dummyImagePath;

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

class FakeTestParser extends MangaParser {
  @override
  String get id => 'fake_parser';
  @override
  String get name => 'Fake Parser';
  @override
  String get domain => 'fakeparser.com';
  @override
  String get locale => 'en';

  @override
  Future<List<Manga>> getList({
    required int page,
    required SortOrder order,
    String? query,
    String? genre,
    List<String>? genres,
    String? category,
  }) async => [];

  @override
  Future<Manga> getDetails(Manga manga) async => manga;

  @override
  Future<List<MangaChapter>> getChapters(Manga manga) async => [];

  @override
  Future<List<MangaPage>> getPages(MangaChapter chapter) async {
    return [
      MangaPage(index: 0, url: dummyImagePath),
      MangaPage(index: 1, url: dummyImagePath),
      MangaPage(index: 2, url: dummyImagePath),
    ];
  }
}

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    await _loadSystemFonts();

    final dummyFile = File('/opt/data/profiles/dev-one/cache/scratch/dummy_page.png');
    await dummyFile.writeAsBytes(kTransparentImage);
    dummyImagePath = dummyFile.path;

    ParserRegistry.instance.registerParser(FakeTestParser());
  });

  const testManga = Manga(
    id: 'manga_solo_leveling',
    title: 'Solo Leveling',
    url: 'https://fakeparser.com/manga/solo-leveling',
    coverUrl: 'https://fakeparser.com/covers/solo.jpg',
    sourceId: 'fake_parser',
    author: 'Chugong',
    status: MangaStatus.completed,
    rating: 9.9,
    genres: ['Action', 'Fantasy'],
    isFavorite: true,
  );

  const ch1 = MangaChapter(
    id: 'ch_1',
    mangaId: 'manga_solo_leveling',
    title: 'Chapter 1: The D-Rank Hunter',
    number: 1.0,
    url: 'https://fakeparser.com/ch/1',
  );

  const ch2 = MangaChapter(
    id: 'ch_2',
    mangaId: 'manga_solo_leveling',
    title: 'Chapter 2: The Double Dungeon',
    number: 2.0,
    url: 'https://fakeparser.com/ch/2',
  );

  const ch3 = MangaChapter(
    id: 'ch_3',
    mangaId: 'manga_solo_leveling',
    title: 'Chapter 3: The Statues Awaken',
    number: 3.0,
    url: 'https://fakeparser.com/ch/3',
  );

  final allChapters = [ch1, ch2, ch3];

  group('Bidirectional Infinite Scroll Reader Logic Tests', () {
    test('Initial load builds boundary items and page items correctly', () async {
      final args = ReaderArgs(
        manga: testManga,
        chapter: ch2,
        chapters: allChapters,
      );

      final notifier = ReaderNotifier(args);
      await Future.delayed(const Duration(milliseconds: 50));

      final state = notifier.state;
      expect(state.isLoading, isFalse);
      expect(state.currentChapter?.id, 'ch_2');
      expect(state.pages.length, 3);
      expect(state.items.length, 5);

      expect(state.items.first, isA<ReaderBoundaryItem>());
      final topBoundary = state.items.first as ReaderBoundaryItem;
      expect(topBoundary.isTop, isTrue);
      expect(topBoundary.hasMore, isTrue);

      expect(state.items[1], isA<ReaderPageItem>());
      final p0 = state.items[1] as ReaderPageItem;
      expect(p0.pageIndex, 0);
      expect(p0.chapter.id, 'ch_2');

      expect(state.items.last, isA<ReaderBoundaryItem>());
      final bottomBoundary = state.items.last as ReaderBoundaryItem;
      expect(bottomBoundary.isTop, isFalse);
      expect(bottomBoundary.hasMore, isTrue);
    });

    test('loadNextChapter appends ChapterTransition and next chapter pages', () async {
      final args = ReaderArgs(
        manga: testManga,
        chapter: ch1,
        chapters: allChapters,
      );

      final notifier = ReaderNotifier(args);
      await Future.delayed(const Duration(milliseconds: 50));

      expect(notifier.state.items.length, 5);

      await notifier.loadNextChapter();
      final state = notifier.state;

      expect(state.items.length, 9);

      final transitionItem = state.items[4];
      expect(transitionItem, isA<ReaderChapterTransitionItem>());
      final trans = transitionItem as ReaderChapterTransitionItem;
      expect(trans.fromChapter.id, 'ch_1');
      expect(trans.toChapter.id, 'ch_2');

      final ch2Page = state.items[5] as ReaderPageItem;
      expect(ch2Page.chapter.id, 'ch_2');
      expect(ch2Page.pageIndex, 0);

      final newBottom = state.items.last as ReaderBoundaryItem;
      expect(newBottom.isTop, isFalse);
      expect(newBottom.hasMore, isTrue);
    });

    test('loadPreviousChapter prepends pages and calculates prependedCount', () async {
      final args = ReaderArgs(
        manga: testManga,
        chapter: ch2,
        chapters: allChapters,
      );

      final notifier = ReaderNotifier(args);
      await Future.delayed(const Duration(milliseconds: 50));

      expect(notifier.state.items.length, 5);

      await notifier.loadPreviousChapter();
      final state = notifier.state;

      expect(state.items.length, 9);
      expect(state.prependedCount, 4);

      final topBoundary = state.items.first as ReaderBoundaryItem;
      expect(topBoundary.isTop, isTrue);
      expect(topBoundary.hasMore, isFalse);

      final ch1Page = state.items[1] as ReaderPageItem;
      expect(ch1Page.chapter.id, 'ch_1');
      expect(ch1Page.pageIndex, 0);

      final trans = state.items[4] as ReaderChapterTransitionItem;
      expect(trans.fromChapter.id, 'ch_1');
      expect(trans.toChapter.id, 'ch_2');
    });

    test('onPositionChanged updates active chapter and page dynamically', () async {
      final args = ReaderArgs(
        manga: testManga,
        chapter: ch1,
        chapters: allChapters,
      );

      final notifier = ReaderNotifier(args);
      await Future.delayed(const Duration(milliseconds: 50));
      await notifier.loadNextChapter();

      notifier.onPositionChanged(2, 0.0);
      expect(notifier.state.currentChapter?.id, 'ch_1');
      expect(notifier.state.currentPage, 1);

      notifier.onPositionChanged(6, -0.2);
      expect(notifier.state.currentChapter?.id, 'ch_2');
      expect(notifier.state.currentPage, 1);
      expect(notifier.state.currentOffset, -0.2);
    });
  });

  group('Visual & Widget E2E Verification Tests', () {
    testWidgets('Render MangaReaderScreen with HUD and chapter controls', (tester) async {
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final boundaryKey = GlobalKey();
      final args = ReaderArgs(
        manga: testManga,
        chapter: ch2,
        chapters: allChapters,
      );

      await tester.runAsync(() async {
        await tester.pumpWidget(
          ProviderScope(
            child: MaterialApp(
              theme: AppTheme.darkTheme,
              home: RepaintBoundary(
                key: boundaryKey,
                child: MangaReaderScreen(args: args),
              ),
            ),
          ),
        );

        // Wait for async reader provider to load
        for (int i = 0; i < 5; i++) {
          await Future.delayed(const Duration(milliseconds: 100));
          await tester.pump();
        }

        // Verify Top HUD
        expect(find.text('Solo Leveling'), findsOneWidget);
        expect(find.text('Chapter 2: The Double Dungeon'), findsWidgets);

        // Verify Bottom HUD Controls
        expect(find.text('Prev Ch'), findsOneWidget);
        expect(find.text('Next Ch'), findsOneWidget);
        expect(find.textContaining('Halaman 1 / 3'), findsOneWidget);
        expect(find.text('Webtoon (Continuous)'), findsOneWidget);

        // Capture Skia Raster Screenshot of Reader with HUD
        final renderObject = boundaryKey.currentContext!.findRenderObject() as RenderRepaintBoundary;
        final image = await renderObject.toImage(pixelRatio: 2.0);
        final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
        final bytes = byteData!.buffer.asUint8List();

        final outputFile = File('/opt/data/profiles/dev-one/cache/scratch/reader_hud_controls_preview.png');
        await outputFile.writeAsBytes(bytes);
        print('Saved Reader HUD preview: ${outputFile.path}');
      });
    });

    testWidgets('Render Chapter Transition Card and Boundary in Webtoon List', (tester) async {
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final boundaryKey = GlobalKey();
      // Set initialPage = 2 (last page of chapter 1) so transition card is in view
      final args = ReaderArgs(
        manga: testManga,
        chapter: ch1,
        initialPage: 2,
        chapters: allChapters,
      );

      await tester.runAsync(() async {
        final container = ProviderContainer();
        final notifier = container.read(readerProvider(args).notifier);

        await Future.delayed(const Duration(milliseconds: 100));
        await notifier.loadNextChapter();

        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: MaterialApp(
              theme: AppTheme.darkTheme,
              home: RepaintBoundary(
                key: boundaryKey,
                child: MangaReaderScreen(args: args),
              ),
            ),
          ),
        );

        for (int i = 0; i < 5; i++) {
          await Future.delayed(const Duration(milliseconds: 100));
          await tester.pump();
        }

        // Verify Transition Card widgets exist
        expect(find.text('Akhir Chapter 1: The D-Rank Hunter'), findsOneWidget);
        expect(find.text('Chapter 2: The Double Dungeon'), findsWidgets);

        // Capture Skia Raster Screenshot
        final renderObject = boundaryKey.currentContext!.findRenderObject() as RenderRepaintBoundary;
        final image = await renderObject.toImage(pixelRatio: 2.0);
        final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
        final bytes = byteData!.buffer.asUint8List();

        final outputFile = File('/opt/data/profiles/dev-one/cache/scratch/reader_chapter_transition_preview.png');
        await outputFile.writeAsBytes(bytes);
        print('Saved Chapter Transition preview: ${outputFile.path}');
      });
    });

    testWidgets('Render Boundary Indicator in Webtoon List', (tester) async {
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final boundaryKey = GlobalKey();
      // Ch 1, initialPage = 2 to see the bottom boundary
      final args = ReaderArgs(
        manga: testManga,
        chapter: ch1,
        initialPage: 2,
        chapters: allChapters,
      );

      await tester.runAsync(() async {
        await tester.pumpWidget(
          ProviderScope(
            child: MaterialApp(
              theme: AppTheme.darkTheme,
              home: RepaintBoundary(
                key: boundaryKey,
                child: MangaReaderScreen(args: args),
              ),
            ),
          ),
        );

        for (int i = 0; i < 5; i++) {
          await Future.delayed(const Duration(milliseconds: 100));
          await tester.pump();
        }

        // Tap screen center to hide HUD and focus on content & boundary
        await tester.tap(find.byType(GestureDetector).first);
        await tester.pump(const Duration(milliseconds: 250));

        final renderObject = boundaryKey.currentContext!.findRenderObject() as RenderRepaintBoundary;
        final image = await renderObject.toImage(pixelRatio: 2.0);
        final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
        final bytes = byteData!.buffer.asUint8List();

        final outputFile = File('/opt/data/profiles/dev-one/cache/scratch/reader_boundary_preview.png');
        await outputFile.writeAsBytes(bytes);
        print('Saved Reader Boundary preview: ${outputFile.path}');
      });
    });
  });
}
