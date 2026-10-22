import '../database/app_database.dart';
import 'manga_parser.dart';
import 'dynamic_manga_parser.dart';
import 'parsers/mangapill_parser.dart';
import 'parsers/komiku_parser.dart';
import 'parsers/shinigami_parser.dart';

class ParserRegistry {
  static final ParserRegistry instance = ParserRegistry._internal();

  final Map<String, MangaParser> _parsers = {};

  ParserRegistry._internal() {
    _register(MangaPillParser());
    _register(KomikuParser());
    _register(ShinigamiParser());
  }

  void _register(MangaParser parser) {
    _parsers[parser.id] = parser;
  }

  Future<void> loadCustomSources() async {
    try {
      final customConfigs = await AppDatabase.instance.getCustomSources();
      for (final cfg in customConfigs) {
        _register(DynamicMangaParser(cfg));
      }
    } catch (_) {}
  }

  Future<void> addCustomSource(CustomSourceConfig config) async {
    await AppDatabase.instance.upsertCustomSource(config);
    _register(DynamicMangaParser(config));
  }

  Future<void> removeCustomSource(String id) async {
    await AppDatabase.instance.deleteCustomSource(id);
    _parsers.remove(id);
  }

  List<MangaParser> get allParsers => _parsers.values.toList();

  MangaParser? getParser(String id) => _parsers[id];

  MangaParser get defaultParser => _parsers['shinigami'] ?? _parsers['komiku'] ?? _parsers.values.first;
}
