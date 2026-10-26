import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'manga_parser.dart';
import 'parsers/mangapill_parser.dart';
import 'parsers/shinigami_parser.dart';
import 'parsers/weebcentral_parser.dart';

class ParserRegistry {
  static final ParserRegistry instance = ParserRegistry._internal();

  static const String _kActiveParserKey = 'kuroku_active_parser_id';

  final Map<String, MangaParser> _parsers = {};
  final MangaPillParser _mangapill = MangaPillParser();
  final ShinigamiParser _shinigami = ShinigamiParser();
  final WeebCentralParser _weebCentral = WeebCentralParser();
  String? _activeParserId;

  ParserRegistry._internal() {
    _register(_mangapill);
    _register(_shinigami);
    _register(_weebCentral);
  }

  @visibleForTesting
  void resetForTesting() {
    _parsers.clear();
    _register(_mangapill);
    _register(_shinigami);
    _register(_weebCentral);
    _activeParserId = null;
  }

  void _register(MangaParser parser) {
    _parsers[parser.id] = parser;
  }

  void registerParser(MangaParser parser) {
    _register(parser);
  }

  MangaParser get activeParser {
    if (_activeParserId != null && _parsers.containsKey(_activeParserId)) {
      return _parsers[_activeParserId]!;
    }
    return defaultParser;
  }

  Future<void> setActiveParserId(String id) async {
    if (_parsers.containsKey(id)) {
      _activeParserId = id;
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(_kActiveParserKey, id);
      } catch (_) {}
    }
  }

  Future<void> loadCustomSources() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      final mangapillDomain = prefs.getString('domain_mangapill');
      if (mangapillDomain != null && mangapillDomain.isNotEmpty) {
        _mangapill.setCustomDomain(mangapillDomain);
      }

      final shinigamiDomain = prefs.getString('domain_shinigami');
      if (shinigamiDomain != null && shinigamiDomain.isNotEmpty) {
        _shinigami.setCustomDomain(shinigamiDomain);
      }

      final weebCentralDomain = prefs.getString('domain_weebcentral');
      if (weebCentralDomain != null && weebCentralDomain.isNotEmpty) {
        _weebCentral.setCustomDomain(weebCentralDomain);
      }

      // Restore active parser choice (default to mangapill)
      final savedActiveId = prefs.getString(_kActiveParserKey);
      if (savedActiveId != null && _parsers.containsKey(savedActiveId)) {
        _activeParserId = savedActiveId;
      } else {
        _activeParserId = 'mangapill';
      }
    } catch (_) {}
  }

  Future<void> updateSourceDomain(String id, String newDomain) async {
    final cleanDomain = newDomain.replaceAll('https://', '').replaceAll('http://', '').replaceAll('/', '').trim();
    if (cleanDomain.isEmpty) return;

    final prefs = await SharedPreferences.getInstance();

    if (id == 'mangapill') {
      await prefs.setString('domain_mangapill', cleanDomain);
      _mangapill.setCustomDomain(cleanDomain);
    } else if (id == 'shinigami') {
      await prefs.setString('domain_shinigami', cleanDomain);
      _shinigami.setCustomDomain(cleanDomain);
    } else if (id == 'weebcentral') {
      await prefs.setString('domain_weebcentral', cleanDomain);
      _weebCentral.setCustomDomain(cleanDomain);
    }
  }

  List<MangaParser> get allParsers => _parsers.values.toList();

  MangaParser? getParser(String id) {
    if (id == 'custom_mangapill' || id == 'mangapill') {
      return _parsers['mangapill'];
    }
    return _parsers[id];
  }

  MangaParser get defaultParser => _parsers['mangapill'] ?? _parsers.values.first;

  // Stubs for backward compatibility
  Future<void> addCustomSource(dynamic config, {String? rawJson}) async {}
  Future<void> removeCustomSource(String id) async {}
  Future<String?> exportParserToJson(String id) async => null;
}
