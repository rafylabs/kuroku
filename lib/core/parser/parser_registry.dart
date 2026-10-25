import 'package:shared_preferences/shared_preferences.dart';
import '../database/app_database.dart';
import 'manga_parser.dart';
import 'dynamic_manga_parser.dart';
import 'parsers/shinigami_parser.dart';
import 'parsers/weebcentral_parser.dart';

import 'parser_importer.dart';

class ParserRegistry {
  static final ParserRegistry instance = ParserRegistry._internal();

  final Map<String, MangaParser> _parsers = {};
  final ShinigamiParser _shinigami = ShinigamiParser();
  final WeebCentralParser _weebCentral = WeebCentralParser();

  ParserRegistry._internal() {
    _register(_shinigami);
    _register(_weebCentral);
  }

  void _register(MangaParser parser) {
    _parsers[parser.id] = parser;
  }

  void registerParser(MangaParser parser) {
    _register(parser);
  }

  Future<void> loadCustomSources() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      // Load overridden domain for Shinigami
      final shinigamiDomain = prefs.getString('domain_shinigami');
      if (shinigamiDomain != null && shinigamiDomain.isNotEmpty) {
        _shinigami.setCustomDomain(shinigamiDomain);
      }

      // Load overridden domain for WeebCentral
      final weebCentralDomain = prefs.getString('domain_weebcentral');
      if (weebCentralDomain != null && weebCentralDomain.isNotEmpty) {
        _weebCentral.setCustomDomain(weebCentralDomain);
      }

      // Load user custom sources from local SQLite database
      final customConfigs = await AppDatabase.instance.getCustomSources();
      for (final cfg in customConfigs) {
        _register(DynamicMangaParser(cfg));
      }
    } catch (_) {}
  }

  Future<void> updateSourceDomain(String id, String newDomain) async {
    final cleanDomain = newDomain.replaceAll('https://', '').replaceAll('http://', '').replaceAll('/', '').trim();
    if (cleanDomain.isEmpty) return;

    final prefs = await SharedPreferences.getInstance();

    if (id == 'shinigami') {
      await prefs.setString('domain_shinigami', cleanDomain);
      _shinigami.setCustomDomain(cleanDomain);
    } else if (id == 'weebcentral') {
      await prefs.setString('domain_weebcentral', cleanDomain);
      _weebCentral.setCustomDomain(cleanDomain);
    } else if (id.startsWith('custom_')) {
      final customConfigs = await AppDatabase.instance.getCustomSources();
      final target = customConfigs.where((c) => c.id == id).firstOrNull;
      if (target != null) {
        final updated = CustomSourceConfig(
          id: target.id,
          name: target.name,
          domain: cleanDomain,
          locale: target.locale,
          type: target.type,
          customSelectors: target.customSelectors,
        );
        await AppDatabase.instance.upsertCustomSource(updated);
        _register(DynamicMangaParser(updated));
      }
    }
  }

  Future<void> addCustomSource(CustomSourceConfig config) async {
    await AppDatabase.instance.upsertCustomSource(config);
    _register(DynamicMangaParser(config));
  }

  Future<void> removeCustomSource(String id) async {
    await AppDatabase.instance.deleteCustomSource(id);
    _parsers.remove(id);
  }

  Future<CustomSourceConfig> importParserFromJson(String jsonStr) async {
    final config = ParserImporter.fromJsonString(jsonStr);
    await addCustomSource(config);
    return config;
  }

  Future<CustomSourceConfig> importParserFromUrl(String url) async {
    final config = await ParserImporter.fetchFromUrl(url);
    await addCustomSource(config);
    return config;
  }

  Future<String?> exportParserToJson(String id) async {
    final customConfigs = await AppDatabase.instance.getCustomSources();
    final target = customConfigs.where((c) => c.id == id).firstOrNull;
    if (target != null) {
      return ParserImporter.exportToJson(target);
    }
    return null;
  }

  List<MangaParser> get allParsers => _parsers.values.toList();

  MangaParser? getParser(String id) => _parsers[id];

  MangaParser get defaultParser => _parsers['shinigami'] ?? _parsers.values.first;
}
