import 'dart:convert';
import 'package:flutter/foundation.dart';
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

  @visibleForTesting
  void resetForTesting() {
    _parsers.clear();
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

      // 1. Dual-source reconciliation: gather configs from both SQLite and SharedPreferences
      final Map<String, CustomSourceConfig> mergedConfigs = {};

      // Load from SQLite
      try {
        final sqliteConfigs = await AppDatabase.instance.getCustomSources();
        for (final cfg in sqliteConfigs) {
          if (cfg.id.isNotEmpty) {
            mergedConfigs[cfg.id] = cfg;
          }
        }
      } catch (_) {}

      // Load from SharedPreferences backup
      try {
        final backupList = prefs.getStringList(_kCustomSourcesBackupKey) ?? [];
        for (final item in backupList) {
          try {
            final decoded = jsonDecode(item);
            if (decoded is Map) {
              final cfg = CustomSourceConfig.fromMap(Map<String, dynamic>.from(decoded));
              if (cfg.id.isNotEmpty) {
                // If not in SQLite, or backup has selectors while SQLite version doesn't, prefer backup
                final existing = mergedConfigs[cfg.id];
                if (existing == null || (existing.customSelectors == null && cfg.customSelectors != null)) {
                  mergedConfigs[cfg.id] = cfg;
                }
              }
            }
          } catch (_) {}
        }
      } catch (_) {}

      // 2. Register all merged custom sources into memory
      for (final cfg in mergedConfigs.values) {
        try {
          _register(DynamicMangaParser(cfg));
          // Self-heal SQLite database with latest merged config
          await AppDatabase.instance.upsertCustomSource(cfg);
        } catch (_) {}
      }

      // 3. Keep SharedPreferences backup synchronized only if configs were actually recovered
      if (mergedConfigs.isNotEmpty) {
        await _syncCustomSourcesBackup(prefs);
      }

      // 4. Restore active parser choice
      final savedActiveId = prefs.getString(_kActiveParserKey);
      if (savedActiveId != null && _parsers.containsKey(savedActiveId)) {
        _activeParserId = savedActiveId;
      }
    } catch (_) {}
  }

  Future<void> _syncCustomSourcesBackup([SharedPreferences? prefs, bool forceEmpty = false]) async {
    try {
      final p = prefs ?? await SharedPreferences.getInstance();
      final customParsers = _parsers.values.whereType<DynamicMangaParser>().toList();
      if (customParsers.isEmpty && !forceEmpty) {
        // Guard against wiping existing backup on transient startup errors
        return;
      }
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

  Future<void> addCustomSource(CustomSourceConfig config, {String? rawJson}) async {
    CustomSourceConfig finalConfig = config;
    if (rawJson != null && rawJson.trim().isNotEmpty) {
      try {
        final decoded = jsonDecode(rawJson);
        if (decoded is Map) {
          finalConfig = CustomSourceConfig.fromMap({
            ...config.toMap(),
            'config': rawJson,
          });
        }
      } catch (_) {}
    }

    try {
      await AppDatabase.instance.upsertCustomSource(finalConfig);
    } catch (_) {}
    _register(DynamicMangaParser(finalConfig));
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
    await _syncCustomSourcesBackup(null, true);
  }

  Future<CustomSourceConfig> importParserFromJson(String jsonStr) async {
    final config = ParserImporter.fromJsonString(jsonStr);
    await addCustomSource(config, rawJson: jsonStr);
    return config;
  }

  Future<CustomSourceConfig> importParserFromUrl(String url) async {
    final config = await ParserImporter.fetchFromUrl(url);
    await addCustomSource(config, rawJson: ParserImporter.exportToJson(config));
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
