import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:dio/dio.dart';
import '../database/app_database.dart';
import '../database/models/manga.dart';
import '../database/models/chapter.dart';
import '../database/models/manga_page.dart';
import '../parser/parser_registry.dart';
import '../network/http_client.dart';

class DownloadManager {
  static final DownloadManager instance = DownloadManager._internal();
  DownloadManager._internal();

  /// Observable download progress: chapterId -> progress (0.0 to 1.0)
  final ValueNotifier<Map<String, double>> activeDownloads = ValueNotifier({});

  /// Cached set of downloaded chapter IDs for instant lookup in UI
  final ValueNotifier<Set<String>> downloadedChapterIds = ValueNotifier({});

  bool _initialized = false;

  Future<void> init() async {
    if (_initialized) return;
    _initialized = true;
    await refreshDownloaded();
  }

  Future<void> refreshDownloaded() async {
    final db = await AppDatabase.instance.database;
    final res = await db.query('downloads', columns: ['chapter_id']);
    downloadedChapterIds.value = res.map((r) => r['chapter_id'] as String).toSet();
  }

  bool isDownloaded(String chapterId) {
    return downloadedChapterIds.value.contains(chapterId);
  }

  double? getProgress(String chapterId) {
    return activeDownloads.value[chapterId];
  }

  Future<String> _getChapterDirPath(String mangaId, String chapterId) async {
    final docsDir = await getApplicationDocumentsDirectory();
    final safeMangaId = mangaId.replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '_');
    final safeChapterId = chapterId.replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '_');
    return p.join(docsDir.path, 'downloads', safeMangaId, safeChapterId);
  }

  Future<File?> getLocalCoverFile(String mangaId) async {
    final docsDir = await getApplicationDocumentsDirectory();
    final safeMangaId = mangaId.replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '_');
    final file = File(p.join(docsDir.path, 'downloads', safeMangaId, 'cover.jpg'));
    if (await file.exists() && await file.length() > 0) {
      return file;
    }
    return null;
  }

  Future<List<MangaPage>?> getDownloadedPages(MangaChapter chapter) async {
    String? targetDirPath;

    // 1. Try finding by saved database dir_path first
    try {
      final db = await AppDatabase.instance.database;
      final res = await db.query(
        'downloads',
        columns: ['dir_path'],
        where: 'chapter_id = ?',
        whereArgs: [chapter.id],
        limit: 1,
      );
      if (res.isNotEmpty && res.first['dir_path'] != null) {
        final path = res.first['dir_path'] as String;
        if (await Directory(path).exists()) {
          targetDirPath = path;
        }
      }
    } catch (_) {}

    // 2. Fall back to canonical documents directory path
    if (targetDirPath == null) {
      final computed = await _getChapterDirPath(chapter.mangaId, chapter.id);
      if (await Directory(computed).exists()) {
        targetDirPath = computed;
      }
    }

    if (targetDirPath == null) return null;

    final dir = Directory(targetDirPath);
    final files = dir.listSync().whereType<File>().toList();
    if (files.isEmpty) return null;

    // Filter image files only
    final imageFiles = files.where((f) {
      final name = p.basename(f.path).toLowerCase();
      return name.endsWith('.jpg') ||
          name.endsWith('.jpeg') ||
          name.endsWith('.png') ||
          name.endsWith('.webp') ||
          name.endsWith('.avif');
    }).toList();

    if (imageFiles.isEmpty) return null;

    // Natural numerical sorting: 0.jpg, 1.jpg, 2.jpg, 10.jpg
    imageFiles.sort((a, b) {
      final aName = p.basenameWithoutExtension(a.path);
      final bName = p.basenameWithoutExtension(b.path);
      final aNum = int.tryParse(RegExp(r'^\d+').firstMatch(aName)?.group(0) ?? '');
      final bNum = int.tryParse(RegExp(r'^\d+').firstMatch(bName)?.group(0) ?? '');
      if (aNum != null && bNum != null) {
        return aNum.compareTo(bNum);
      }
      return aName.compareTo(bName);
    });

    return imageFiles.asMap().entries.map((entry) {
      return MangaPage(
        index: entry.key,
        url: entry.value.path,
      );
    }).toList();
  }

  Future<void> downloadChapter({
    required Manga manga,
    required MangaChapter chapter,
    Function(int current, int total)? onProgress,
  }) async {
    final chapterId = chapter.id;
    if (activeDownloads.value.containsKey(chapterId)) return;

    final updated = Map<String, double>.from(activeDownloads.value);
    updated[chapterId] = 0.01;
    activeDownloads.value = updated;

    try {
      final parser = ParserRegistry.instance.getParser(manga.sourceId) ??
          ParserRegistry.instance.defaultParser;

      final pages = await parser.getPages(chapter);
      if (pages.isEmpty) {
        throw Exception('No pages found for chapter');
      }

      final dirPath = await _getChapterDirPath(manga.id, chapter.id);
      final dir = Directory(dirPath);
      if (!await dir.exists()) {
        await dir.create(recursive: true);
      }

      // Cache manga cover locally for offline display in library
      final mangaDir = dir.parent;
      final coverFile = File(p.join(mangaDir.path, 'cover.jpg'));
      if (!await coverFile.exists() && manga.coverUrl.isNotEmpty && manga.coverUrl.startsWith('http')) {
        try {
          await KurokuHttpClient.instance.dio.download(
            manga.coverUrl,
            coverFile.path,
            options: Options(headers: parser.headers),
          );
        } catch (_) {}
      }

      // Download each page image sequentially
      for (int i = 0; i < pages.length; i++) {
        final page = pages[i];
        final ext = page.url.contains('.webp')
            ? 'webp'
            : page.url.contains('.png')
                ? 'png'
                : 'jpg';
        final filePath = p.join(dirPath, '$i.$ext');
        final file = File(filePath);

        if (!await file.exists() || await file.length() == 0) {
          await KurokuHttpClient.instance.dio.download(
            page.url,
            filePath,
            options: Options(
              headers: page.headers ?? parser.headers,
              responseType: ResponseType.bytes,
            ),
          );
        }

        final progress = (i + 1) / pages.length;
        final currProgressMap = Map<String, double>.from(activeDownloads.value);
        currProgressMap[chapterId] = progress;
        activeDownloads.value = currProgressMap;
        onProgress?.call(i + 1, pages.length);
      }

      await AppDatabase.instance.upsertManga(manga);
      await AppDatabase.instance.upsertChapters([chapter]);
      await AppDatabase.instance.saveDownload(
        chapterId: chapterId,
        mangaId: manga.id,
        dirPath: dirPath,
        pageCount: pages.length,
      );

      final newSet = Set<String>.from(downloadedChapterIds.value);
      newSet.add(chapterId);
      downloadedChapterIds.value = newSet;
    } finally {
      final finalMap = Map<String, double>.from(activeDownloads.value);
      finalMap.remove(chapterId);
      activeDownloads.value = finalMap;
    }
  }

  Future<void> deleteDownload(MangaChapter chapter) async {
    try {
      final dirPath = await _getChapterDirPath(chapter.mangaId, chapter.id);
      final dir = Directory(dirPath);
      if (await dir.exists()) {
        await dir.delete(recursive: true);
      }
      await AppDatabase.instance.deleteDownload(chapter.id);
      final newSet = Set<String>.from(downloadedChapterIds.value);
      newSet.remove(chapter.id);
      downloadedChapterIds.value = newSet;
    } catch (_) {}
  }
}
