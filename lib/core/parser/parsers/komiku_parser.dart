import 'package:html/parser.dart' as html_parser;
import 'package:dio/dio.dart';
import '../../database/models/manga.dart';
import '../../database/models/chapter.dart';
import '../../database/models/manga_page.dart';
import '../../network/http_client.dart';
import '../manga_parser.dart';

class KomikuParser extends MangaParser {
  @override
  String get id => 'komiku';

  @override
  String get name => 'Komiku (ID)';

  @override
  String get domain => 'komiku.org';

  @override
  String get locale => 'id';

  @override
  Map<String, String> get headers => {
    'Referer': 'https://komiku.org/',
    'User-Agent': 'Mozilla/5.0 (iPhone; CPU iPhone OS 17_4 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.4 Mobile/15E148 Safari/604.1',
  };

  @override
  Future<List<Manga>> getList({
    required int page,
    required SortOrder order,
    String? query,
    String? genre,
    String? category,
  }) async {
    String url;
    if (query != null && query.trim().isNotEmpty) {
      final q = Uri.encodeComponent(query.trim());
      url = 'https://api.komiku.id/page/$page/?post_type=manga&s=$q';
    } else {
      url = 'https://api.komiku.id/manga/page/$page/?orderby=modified';
    }

    try {
      final res = await KurokuHttpClient.instance.get<String>(
        url,
        headers: headers,
        responseType: ResponseType.plain,
      );

      if (res.data == null) return [];
      final doc = html_parser.parse(res.data);
      final elements = doc.querySelectorAll('div.bge');

      final list = <Manga>[];
      for (final el in elements) {
        final a = el.querySelector('a:has(h3)') ?? el.querySelector('a');
        if (a == null) continue;

        final href = a.attributes['href'];
        if (href == null) continue;

        final titleEl = el.querySelector('h3');
        final title = titleEl?.text.trim() ?? '';
        if (title.isEmpty) continue;

        final img = el.querySelector('img');
        final dataSrc = img?.attributes['data-src']?.trim();
        final src = img?.attributes['src']?.trim();
        String coverUrl = '';
        if (dataSrc != null && dataSrc.isNotEmpty && !dataSrc.startsWith('data:')) {
          coverUrl = dataSrc;
        } else if (src != null && src.isNotEmpty && !src.startsWith('data:')) {
          coverUrl = src;
        }
        if (coverUrl.contains('?')) {
          coverUrl = coverUrl.split('?').first;
        }

        final mangaId = href.split('/').where((s) => s.isNotEmpty).last;

        list.add(Manga(
          id: '${id}_$mangaId',
          title: title,
          url: href.startsWith('http') ? href : 'https://$domain$href',
          coverUrl: coverUrl,
          sourceId: id,
          status: MangaStatus.ongoing,
        ));
      }

      return list;
    } catch (_) {
      return [];
    }
  }

  @override
  Future<Manga> getDetails(Manga manga) async {
    try {
      final res = await KurokuHttpClient.instance.get<String>(
        manga.url,
        headers: headers,
        responseType: ResponseType.plain,
      );

      if (res.data == null) return manga;
      final doc = html_parser.parse(res.data);

      final descEl = doc.querySelector('#Sinopsis > p') ?? doc.querySelector('p.desc');
      final description = descEl?.text.trim();

      return manga.copyWith(
        description: description,
      );
    } catch (_) {
      return manga;
    }
  }

  @override
  Future<List<MangaChapter>> getChapters(Manga manga) async {
    try {
      final res = await KurokuHttpClient.instance.get<String>(
        manga.url,
        headers: headers,
        responseType: ResponseType.plain,
      );

      if (res.data == null) return [];
      final doc = html_parser.parse(res.data);

      final rows = doc.querySelectorAll('#Daftar_Chapter tr:has(td.judulseries)');
      final chapters = <MangaChapter>[];

      for (int i = 0; i < rows.length; i++) {
        final row = rows[i];
        final a = row.querySelector('td.judulseries a');
        if (a == null) continue;

        final href = a.attributes['href'];
        if (href == null) continue;

        final title = a.querySelector('span')?.text.trim() ?? a.text.trim();
        final chNumber = (rows.length - i).toDouble();
        final chId = href.split('/').where((s) => s.isNotEmpty).last;

        chapters.add(MangaChapter(
          id: '${id}_${manga.id}_$chId',
          mangaId: manga.id,
          title: title,
          number: chNumber,
          url: href.startsWith('http') ? href : 'https://$domain$href',
        ));
      }

      chapters.sort((a, b) => b.number.compareTo(a.number));
      return chapters;
    } catch (_) {
      return [];
    }
  }

  @override
  Future<List<MangaPage>> getPages(MangaChapter chapter) async {
    try {
      final res = await KurokuHttpClient.instance.get<String>(
        chapter.url,
        headers: headers,
        responseType: ResponseType.plain,
      );

      if (res.data == null) return [];
      final doc = html_parser.parse(res.data);

      final imgEls = doc.querySelectorAll('#Baca_Komik img');
      final pages = <MangaPage>[];

      for (int i = 0; i < imgEls.length; i++) {
        final el = imgEls[i];
        final src = el.attributes['src'] ?? el.attributes['data-src'];
        if (src == null || src.isEmpty) continue;

        pages.add(MangaPage(
          index: i,
          url: src.startsWith('http') ? src : 'https://$domain$src',
          headers: headers,
        ));
      }

      return pages;
    } catch (_) {
      return [];
    }
  }
}
