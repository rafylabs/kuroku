// ignore_for_file: avoid_print
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kuroku/core/database/models/chapter.dart';
import 'package:kuroku/core/database/models/history_entry.dart';
import 'package:kuroku/core/database/models/manga.dart';
import 'package:kuroku/core/theme/app_theme.dart';
import 'package:kuroku/features/history/providers/history_provider.dart';
import 'package:kuroku/features/history/screens/history_screen.dart';

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

class FakeHistoryNotifier extends StateNotifier<AsyncValue<UnifiedHistoryData>> implements HistoryNotifier {
  final List<UnifiedHistoryItem> deletedBatches = [];

  FakeHistoryNotifier(UnifiedHistoryData initialData) : super(AsyncValue.data(initialData));

  @override
  Future<void> loadHistory() async {}

  @override
  Future<void> deleteItem(UnifiedHistoryItem item) async {
    deletedBatches.add(item);
    final cur = state.asData?.value;
    if (cur != null) {
      final updated = cur.allItems.where((it) => it.id != item.id).toList();
      state = AsyncValue.data(UnifiedHistoryData(
        allItems: updated,
        updateCards: cur.updateCards,
        readCount: updated.where((e) => !e.isUpdate).length,
        updateCount: cur.updateCount,
        unseenUpdateCount: cur.unseenUpdateCount,
        favoriteMangaIds: cur.favoriteMangaIds,
      ));
    }
  }

  @override
  Future<void> deleteItems(List<UnifiedHistoryItem> items) async {
    deletedBatches.addAll(items);
    final cur = state.asData?.value;
    if (cur != null) {
      final toRemove = items.map((e) => e.id).toSet();
      final updated = cur.allItems.where((it) => !toRemove.contains(it.id)).toList();
      state = AsyncValue.data(UnifiedHistoryData(
        allItems: updated,
        updateCards: cur.updateCards,
        readCount: updated.where((e) => !e.isUpdate).length,
        updateCount: cur.updateCount,
        unseenUpdateCount: cur.unseenUpdateCount,
        favoriteMangaIds: cur.favoriteMangaIds,
      ));
    }
  }

  @override
  Future<void> clearAll() async {}

  @override
  Future<void> clearReadingHistory() async {}

  @override
  Future<void> clearUpdateNotifications() async {}

  @override
  Future<void> toggleFavorite(String mangaId, String title, String coverUrl, String sourceId) async {}

  @override
  Future<void> markAllUpdatesSeen() async {}
}

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    await _loadSystemFonts();
  });

  UnifiedHistoryData createMockData() {
    final now = DateTime.now();
    const m1 = Manga(
      id: 'm1',
      title: 'Solo Leveling',
      url: 'https://example.com/m1',
      coverUrl: '',
      sourceId: 'shinigami',
    );
    const ch1 = MangaChapter(
      id: 'ch1',
      mangaId: 'm1',
      title: 'Chapter 179',
      url: 'https://example.com/ch1',
      number: 179,
    );
    final read1 = HistoryEntry(
      manga: m1,
      chapter: ch1,
      page: 15,
      updatedAt: now.subtract(const Duration(minutes: 30)),
    );

    const m2 = Manga(
      id: 'm2',
      title: 'Omniscient Reader',
      url: 'https://example.com/m2',
      coverUrl: '',
      sourceId: 'shinigami',
    );
    const ch2 = MangaChapter(
      id: 'ch2',
      mangaId: 'm2',
      title: 'Chapter 210',
      url: 'https://example.com/ch2',
      number: 210,
    );
    final read2 = HistoryEntry(
      manga: m2,
      chapter: ch2,
      page: 8,
      updatedAt: now.subtract(const Duration(hours: 3)),
    );

    const m3 = Manga(
      id: 'm3',
      title: 'The Beginning After The End',
      url: 'https://example.com/m3',
      coverUrl: '',
      sourceId: 'shinigami',
    );
    const ch3 = MangaChapter(
      id: 'ch3',
      mangaId: 'm3',
      title: 'Chapter 175',
      url: 'https://example.com/ch3',
      number: 175,
    );
    final read3 = HistoryEntry(
      manga: m3,
      chapter: ch3,
      page: 2,
      updatedAt: now.subtract(const Duration(days: 1)),
    );

    final items = [
      UnifiedHistoryItem.read(read1),
      UnifiedHistoryItem.read(read2),
      UnifiedHistoryItem.read(read3),
    ];

    return UnifiedHistoryData(
      allItems: items,
      updateCards: const [],
      readCount: 3,
      updateCount: 0,
      unseenUpdateCount: 0,
      favoriteMangaIds: const {},
    );
  }

  testWidgets('Trigger hold activates selection mode, bulk selection, and bulk deletion', (tester) async {
    final GlobalKey boundaryKey = GlobalKey();

    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    final mockData = createMockData();
    final fakeNotifier = FakeHistoryNotifier(mockData);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          historyProvider.overrideWith((ref) => fakeNotifier),
        ],
        child: MaterialApp(
          theme: AppTheme.darkTheme,
          builder: (context, child) => RepaintBoundary(
            key: boundaryKey,
            child: child!,
          ),
          home: const HistoryScreen(),
        ),
      ),
    );

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    // Verify initial items rendered
    expect(find.text('Solo Leveling'), findsOneWidget);
    expect(find.text('Omniscient Reader'), findsOneWidget);
    expect(find.text('The Beginning After The End'), findsOneWidget);

    // Initial state: not in selection mode
    expect(find.text('1 dipilih'), findsNothing);
    expect(find.byIcon(Icons.check_circle), findsNothing);

    // 1. Long press on "Solo Leveling" to enter selection mode
    await tester.longPress(find.text('Solo Leveling'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    // Selection mode is now ACTIVE
    expect(find.text('1 dipilih'), findsOneWidget);
    expect(find.text('Hapus (1)'), findsOneWidget);
    expect(find.byIcon(Icons.check_circle), findsOneWidget);
    expect(find.byIcon(Icons.radio_button_unchecked), findsNWidgets(2));

    // Capture visual screenshot of selection mode
    await tester.runAsync(() async {
      final boundary = boundaryKey.currentContext!.findRenderObject() as RenderRepaintBoundary;
      final image = await boundary.toImage(pixelRatio: 2.0);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      const path = '/opt/data/profiles/dev-one/cache/scratch/history_bulk_selection_preview.png';
      File(path).writeAsBytesSync(byteData!.buffer.asUint8List());
      print('Saved selection preview: $path');
    });

    // 2. Tap second item "Omniscient Reader" to toggle selection
    await tester.tap(find.text('Omniscient Reader'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    expect(find.text('2 dipilih'), findsOneWidget);
    expect(find.text('Hapus (2)'), findsOneWidget);
    expect(find.byIcon(Icons.check_circle), findsNWidgets(2));
    expect(find.byIcon(Icons.radio_button_unchecked), findsOneWidget);

    // 3. Tap Select All button in selection bar
    final selectAllBtn = find.byTooltip('Pilih Semua');
    expect(selectAllBtn, findsOneWidget);
    await tester.tap(selectAllBtn);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    expect(find.text('3 dipilih'), findsOneWidget);
    expect(find.text('Hapus (3)'), findsOneWidget);
    expect(find.byIcon(Icons.check_circle), findsNWidgets(3));

    // 4. Tap Bulk Delete Floating Action Button
    final fabDelete = find.text('Hapus (3)');
    expect(fabDelete, findsOneWidget);
    await tester.tap(fabDelete);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    // Confirmation dialog appears
    expect(find.text('Hapus 3 riwayat bacaan yang dipilih?'), findsOneWidget);
    expect(find.text('Batal'), findsOneWidget);
    expect(find.text('Hapus'), findsOneWidget);

    // Capture dialog preview
    await tester.runAsync(() async {
      final boundary = boundaryKey.currentContext!.findRenderObject() as RenderRepaintBoundary;
      final image = await boundary.toImage(pixelRatio: 2.0);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      const path = '/opt/data/profiles/dev-one/cache/scratch/history_bulk_dialog_preview.png';
      File(path).writeAsBytesSync(byteData!.buffer.asUint8List());
      print('Saved dialog preview: $path');
    });

    // Tap confirm Hapus in dialog
    await tester.tap(find.widgetWithText(ElevatedButton, 'Hapus'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    // Verify batch deletion was executed on notifier
    expect(fakeNotifier.deletedBatches.length, 3);
    // Selection mode exited
    expect(find.text('3 dipilih'), findsNothing);
    expect(find.text('No history or updates yet'), findsOneWidget);
  });
}
