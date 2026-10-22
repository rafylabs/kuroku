import 'manga.dart';
import 'chapter.dart';

class HistoryEntry {
  final Manga manga;
  final MangaChapter chapter;
  final int page;
  final DateTime updatedAt;

  const HistoryEntry({
    required this.manga,
    required this.chapter,
    required this.page,
    required this.updatedAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'manga_id': manga.id,
      'chapter_id': chapter.id,
      'page': page,
      'updated_at': updatedAt.toIso8601String(),
    };
  }
}
