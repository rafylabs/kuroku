import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../database/app_database.dart';
import 'manga_parser.dart';
import 'dynamic_manga_parser.dart';
import 'parsers/shinigami_parser.dart';
import 'parsers/weebcentral_parser.dart';

import 'parser_importer.dart';

class ParserRegistry {
  static final ParserRegistry instance = ParserRegistry._internal();

  static const String _kActiveParserKey = 'kuroku_active_parser_id';
  static const String _kCustomSourcesBackupKey = 'persisted_custom_sources_v1';

  final Map<String, MangaParser> _parsers = {};
  final ShinigamiParser _shinigami = ShinigamiParser();
  final WeebCentralParser _weebCentral = WeebCentralParser();
  String? _activeParserId;

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

      // 1. Load user custom sources from local SQLite database
      List<CustomSourceConfig> customConfigs = [];
      try {
        customConfigs = await AppDatabase.instance.getCustomSources();
      } catch (_) {}

      // 2. Fallback to SharedPreferences backup if SQLite returned empty
      if (customConfigs.isEmpty) {
        final backupList = prefs.getStringList(_kCustomSourcesBackupKey) ?? [];
        for (final item in backupList) {
          try {
            final map = jsonDecode(item) as Map<String, dynamic>;
            customConfigs.add(CustomSourceConfig.fromMap(map));
          } catch (_) {}
        }
        // Resync restored configs back to SQLite
        for (final cfg in customConfigs) {
          try {
            await AppDatabase.instance.upsertCustomSource(cfg);
          } catch (_) {}
        }
      }

      // 3. Register all discovered custom sources
      for (final cfg in customConfigs) {
        try {
          _register(DynamicMangaParser(cfg));
        } catch (_) {}
      }

      // 4. Ensure SharedPreferences backup is always in sync
      await _syncCustomSourcesBackup(prefs);

      // 5. Restore active parser choice
      final savedActiveId = prefs.getString(_kActiveParserKey);
      if (savedActiveId != null && _parsers.containsKey(savedActiveId)) {
        _activeParserId = savedActiveId;
      }
    } catch (_) {}
  }

  Future<void> _syncCustomSourcesBackup([SharedPreferences? prefs]) async {
    try {
      final p = prefs ?? await SharedPreferences.getInstance();
      final customParsers = _parsers.values.whereType<DynamicMangaParser>().toList();
      final list = customParsers.map((cp) => jsonEncode(cp.sourceConfig.toMap())).toList();
      await p.setStringList(_kCustomSourcesBackupKey, list);
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
        try {
          await AppDatabase.instance.upsertCustomSource(updated);
        } catch (_) {}
        _register(DynamicMangaParser(updated));
        await _syncCustomSourcesBackup(prefs);
      }
    }
  }

  Future<void> addCustomSource(CustomSourceConfig config) async {
    try {
      await AppDatabase.instance.upsertCustomSource(config);
    } catch (_) {}
    _register(DynamicMangaParser(config));
    await _syncCustomSourcesBackup();
  }

  Future<void> removeCustomSource(String id) async {
    try {
      await AppDatabase.instance.deleteCustomSource(id);
    } catch (_) {}
    _parsers.remove(id);
    if (_activeParserId == id) {
      _activeParserId = defaultParser.id;
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_kActiveParserKey, defaultParser.id);
    }
    await _syncCustomSourcesBackup();
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
