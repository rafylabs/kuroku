class MangaChapter {
  final String id;
  final String mangaId;
  final String title;
  final double number;
  final String url;
  final String? scanlator;
  final DateTime? uploadDate;
  final bool isRead;
  final int lastReadPage;
  final int pageCount;

  const MangaChapter({
    required this.id,
    required this.mangaId,
    required this.title,
    required this.number,
    required this.url,
    this.scanlator,
    this.uploadDate,
    this.isRead = false,
    this.lastReadPage = 0,
    this.pageCount = 0,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'manga_id': mangaId,
      'title': title,
      'number': number,
      'url': url,
      'scanlator': scanlator,
      'upload_date': uploadDate?.toIso8601String(),
      'is_read': isRead ? 1 : 0,
      'last_read_page': lastReadPage,
      'page_count': pageCount,
    };
  }

  factory MangaChapter.fromMap(Map<String, dynamic> map) {
    return MangaChapter(
      id: map['id'] as String,
      mangaId: map['manga_id'] as String,
      title: map['title'] as String,
      number: (map['number'] as num).toDouble(),
      url: map['url'] as String,
      scanlator: map['scanlator'] as String?,
      uploadDate: map['upload_date'] != null ? DateTime.tryParse(map['upload_date'] as String) : null,
      isRead: (map['is_read'] as int? ?? 0) == 1,
      lastReadPage: map['last_read_page'] as int? ?? 0,
      pageCount: map['page_count'] as int? ?? 0,
    );
  }

  MangaChapter copyWith({
    String? id,
    String? mangaId,
    String? title,
    double? number,
    String? url,
    String? scanlator,
    DateTime? uploadDate,
    bool? isRead,
    int? lastReadPage,
    int? pageCount,
  }) {
    return MangaChapter(
      id: id ?? this.id,
      mangaId: mangaId ?? this.mangaId,
      title: title ?? this.title,
      number: number ?? this.number,
      url: url ?? this.url,
      scanlator: scanlator ?? this.scanlator,
      uploadDate: uploadDate ?? this.uploadDate,
      isRead: isRead ?? this.isRead,
      lastReadPage: lastReadPage ?? this.lastReadPage,
      pageCount: pageCount ?? this.pageCount,
    );
  }
}
