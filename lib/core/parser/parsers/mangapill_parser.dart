import 'package:html/parser.dart' as html_parser;
import 'package:dio/dio.dart';
import '../../database/models/manga.dart';
import '../../database/models/chapter.dart';
import '../../database/models/manga_page.dart';
import '../../network/http_client.dart';
import '../manga_parser.dart';

class MangaPillParser extends MangaParser {
  @override
  String get id => 'mangapill';

  @override
  String get name => 'MangaPill';

  @override
  String get domain => 'mangapill.com';

  @override
  String get locale => 'en';

  @override
  Map<String, String> get headers => {
    'Referer': 'https://mangapill.com/',
    'User-Agent': 'Mozilla/5.0 (iPhone; CPU iPhone OS 17_4 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.4 Mobile/15E148 Safari/604.1',
  };

  @override
  Future<List<Manga>> getList({
    required int page,
    required SortOrder order,
    String? query,
    String? genre,
  }) async {
    String url;
    if (query != null && query.trim().isNotEmpty) {
      final q = Uri.encodeComponent(query.trim());
      url = 'https://$domain/search?q=$q&page=$page';
    } else if (genre != null && genre.isNotEmpty) {
      url = 'https://$domain/search?genre=${Uri.encodeComponent(genre)}&page=$page';
    } else {
      url = 'https://$domain/search?status=publishing&page=$page';
    }

    final res = await KurokuHttpClient.instance.get<String>(
      url,
      headers: headers,
      responseType: ResponseType.plain,
    );

    if (res.data == null) return [];
    final doc = html_parser.parse(res.data);
    final elements = doc.querySelectorAll('a.relative.block');

    final list = <Manga>[];
    for (final el in elements) {
      final href = el.attributes['href'];
      if (href == null || !href.contains('/manga/')) continue;

      final img = el.querySelector('img');
      final coverUrl = img?.attributes['data-src'] ?? img?.attributes['src'] ?? '';

      final parent = el.parent;
      final titleEl = parent?.querySelector('div.mt-3.font-black') ?? parent?.querySelector('div.line-clamp-2');
      final title = titleEl?.text.trim() ?? '';
      if (title.isEmpty) continue;

      final mangaId = href.replaceAll('/manga/', '').split('/').first;

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
  }

  @override
  Future<Manga> getDetails(Manga manga) async {
    final res = await KurokuHttpClient.instance.get<String>(
      manga.url,
      headers: headers,
      responseType: ResponseType.plain,
    );

    if (res.data == null) return manga;
    final doc = html_parser.parse(res.data);

    final descEl = doc.querySelector('p.text-sm.text--secondary') ?? doc.querySelector('p.text-sm');
    final description = descEl?.text.trim();

    final altTitle = doc.querySelector('div.text-sm.text-secondary')?.text.trim();

    final genres = <String>[];
    final genreEls = doc.querySelectorAll('a[href*="/search?genre="]');
    for (final g in genreEls) {
      final text = g.text.trim();
      if (text.isNotEmpty && !genres.contains(text)) {
        genres.add(text);
      }
    }

    MangaStatus status = manga.status;
    final labels = doc.querySelectorAll('label.text-secondary');
    for (final l in labels) {
      if (l.text.contains('Status')) {
        final val = l.nextElementSibling?.text.toLowerCase().trim() ?? '';
        if (val.contains('publishing') || val.contains('ongoing')) {
          status = MangaStatus.ongoing;
        } else if (val.contains('finished') || val.contains('completed')) {
          status = MangaStatus.completed;
        }
      }
    }

    return manga.copyWith(
      description: description,
      altTitle: altTitle,
      genres: genres,
      status: status,
    );
  }

  @override
  Future<List<MangaChapter>> getChapters(Manga manga) async {
    final res = await KurokuHttpClient.instance.get<String>(
      manga.url,
      headers: headers,
      responseType: ResponseType.plain,
    );

    if (res.data == null) return [];
    final doc = html_parser.parse(res.data);

    final chapterLinks = doc.querySelectorAll('div#chapters a');
    final chapters = <MangaChapter>[];

    for (int i = 0; i < chapterLinks.length; i++) {
      final el = chapterLinks[i];
      final href = el.attributes['href'];
      if (href == null) continue;

      final title = el.text.trim();
      double number = 0;
      final match = RegExp(r'Chapter\s+([0-9.]+)').firstMatch(title);
      if (match != null) {
        number = double.tryParse(match.group(1) ?? '0') ?? 0;
      } else {
        number = (chapterLinks.length - i).toDouble();
      }

      final chapterId = href.split('/').where((s) => s.isNotEmpty).last;

      chapters.add(MangaChapter(
        id: '${id}_${manga.id}_$chapterId',
        mangaId: manga.id,
        title: title,
        number: number,
        url: href.startsWith('http') ? href : 'https://$domain$href',
      ));
    }

    // Sort chapters by number descending (latest first)
    chapters.sort((a, b) => b.number.compareTo(a.number));
    return chapters;
  }

  @override
  Future<List<MangaPage>> getPages(MangaChapter chapter) async {
    final res = await KurokuHttpClient.instance.get<String>(
      chapter.url,
      headers: headers,
      responseType: ResponseType.plain,
    );

    if (res.data == null) return [];
    final doc = html_parser.parse(res.data);

    final imgEls = doc.querySelectorAll('img.js-page');
    final pages = <MangaPage>[];

    for (int i = 0; i < imgEls.length; i++) {
      final el = imgEls[i];
      final imgUrl = el.attributes['data-src'] ?? el.attributes['src'];
      if (imgUrl == null || imgUrl.isEmpty) continue;

      pages.add(MangaPage(
        index: i,
        url: imgUrl.startsWith('http') ? imgUrl : 'https://$domain$imgUrl',
        headers: headers,
      ));
    }

    return pages;
  }
}
