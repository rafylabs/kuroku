// ignore_for_file: avoid_print
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kuroku/core/theme/app_theme.dart';
import 'package:kuroku/core/parser/dynamic_manga_parser.dart';
import 'package:kuroku/core/parser/parser_registry.dart';
import 'package:kuroku/core/parser/parser_importer.dart';

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

  testWidgets('Visual Verification: Render Source Picker with Import button and Custom badge', (tester) async {
    tester.view.physicalSize = const Size(1080, 2000);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    final repaintBoundaryKey = GlobalKey();

    const customConfig = CustomSourceConfig(
      id: 'custom_flame_scans',
      name: 'Flame Scans (Imported)',
      domain: 'flamecomics.xyz',
      locale: 'en',
      type: 'html',
    );
    final customParser = DynamicMangaParser(customConfig);
    final parsers = [...ParserRegistry.instance.allParsers, customParser];
    final activeParser = parsers.first;

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
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Pilih Sumber Komik',
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
                        ),
                        Row(
                          children: [
                            IconButton(
                              icon: const Icon(Icons.file_download_outlined, color: Color(0xFF00F0FF)),
                              tooltip: 'Import Parser',
                              onPressed: () {},
                            ),
                            IconButton(
                              icon: const Icon(Icons.add_circle_outline, color: Color(0xFF00F0FF)),
                              tooltip: 'Add Custom Source',
                              onPressed: () {},
                            ),
                          ],
                        ),
                      ],
                    ),
                    const Divider(color: Colors.white24),
                    const SizedBox(height: 8),
                    ...parsers.map((parser) {
                      final isSelected = parser.id == activeParser.id;
                      final isCustom = parser.id.startsWith('custom_');

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
                          title: Row(
                            children: [
                              Flexible(
                                child: Text(
                                  parser.name,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                    color: Colors.white,
                                    fontSize: 14,
                                  ),
                                ),
                              ),
                              if (isCustom) ...[
                                const SizedBox(width: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: Colors.amber.withValues(alpha: 0.2),
                                    borderRadius: BorderRadius.circular(4),
                                    border: Border.all(color: Colors.amber.shade700, width: 0.5),
                                  ),
                                  child: const Text('CUSTOM', style: TextStyle(fontSize: 9, color: Colors.amber, fontWeight: FontWeight.bold)),
                                ),
                              ],
                            ],
                          ),
                          subtitle: Text(parser.domain, style: const TextStyle(fontSize: 11, color: Colors.white54)),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (isSelected) ...[
                                const Icon(Icons.check_circle, color: Color(0xFF00F0FF), size: 20),
                                const SizedBox(width: 4),
                              ],
                              if (isCustom)
                                const IconButton(
                                  icon: Icon(Icons.more_vert, size: 20, color: Colors.white70),
                                  tooltip: 'Opsi Parser',
                                  onPressed: null,
                                )
                              else
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
                    const SizedBox(height: 12),
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        minimumSize: const Size.fromHeight(44),
                        backgroundColor: const Color(0xFF00F0FF),
                        foregroundColor: Colors.black,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      icon: const Icon(Icons.file_download_outlined, color: Colors.black),
                      label: const Text('Import Parser (.json / URL)', style: TextStyle(fontWeight: FontWeight.bold)),
                      onPressed: () {},
                    ),
                    const SizedBox(height: 8),
                    OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size.fromHeight(40),
                        side: BorderSide(color: Colors.grey.shade700),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      icon: const Icon(Icons.add, size: 18, color: Colors.grey),
                      label: const Text('Tambah Manual Website (Template)', style: TextStyle(color: Colors.grey)),
                      onPressed: () {},
                    ),
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

  testWidgets('Visual Verification: Render Import Parser Dialog with live spec preview', (tester) async {
    tester.view.physicalSize = const Size(1080, 2000);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    final repaintBoundaryKey = GlobalKey();
    final parsedConfig = ParserImporter.fromJsonString(ParserImporter.sampleHtmlTemplate);

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
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: const Color(0xFF1B1926),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.white12),
                  boxShadow: const [
                    BoxShadow(color: Colors.black54, blurRadius: 20, spreadRadius: 4),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Import Manga Parser', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            decoration: BoxDecoration(
                              color: const Color(0xFF00F0FF).withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: const Color(0xFF00F0FF)),
                            ),
                            child: const Center(
                              child: Text('Paste JSON', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF00F0FF))),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.05),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.white24),
                            ),
                            child: const Center(
                              child: Text('Import URL', style: TextStyle(fontSize: 12, color: Colors.white70)),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Parser JSON Spec', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.white70)),
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: const Color(0xFF00F0FF).withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: const Text('Paste Clipboard', style: TextStyle(fontSize: 10, color: Color(0xFF00F0FF), fontWeight: FontWeight.bold)),
                            ),
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: Colors.white10,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: const Text('Template ▾', style: TextStyle(fontSize: 10, color: Colors.white70)),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Container(
                      width: double.infinity,
                      height: 140,
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.black38,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.white24),
                      ),
                      child: Text(
                        ParserImporter.sampleHtmlTemplate,
                        style: const TextStyle(fontSize: 10, fontFamily: 'monospace', color: Colors.white70),
                        maxLines: 9,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(height: 12),
                    // Validation success card
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.green.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.green.shade600),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.check_circle, color: Colors.green, size: 16),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  parsedConfig.name,
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.white),
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: Colors.green.shade800,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  parsedConfig.type.toUpperCase(),
                                  style: const TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Colors.white),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Domain: ${parsedConfig.domain} • Bahasa: ${parsedConfig.locale.toUpperCase()} • Engine: HTML Selector',
                            style: const TextStyle(fontSize: 11, color: Colors.white70),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton(
                          onPressed: () {},
                          child: const Text('Batal', style: TextStyle(color: Colors.grey)),
                        ),
                        const SizedBox(width: 8),
                        ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF00F0FF),
                            foregroundColor: Colors.black,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                          icon: const Icon(Icons.download_done, size: 16),
                          label: const Text('Pasang Parser', style: TextStyle(fontWeight: FontWeight.bold)),
                          onPressed: () {},
                        ),
                      ],
                    ),
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
          const path = '/opt/data/profiles/dev-one/cache/scratch/import_parser_dialog_preview.png';
          File(path).writeAsBytesSync(byteData.buffer.asUint8List());
          print('Saved Import Dialog preview: $path');
        }
      }
    });
  });
}
