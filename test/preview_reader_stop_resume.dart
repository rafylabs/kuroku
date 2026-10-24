// ignore_for_file: avoid_print
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:scrollable_positioned_list/scrollable_positioned_list.dart';

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
  } catch (_) {}
}

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    await _loadSystemFonts();
  });

  testWidgets('Preview test: Stopping in middle of chapter and resuming at exact position', (tester) async {
    final GlobalKey stopKey = GlobalKey();
    final GlobalKey resumeKey = GlobalKey();

    tester.view.physicalSize = const Size(800, 1400);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    final itemPositionsListener = ItemPositionsListener.create();
    final itemScrollController = ItemScrollController();
    final scrollOffsetController = ScrollOffsetController();

    int recordedPage = 0;
    double recordedOffset = 0.0;

    void onPositionsChanged() {
      final positions = itemPositionsListener.itemPositions.value.toList();
      if (positions.isEmpty) return;
      const double focalPoint = 0.35;
      ItemPosition? target;
      for (final pos in positions) {
        if (pos.itemLeadingEdge <= focalPoint && pos.itemTrailingEdge > focalPoint) {
          target = pos;
          break;
        }
      }
      if (target != null) {
        recordedPage = target.index;
        recordedOffset = target.itemLeadingEdge;
      }
    }

    itemPositionsListener.itemPositions.addListener(onPositionsChanged);

    Widget buildPage(int index) {
      return Container(
        height: 1100,
        margin: const EdgeInsets.only(bottom: 4),
        decoration: BoxDecoration(
          color: index.isEven ? const Color(0xFF131722) : const Color(0xFF1E2330),
          border: Border.all(color: Colors.white12),
        ),
        child: Stack(
          children: [
            Positioned(
              top: 30,
              left: 30,
              child: Text(
                'CHAPTER 258 - PAGE $index [PANEL ATAS]',
                style: const TextStyle(
                  fontFamily: 'DejaVuSans',
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF00F0FF),
                ),
              ),
            ),
            Center(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                decoration: BoxDecoration(
                  color: Colors.black54,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.amberAccent, width: 2),
                ),
                child: Text(
                  '★ PAGE $index - PANEL TENGAH (BERHENTI DI SINI) ★',
                  style: const TextStyle(
                    fontFamily: 'DejaVuSans',
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.amberAccent,
                  ),
                ),
              ),
            ),
            Positioned(
              bottom: 30,
              right: 30,
              child: Text(
                'PAGE $index [PANEL BAWAH]',
                style: const TextStyle(
                  fontFamily: 'DejaVuSans',
                  fontSize: 22,
                  color: Colors.greenAccent,
                ),
              ),
            ),
          ],
        ),
      );
    }

    // Step 1: Render reader from 0, scroll to middle of Page 3
    await tester.pumpWidget(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: ThemeData.dark(),
        home: Scaffold(
          body: RepaintBoundary(
            key: stopKey,
            child: ScrollablePositionedList.builder(
              itemPositionsListener: itemPositionsListener,
              itemScrollController: itemScrollController,
              scrollOffsetController: scrollOffsetController,
              itemCount: 15,
              initialScrollIndex: 0,
              initialAlignment: 0.0,
              itemBuilder: (context, index) => buildPage(index),
            ),
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    // Drag down by 3800 pixels (past Page 0, 1, 2, into middle of Page 3)
    await tester.drag(find.byKey(stopKey), const Offset(0, -3800));
    await tester.pumpAndSettle();

    print('AFTER SCROLLING: recordedPage = $recordedPage, recordedOffset = $recordedOffset');

    // Take screenshot of where user stopped
    await tester.runAsync(() async {
      final RenderRepaintBoundary boundary =
          stopKey.currentContext!.findRenderObject() as RenderRepaintBoundary;
      final ui.Image image = await boundary.toImage(pixelRatio: 1.0);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      final bytes = byteData!.buffer.asUint8List();

      final file = File('/opt/data/profiles/dev-one/cache/scratch/stop_middle_preview.png');
      file.writeAsBytesSync(bytes);
      print('Saved STOP preview: ${file.path}');
    });

    // Step 2: Resume with recordedPage and recordedOffset
    final resumeItemPositionsListener = ItemPositionsListener.create();
    final resumeItemScrollController = ItemScrollController();
    final resumeScrollOffsetController = ScrollOffsetController();

    bool didApplyOffset = false;
    void applyOffset(BuildContext ctx) {
      if (didApplyOffset) return;
      didApplyOffset = true;
      if (recordedOffset < -0.02) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          final screenHeight = MediaQuery.of(ctx).size.height;
          final scrollDelta = (-recordedOffset * screenHeight);
          print('Applying sub-page scrollDelta on Resume: $scrollDelta');
          resumeScrollOffsetController.animateScroll(
            offset: scrollDelta,
            duration: const Duration(milliseconds: 200),
          );
        });
      }
    }

    await tester.pumpWidget(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: ThemeData.dark(),
        home: Scaffold(
          body: Builder(
            builder: (ctx) {
              applyOffset(ctx);
              return RepaintBoundary(
                key: resumeKey,
                child: ScrollablePositionedList.builder(
                  itemPositionsListener: resumeItemPositionsListener,
                  itemScrollController: resumeItemScrollController,
                  scrollOffsetController: resumeScrollOffsetController,
                  itemCount: 15,
                  initialScrollIndex: recordedPage,
                  initialAlignment: 0.0,
                  itemBuilder: (context, index) => buildPage(index),
                ),
              );
            },
          ),
        ),
      ),
    );

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pumpAndSettle();

    // Take screenshot of where user resumed
    await tester.runAsync(() async {
      final RenderRepaintBoundary boundary =
          resumeKey.currentContext!.findRenderObject() as RenderRepaintBoundary;
      final ui.Image image = await boundary.toImage(pixelRatio: 1.0);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      final bytes = byteData!.buffer.asUint8List();

      final file = File('/opt/data/profiles/dev-one/cache/scratch/resume_middle_preview.png');
      file.writeAsBytesSync(bytes);
      print('Saved RESUME preview: ${file.path}');
    });
  });
}
