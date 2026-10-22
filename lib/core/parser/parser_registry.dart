import 'manga_parser.dart';
import 'parsers/mangapill_parser.dart';
import 'parsers/komiku_parser.dart';

class ParserRegistry {
  static final ParserRegistry instance = ParserRegistry._internal();

  final Map<String, MangaParser> _parsers = {};

  ParserRegistry._internal() {
    _register(MangaPillParser());
    _register(KomikuParser());
  }

  void _register(MangaParser parser) {
    _parsers[parser.id] = parser;
  }

  List<MangaParser> get allParsers => _parsers.values.toList();

  MangaParser? getParser(String id) => _parsers[id];

  MangaParser get defaultParser => _parsers['mangapill'] ?? _parsers.values.first;
}
