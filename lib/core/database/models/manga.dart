enum MangaStatus {
  ongoing,
  completed,
  cancelled,
  unknown,
}

enum SortOrder {
  popular,
  latest,
  updated,
  alphabetic,
}

class Manga {
  final String id;
  final String title;
  final String? altTitle;
  final String url;
  final String coverUrl;
  final String sourceId;
  final String? author;
  final String? artist;
  final String? description;
  final MangaStatus status;
  final double? rating;
  final List<String> genres;
  final bool isFavorite;
  final DateTime? lastReadAt;

  const Manga({
    required this.id,
    required this.title,
    this.altTitle,
    required this.url,
    required this.coverUrl,
    required this.sourceId,
    this.author,
    this.artist,
    this.description,
    this.status = MangaStatus.unknown,
    this.rating,
    this.genres = const [],
    this.isFavorite = false,
    this.lastReadAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'alt_title': altTitle,
      'url': url,
      'cover_url': coverUrl,
      'source_id': sourceId,
      'author': author,
      'artist': artist,
      'description': description,
      'status': status.name,
      'rating': rating,
      'genres': genres.join(','),
      'is_favorite': isFavorite ? 1 : 0,
      'last_read_at': lastReadAt?.toIso8601String(),
    };
  }

  factory Manga.fromMap(Map<String, dynamic> map) {
    return Manga(
      id: map['id'] as String,
      title: map['title'] as String,
      altTitle: map['alt_title'] as String?,
      url: map['url'] as String,
      coverUrl: map['cover_url'] as String,
      sourceId: map['source_id'] as String,
      author: map['author'] as String?,
      artist: map['artist'] as String?,
      description: map['description'] as String?,
      status: MangaStatus.values.firstWhere(
        (e) => e.name == map['status'],
        orElse: () => MangaStatus.unknown,
      ),
      rating: (map['rating'] as num?)?.toDouble(),
      genres: (map['genres'] as String?)?.split(',').where((s) => s.isNotEmpty).toList() ?? [],
      isFavorite: (map['is_favorite'] as int? ?? 0) == 1,
      lastReadAt: map['last_read_at'] != null ? DateTime.tryParse(map['last_read_at'] as String) : null,
    );
  }

  Manga copyWith({
    String? id,
    String? title,
    String? altTitle,
    String? url,
    String? coverUrl,
    String? sourceId,
    String? author,
    String? artist,
    String? description,
    MangaStatus? status,
    double? rating,
    List<String>? genres,
    bool? isFavorite,
    DateTime? lastReadAt,
  }) {
    return Manga(
      id: id ?? this.id,
      title: title ?? this.title,
      altTitle: altTitle ?? this.altTitle,
      url: url ?? this.url,
      coverUrl: coverUrl ?? this.coverUrl,
      sourceId: sourceId ?? this.sourceId,
      author: author ?? this.author,
      artist: artist ?? this.artist,
      description: description ?? this.description,
      status: status ?? this.status,
      rating: rating ?? this.rating,
      genres: genres ?? this.genres,
      isFavorite: isFavorite ?? this.isFavorite,
      lastReadAt: lastReadAt ?? this.lastReadAt,
    );
  }
}
