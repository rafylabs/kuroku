import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';
import 'models/manga.dart';
import 'models/chapter.dart';
import 'models/history_entry.dart';
import '../parser/dynamic_manga_parser.dart';

class AppDatabase {
  static final AppDatabase instance = AppDatabase._internal();
  Database? _db;

  AppDatabase._internal();

  Future<Database> get database async {
    if (_db != null) return _db!;
    _db = await _initDatabase();
    return _db!;
  }

  Future<Database> _initDatabase() async {
    final docsDir = await getApplicationDocumentsDirectory();
    final dbPath = p.join(docsDir.path, 'kuroku_local.db');

    return await openDatabase(
      dbPath,
      version: 1,
      onOpen: (db) async {
        await db.execute('''
          CREATE TABLE IF NOT EXISTS custom_sources (
            id TEXT PRIMARY KEY,
            name TEXT NOT NULL,
            domain TEXT NOT NULL,
            locale TEXT NOT NULL DEFAULT 'id',
            type TEXT NOT NULL DEFAULT 'madara',
            config TEXT
          )
        ''');
        await db.execute('''
          CREATE TABLE IF NOT EXISTS downloads (
            chapter_id TEXT PRIMARY KEY,
            manga_id TEXT NOT NULL,
            dir_path TEXT NOT NULL,
            page_count INTEGER NOT NULL,
            downloaded_at TEXT NOT NULL
          )
        ''');
        await db.execute('CREATE INDEX IF NOT EXISTS idx_downloads_manga ON downloads(manga_id);');
      },
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE manga (
            id TEXT PRIMARY KEY,
            title TEXT NOT NULL,
            alt_title TEXT,
            url TEXT NOT NULL,
            cover_url TEXT NOT NULL,
            source_id TEXT NOT NULL,
            author TEXT,
            artist TEXT,
            description TEXT,
            status TEXT,
            rating REAL,
            genres TEXT,
            is_favorite INTEGER NOT NULL DEFAULT 0,
            last_read_at TEXT
          )
        ''');

        await db.execute('''
          CREATE TABLE chapters (
            id TEXT PRIMARY KEY,
            manga_id TEXT NOT NULL,
            title TEXT NOT NULL,
            number REAL NOT NULL,
            url TEXT NOT NULL,
            scanlator TEXT,
            upload_date TEXT,
            is_read INTEGER NOT NULL DEFAULT 0,
            last_read_page INTEGER NOT NULL DEFAULT 0,
            page_count INTEGER NOT NULL DEFAULT 0,
            FOREIGN KEY(manga_id) REFERENCES manga(id) ON DELETE CASCADE
          )
        ''');

        await db.execute('''
          CREATE TABLE history (
            manga_id TEXT NOT NULL,
            chapter_id TEXT NOT NULL,
            page INTEGER NOT NULL DEFAULT 0,
            updated_at TEXT NOT NULL,
            PRIMARY KEY(manga_id),
            FOREIGN KEY(manga_id) REFERENCES manga(id) ON DELETE CASCADE,
            FOREIGN KEY(chapter_id) REFERENCES chapters(id) ON DELETE CASCADE
          )
        ''');

        await db.execute('''
          CREATE TABLE downloads (
            chapter_id TEXT PRIMARY KEY,
            manga_id TEXT NOT NULL,
            dir_path TEXT NOT NULL,
            page_count INTEGER NOT NULL,
            downloaded_at TEXT NOT NULL,
            FOREIGN KEY(manga_id) REFERENCES manga(id) ON DELETE CASCADE
          )
        ''');

        await db.execute('CREATE INDEX idx_manga_fav ON manga(is_favorite);');
        await db.execute('CREATE INDEX idx_chapters_manga ON chapters(manga_id);');
        await db.execute('CREATE INDEX idx_history_updated ON history(updated_at DESC);');
        await db.execute('CREATE INDEX idx_downloads_manga ON downloads(manga_id);');
      },
    );
  }

  // --- Manga Operations ---
  Future<void> upsertManga(Manga manga) async {
    final db = await database;
    await db.insert(
      'manga',
      manga.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<Manga?> getManga(String id) async {
    final db = await database;
    final results = await db.query(
      'manga',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (results.isEmpty) return null;
    return Manga.fromMap(results.first);
  }

  Future<List<Manga>> getFavorites() async {
    final db = await database;
    final results = await db.query(
      'manga',
      where: 'is_favorite = 1',
      orderBy: 'title ASC',
    );
    return results.map((m) => Manga.fromMap(m)).toList();
  }

  Future<bool> toggleFavorite(Manga manga) async {
    final db = await database;
    final current = await getManga(manga.id);
    final newFavStatus = !(current?.isFavorite ?? false);

    final updated = manga.copyWith(isFavorite: newFavStatus);
    await db.insert(
      'manga',
      updated.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    return newFavStatus;
  }

  // --- Chapters Operations ---
  Future<void> upsertChapters(List<MangaChapter> chapters) async {
    if (chapters.isEmpty) return;
    final db = await database;
    final batch = db.batch();
    for (final ch in chapters) {
      batch.insert(
        'chapters',
        ch.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
    await batch.commit(noResult: true);
  }

  Future<List<MangaChapter>> getChapters(String mangaId) async {
    final db = await database;
    final cleanId = mangaId.contains('_') ? mangaId.substring(mangaId.indexOf('_') + 1) : mangaId;
    final results = await db.query(
      'chapters',
      where: 'manga_id = ? OR manga_id = ? OR manga_id LIKE ?',
      whereArgs: [mangaId, cleanId, '%$cleanId%'],
      orderBy: 'number DESC',
    );
    final chapters = results.map((c) => MangaChapter.fromMap(c)).toList();

    // Check downloads table for any downloaded chapters not in chapters table
    try {
      final downloads = await db.query(
        'downloads',
        where: 'manga_id = ? OR manga_id = ? OR manga_id LIKE ?',
        whereArgs: [mangaId, cleanId, '%$cleanId%'],
        orderBy: 'downloaded_at DESC',
      );

      final existingIds = chapters.map((c) => c.id).toSet();
      for (final d in downloads) {
        final chId = d['chapter_id'] as String;
        if (!existingIds.contains(chId)) {
          final rawId = chId.split('_').last;
          chapters.add(MangaChapter(
            id: chId,
            mangaId: mangaId,
            title: 'Downloaded Chapter ($rawId)',
            number: 1.0,
            url: rawId,
            pageCount: d['page_count'] as int? ?? 0,
          ));
        }
      }
    } catch (_) {}

    chapters.sort((a, b) => b.number.compareTo(a.number));
    return chapters;
  }

  Future<void> updateChapterProgress(String chapterId, int page, bool isRead) async {
    final db = await database;
    await db.update(
      'chapters',
      {
        'last_read_page': page,
        'is_read': isRead ? 1 : 0,
      },
      where: 'id = ?',
      whereArgs: [chapterId],
    );
  }

  // --- History Operations ---
  Future<void> recordHistory({
    required Manga manga,
    required MangaChapter chapter,
    required int page,
  }) async {
    final db = await database;
    await upsertManga(manga);
    await upsertChapters([chapter]);

    await db.insert(
      'history',
      {
        'manga_id': manga.id,
        'chapter_id': chapter.id,
        'page': page,
        'updated_at': DateTime.now().toIso8601String(),
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<HistoryEntry>> getHistory() async {
    final db = await database;
    final results = await db.rawQuery('''
      SELECT 
        h.page as hist_page,
        h.updated_at as hist_updated,
        m.*,
        c.title as ch_title,
        c.number as ch_number,
        c.url as ch_url,
        c.scanlator as ch_scanlator,
        c.upload_date as ch_upload_date,
        c.is_read as ch_is_read,
        c.last_read_page as ch_last_read_page,
        c.page_count as ch_page_count,
        c.id as ch_id
      FROM history h
      INNER JOIN manga m ON h.manga_id = m.id
      INNER JOIN chapters c ON h.chapter_id = c.id
      ORDER BY h.updated_at DESC
    ''');

    return results.map((row) {
      final manga = Manga.fromMap(row);
      final chapter = MangaChapter(
        id: row['ch_id'] as String,
        mangaId: manga.id,
        title: row['ch_title'] as String,
        number: (row['ch_number'] as num).toDouble(),
        url: row['ch_url'] as String,
        scanlator: row['ch_scanlator'] as String?,
        uploadDate: row['ch_upload_date'] != null ? DateTime.tryParse(row['ch_upload_date'] as String) : null,
        isRead: (row['ch_is_read'] as int? ?? 0) == 1,
        lastReadPage: row['ch_last_read_page'] as int? ?? 0,
        pageCount: row['ch_page_count'] as int? ?? 0,
      );

      return HistoryEntry(
        manga: manga,
        chapter: chapter,
        page: row['hist_page'] as int? ?? 0,
        updatedAt: DateTime.tryParse(row['hist_updated'] as String) ?? DateTime.now(),
      );
    }).toList();
  }

  // --- Custom Sources Operations ---
  Future<List<CustomSourceConfig>> getCustomSources() async {
    final db = await database;
    final results = await db.query('custom_sources', orderBy: 'name ASC');
    return results.map((r) => CustomSourceConfig.fromMap(r)).toList();
  }

  Future<void> upsertCustomSource(CustomSourceConfig config) async {
    final db = await database;
    await db.insert(
      'custom_sources',
      config.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> deleteCustomSource(String id) async {
    final db = await database;
    await db.delete(
      'custom_sources',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // --- Downloads Operations ---
  Future<void> saveDownload({
    required String chapterId,
    required String mangaId,
    required String dirPath,
    required int pageCount,
  }) async {
    final db = await database;
    await db.insert(
      'downloads',
      {
        'chapter_id': chapterId,
        'manga_id': mangaId,
        'dir_path': dirPath,
        'page_count': pageCount,
        'downloaded_at': DateTime.now().toIso8601String(),
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> deleteDownload(String chapterId) async {
    final db = await database;
    await db.delete(
      'downloads',
      where: 'chapter_id = ?',
      whereArgs: [chapterId],
    );
  }

  Future<bool> isChapterDownloaded(String chapterId) async {
    final db = await database;
    final res = await db.query(
      'downloads',
      where: 'chapter_id = ?',
      whereArgs: [chapterId],
      limit: 1,
    );
    return res.isNotEmpty;
  }

  Future<List<String>> getDownloadedChapterIds(String mangaId) async {
    final db = await database;
    final res = await db.query(
      'downloads',
      columns: ['chapter_id'],
      where: 'manga_id = ?',
      whereArgs: [mangaId],
    );
    return res.map((r) => r['chapter_id'] as String).toList();
  }

  Future<List<Manga>> getDownloadedManga() async {
    final db = await database;
    final results = await db.rawQuery('''
      SELECT DISTINCT m.* FROM manga m
      INNER JOIN downloads d ON m.id = d.manga_id
      ORDER BY m.title ASC
    ''');
    return results.map((r) => Manga.fromMap(r)).toList();
  }
}
