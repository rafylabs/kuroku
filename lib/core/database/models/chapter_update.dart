class ChapterUpdate {
  final String id;
  final String mangaId;
  final String mangaTitle;
  final String coverUrl;
  final String sourceId;
  final String chapterId;
  final String chapterTitle;
  final double chapterNumber;
  final DateTime detectedAt;
  final bool isSeen;

  const ChapterUpdate({
    required this.id,
    required this.mangaId,
    required this.mangaTitle,
    required this.coverUrl,
    required this.sourceId,
    required this.chapterId,
    required this.chapterTitle,
    required this.chapterNumber,
    required this.detectedAt,
    this.isSeen = false,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'manga_id': mangaId,
      'manga_title': mangaTitle,
      'cover_url': coverUrl,
      'source_id': sourceId,
      'chapter_id': chapterId,
      'chapter_title': chapterTitle,
      'chapter_number': chapterNumber,
      'detected_at': detectedAt.toIso8601String(),
      'is_seen': isSeen ? 1 : 0,
    };
  }

  factory ChapterUpdate.fromMap(Map<String, dynamic> map) {
    return ChapterUpdate(
      id: map['id'] as String,
      mangaId: map['manga_id'] as String,
      mangaTitle: map['manga_title'] as String,
      coverUrl: map['cover_url'] as String,
      sourceId: map['source_id'] as String? ?? 'unknown',
      chapterId: map['chapter_id'] as String,
      chapterTitle: map['chapter_title'] as String,
      chapterNumber: (map['chapter_number'] as num?)?.toDouble() ?? 0.0,
      detectedAt: DateTime.tryParse(map['detected_at'] as String? ?? '') ?? DateTime.now(),
      isSeen: (map['is_seen'] as int? ?? 0) == 1,
    );
  }

  ChapterUpdate copyWith({
    String? id,
    String? mangaId,
    String? mangaTitle,
    String? coverUrl,
    String? sourceId,
    String? chapterId,
    String? chapterTitle,
    double? chapterNumber,
    DateTime? detectedAt,
    bool? isSeen,
  }) {
    return ChapterUpdate(
      id: id ?? this.id,
      mangaId: mangaId ?? this.mangaId,
      mangaTitle: mangaTitle ?? this.mangaTitle,
      coverUrl: coverUrl ?? this.coverUrl,
      sourceId: sourceId ?? this.sourceId,
      chapterId: chapterId ?? this.chapterId,
      chapterTitle: chapterTitle ?? this.chapterTitle,
      chapterNumber: chapterNumber ?? this.chapterNumber,
      detectedAt: detectedAt ?? this.detectedAt,
      isSeen: isSeen ?? this.isSeen,
    );
  }
}
