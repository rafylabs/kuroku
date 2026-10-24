// ignore_for_file: avoid_print
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kuroku/core/database/models/chapter.dart';

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
    final iconFile = File('/home/rafylabs/flutter/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf');
    if (iconFile.existsSync()) {
      final iconData = iconFile.readAsBytesSync();
      final iconLoader = FontLoader('MaterialIcons')..addFont(Future.value(ByteData.view(iconData.buffer)));
      await iconLoader.load();
    }
  } catch (_) {}
}

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    await _loadSystemFonts();
  });

  testWidgets('Preview chapter list UI with readable fonts and icons', (tester) async {
    final GlobalKey boundaryKey = GlobalKey();

    tester.view.physicalSize = const Size(800, 1400);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    final rawChapters = [
      const MangaChapter(id: 'c258', mangaId: 'tbate', title: 'Chapter 258.0', number: 258.0, url: '258', lastReadPage: 20, isRead: false),
      const MangaChapter(id: 'c257', mangaId: 'tbate', title: 'Chapter 257.0', number: 257.0, url: '257', isRead: false),
      const MangaChapter(id: 'c256', mangaId: 'tbate', title: 'Chapter 256.0', number: 256.0, url: '256', isRead: false),
      const MangaChapter(id: 'c255', mangaId: 'tbate', title: 'Chapter 255.0', number: 255.0, url: '255', isRead: false),
      const MangaChapter(id: 'c254', mangaId: 'tbate', title: 'Chapter 254.0', number: 254.0, url: '254', isRead: false),
      const MangaChapter(id: 'c253', mangaId: 'tbate', title: 'Chapter 253.0', number: 253.0, url: '253', isRead: false),
      const MangaChapter(id: 'c252', mangaId: 'tbate', title: 'Chapter 252.0', number: 252.0, url: '252', isRead: false),
      const MangaChapter(id: 'c251', mangaId: 'tbate', title: 'Chapter 251.0', number: 251.0, url: '251', isRead: false),
      const MangaChapter(id: 'c250', mangaId: 'tbate', title: 'Chapter 250.0', number: 250.0, url: '250', isRead: false),
      const MangaChapter(id: 'c249', mangaId: 'tbate', title: 'Chapter 249.0', number: 249.0, url: '249', isRead: false),
      const MangaChapter(id: 'c248', mangaId: 'tbate', title: 'Chapter 248.0', number: 248.0, url: '248', isRead: false),
    ];

    double maxRead = -1.0;
    for (final c in rawChapters) {
      if (c.isRead || c.lastReadPage > 0) {
        if (c.number > maxRead) maxRead = c.number;
      }
    }

    final displayedChapters = rawChapters.map((c) {
      if (c.number < maxRead && !c.isRead) {
        return c.copyWith(isRead: true);
      }
      return c;
    }).toList();

    await tester.pumpWidget(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: ThemeData.dark().copyWith(
          textTheme: ThemeData.dark().textTheme.apply(fontFamily: 'Roboto'),
        ),
        home: Scaffold(
          backgroundColor: const Color(0xFF0F1117),
          body: RepaintBoundary(
            key: boundaryKey,
            child: Container(
              color: const Color(0xFF16181F),
              padding: const EdgeInsets.only(top: 16),
              child: Column(
                children: [
                  Center(
                    child: Container(
                      width: 48,
                      height: 5,
                      decoration: BoxDecoration(
                        color: Colors.white38,
                        borderRadius: BorderRadius.circular(3),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Row(
                      children: [
                        const Icon(Icons.arrow_downward_rounded, size: 20, color: Colors.white70),
                        const SizedBox(width: 16),
                        const Icon(Icons.file_download_outlined, size: 20, color: Colors.white70),
                        const SizedBox(width: 16),
                        const Icon(Icons.search_rounded, size: 20, color: Colors.white70),
                        const SizedBox(width: 16),
                        const Icon(Icons.more_vert_rounded, size: 20, color: Colors.white70),
                        const Spacer(),
                        Container(
                          height: 36,
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          decoration: BoxDecoration(
                            color: const Color(0xFFA8C7FA),
                            borderRadius: BorderRadius.circular(18),
                          ),
                          child: const Row(
                            children: [
                              Text(
                                'Continue',
                                style: TextStyle(
                                  fontFamily: 'Roboto',
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.black,
                                ),
                              ),
                              SizedBox(width: 8),
                              Icon(Icons.keyboard_arrow_down_rounded, size: 18, color: Colors.black),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Divider(height: 1, color: Colors.white10),
                  Expanded(
                    child: ListView.separated(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      itemCount: displayedChapters.length,
                      separatorBuilder: (_, _) => const Divider(height: 1, color: Colors.white10),
                      itemBuilder: (context, index) {
                        final ch = displayedChapters[index];
                        final numStr = ch.number.toString().replaceAll(RegExp(r'\.0$'), '');

                        return Material(
                          color: ch.isRead ? const Color(0xFF14161D) : Colors.transparent,
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                            child: Row(
                              children: [
                                Container(
                                  width: 26,
                                  alignment: Alignment.center,
                                  child: ch.isRead
                                      ? const Icon(Icons.check_circle_rounded, size: 20, color: Color(0xFF10B981))
                                      : (ch.lastReadPage > 0
                                          ? const Icon(Icons.play_circle_fill_rounded, size: 20, color: Color(0xFF00F0FF))
                                          : const Icon(Icons.radio_button_unchecked_rounded, size: 18, color: Colors.white24)),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Row(
                                        children: [
                                          Expanded(
                                            child: Text(
                                              'Chapter $numStr',
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: TextStyle(
                                                fontFamily: 'Roboto',
                                                fontSize: 13.5,
                                                fontWeight: ch.isRead ? FontWeight.normal : FontWeight.w600,
                                                color: ch.isRead ? const Color(0xFF6B7280) : Colors.white,
                                              ),
                                            ),
                                          ),
                                          if (ch.lastReadPage > 0 && !ch.isRead) ...[
                                            const SizedBox(width: 6),
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                              decoration: BoxDecoration(
                                                color: const Color(0xFF00F0FF).withValues(alpha: 0.15),
                                                borderRadius: BorderRadius.circular(4),
                                                border: Border.all(color: const Color(0xFF00F0FF).withValues(alpha: 0.3)),
                                              ),
                                              child: Text(
                                                'Hal. ${ch.lastReadPage + 1}',
                                                style: const TextStyle(
                                                  fontFamily: 'Roboto',
                                                  fontSize: 10,
                                                  color: Color(0xFF00F0FF),
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ],
                                      ),
                                      const SizedBox(height: 3),
                                      Text(
                                        '#$numStr • 24 Okt 2026',
                                        style: TextStyle(
                                          fontFamily: 'Roboto',
                                          fontSize: 11.5,
                                          color: ch.isRead ? const Color(0xFF4B5563) : Colors.grey.shade400,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const Icon(Icons.download_for_offline_outlined, size: 20, color: Colors.white30),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    await tester.runAsync(() async {
      final RenderRepaintBoundary boundary =
          boundaryKey.currentContext!.findRenderObject() as RenderRepaintBoundary;
      final ui.Image image = await boundary.toImage(pixelRatio: 2.0);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      final bytes = byteData!.buffer.asUint8List();

      final outDir = Directory('/opt/data/profiles/dev-one/cache/scratch');
      if (!outDir.existsSync()) outDir.createSync(recursive: true);
      final file = File('/opt/data/profiles/dev-one/cache/scratch/chapter_list_preview.png');
      file.writeAsBytesSync(bytes);
      print('SCREENSHOT_SAVED: ${file.path} (${file.lengthSync()} bytes)');
    });
  });
}
