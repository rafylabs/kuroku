class MangaPage {
  final int index;
  final String url;
  final Map<String, String>? headers;

  const MangaPage({
    required this.index,
    required this.url,
    this.headers,
  });

  Map<String, dynamic> toMap() {
    return {
      'index': index,
      'url': url,
    };
  }

  factory MangaPage.fromMap(Map<String, dynamic> map) {
    return MangaPage(
      index: map['index'] as int,
      url: map['url'] as String,
    );
  }
}
