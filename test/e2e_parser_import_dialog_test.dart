// ignore_for_file: avoid_print
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kuroku/core/theme/app_theme.dart';
import 'package:kuroku/core/parser/parser_registry.dart';

Future<void> _loadTestFonts() async {
  try {
    final fontFile = File('/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf');
    if (fontFile.existsSync()) {
      final fontData = fontFile.readAsBytesSync();
      final fontLoader = FontLoader('Roboto')..addFont(Future.value(ByteData.view(fontData.buffer)));
      await fontLoader.load();
      final fontLoaderDj = FontLoader('DejaVuSans')..addFont(Future.value(ByteData.view(fontData.buffer)));
      await fontLoaderDj.load();
    }
    final iconFile = File('/home/rafylabs/flutter/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf');
    if (iconFile.existsSync()) {
      final fontData = iconFile.readAsBytesSync();
      final fontLoader = FontLoader('MaterialIcons')..addFont(Future.value(ByteData.view(fontData.buffer)));
      await fontLoader.load();
    }
  } catch (_) {}
}

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    await _loadTestFonts();
  });

  testWidgets('Visual Verification: Render Source Picker with Default Built-in Sources', (tester) async {
    tester.view.physicalSize = const Size(1080, 2000);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    final repaintBoundaryKey = GlobalKey();
    final parsers = ParserRegistry.instance.allParsers;
    final activeParser = ParserRegistry.instance.defaultParser;

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.darkTheme.copyWith(
          textTheme: AppTheme.darkTheme.textTheme.apply(fontFamily: 'DejaVuSans'),
        ),
        home: Scaffold(
          backgroundColor: const Color(0xFF0F0E17),
          body: Center(
            child: RepaintBoundary(
              key: repaintBoundaryKey,
              child: Container(
                width: 480,
                padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
                decoration: BoxDecoration(
                  color: const Color(0xFF1B1926),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.white12),
                  boxShadow: const [
                    BoxShadow(color: Colors.black54, blurRadius: 20, spreadRadius: 4),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      child: Text(
                        'Pilih Sumber Komik',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
                      ),
                    ),
                    const Divider(color: Colors.white24),
                    const SizedBox(height: 8),
                    ...parsers.map((parser) {
                      final isSelected = parser.id == activeParser.id;

                      return Container(
                        margin: const EdgeInsets.only(bottom: 6),
                        decoration: BoxDecoration(
                          color: isSelected ? const Color(0xFF00F0FF).withValues(alpha: 0.1) : Colors.transparent,
                          borderRadius: BorderRadius.circular(10),
                          border: isSelected ? Border.all(color: const Color(0xFF00F0FF).withValues(alpha: 0.4)) : null,
                        ),
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundColor: isSelected
                                ? const Color(0xFF00F0FF).withValues(alpha: 0.2)
                                : Colors.white10,
                            child: Text(
                              parser.locale.toUpperCase(),
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: isSelected ? const Color(0xFF00F0FF) : Colors.white70,
                              ),
                            ),
                          ),
                          title: Text(
                            parser.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                              color: Colors.white,
                              fontSize: 14,
                            ),
                          ),
                          subtitle: Text(parser.domain, style: const TextStyle(fontSize: 11, color: Colors.white54)),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (isSelected) ...[
                                const Icon(Icons.check_circle, color: Color(0xFF00F0FF), size: 18),
                                const SizedBox(width: 4),
                              ],
                              IconButton(
                                icon: const Icon(Icons.edit_outlined, size: 18, color: Colors.white70),
                                tooltip: 'Edit Domain',
                                onPressed: () {},
                              ),
                            ],
                          ),
                        ),
                      );
                    }),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.pump();

    // Capture screenshot
    await tester.runAsync(() async {
      final boundary = repaintBoundaryKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
      if (boundary != null) {
        final image = await boundary.toImage(pixelRatio: 1.0);
        final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
        if (byteData != null) {
          const path = '/opt/data/profiles/dev-one/cache/scratch/source_picker_with_import.png';
          File(path).writeAsBytesSync(byteData.buffer.asUint8List());
          print('Saved Source Picker preview: $path');
        }
      }
    });
  });
}
