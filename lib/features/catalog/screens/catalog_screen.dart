import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:extended_image/extended_image.dart';
import '../../../core/database/models/manga.dart';
import '../../../core/parser/manga_parser.dart';
import '../../../core/parser/parser_registry.dart';
import '../../../core/parser/dynamic_manga_parser.dart';
import '../../../core/parser/parser_importer.dart';
import '../providers/catalog_provider.dart';
import 'manga_detail_screen.dart';

class CatalogScreen extends ConsumerStatefulWidget {
  const CatalogScreen({super.key});

  @override
  ConsumerState<CatalogScreen> createState() => _CatalogScreenState();
}

class _CatalogScreenState extends ConsumerState<CatalogScreen> {
  final ScrollController _scrollController = ScrollController();
  final TextEditingController _searchController = TextEditingController();
  bool _isSearching = false;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 400) {
      ref.read(catalogProvider.notifier).loadNextPage();
    }
  }

  void _showEditDomainDialog(MangaParser parser) {
    final domainController = TextEditingController(text: parser.domain);

    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        title: Text('Edit Domain: ${parser.name}', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Domain / Mirror URL', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
            const SizedBox(height: 6),
            TextField(
              controller: domainController,
              decoration: const InputDecoration(
                hintText: 'e.g. id.shinigami.asia or shinigami.moe',
                isDense: true,
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              final newDomain = domainController.text.trim();
              if (newDomain.isNotEmpty) {
                await ParserRegistry.instance.updateSourceDomain(parser.id, newDomain);
                final updated = ParserRegistry.instance.getParser(parser.id);
                if (updated != null && ref.read(activeParserProvider).id == parser.id) {
                  ref.read(activeParserProvider.notifier).state = updated;
                }
              }
              if (dialogCtx.mounted) {
                Navigator.pop(dialogCtx);
              }
              if (mounted) {
                setState(() {});
              }
            },
            child: const Text('Save Domain'),
          ),
        ],
      ),
    );
  }

  void _showAddSourceDialog() {
    final nameController = TextEditingController();
    final domainController = TextEditingController();
    String selectedType = 'madara';
    String selectedLocale = 'id';

    showDialog(
      context: context,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (innerCtx, setDialogState) {
          return AlertDialog(
            title: const Text('Add Custom Manga Source', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Source Name', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 4),
                  TextField(
                    controller: nameController,
                    decoration: const InputDecoration(
                      hintText: 'e.g. Komikcast / Manhwa18',
                      isDense: true,
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Text('Domain / Website URL', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 4),
                  TextField(
                    controller: domainController,
                    decoration: const InputDecoration(
                      hintText: 'e.g. komikcast.bz or manhwa18.com',
                      isDense: true,
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Text('Website Template', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 4),
                  DropdownButtonFormField<String>(
                    initialValue: selectedType,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      isDense: true,
                      border: OutlineInputBorder(),
                    ),
                    items: const [
                      DropdownMenuItem(
                        value: 'madara',
                        child: Text('WordPress Madara (Default / Popular)', style: TextStyle(fontSize: 12)),
                      ),
                      DropdownMenuItem(
                        value: 'themesia',
                        child: Text('MangaThemesia (Kiryuu/Komikcast)', style: TextStyle(fontSize: 12)),
                      ),
                    ],
                    onChanged: (val) {
                      if (val != null) setDialogState(() => selectedType = val);
                    },
                  ),
                  const SizedBox(height: 12),
                  const Text('Language', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 4),
                  DropdownButtonFormField<String>(
                    initialValue: selectedLocale,
                    decoration: const InputDecoration(
                      isDense: true,
                      border: OutlineInputBorder(),
                    ),
                    items: const [
                      DropdownMenuItem(value: 'id', child: Text('Indonesian (ID)')),
                      DropdownMenuItem(value: 'en', child: Text('English (EN)')),
                      DropdownMenuItem(value: 'all', child: Text('Multi / Other')),
                    ],
                    onChanged: (val) {
                      if (val != null) setDialogState(() => selectedLocale = val);
                    },
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogCtx),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () async {
                  final name = nameController.text.trim();
                  var domain = domainController.text.trim();
                  if (name.isEmpty || domain.isEmpty) return;

                  domain = domain.replaceAll('https://', '').replaceAll('http://', '').replaceAll('/', '');

                  final id = 'custom_${DateTime.now().millisecondsSinceEpoch}';
                  final config = CustomSourceConfig(
                    id: id,
                    name: name,
                    domain: domain,
                    locale: selectedLocale,
                    type: selectedType,
                  );

                  await ParserRegistry.instance.addCustomSource(config);
                  final newParser = ParserRegistry.instance.getParser(id);
                  if (newParser != null) {
                    ref.read(activeParserProvider.notifier).state = newParser;
                  }

                  if (dialogCtx.mounted) {
                    Navigator.pop(dialogCtx);
                  }
                  if (mounted) {
                    Navigator.pop(context);
                  }
                },
                child: const Text('Add Source'),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _exportParser(String id) async {
    final json = await ParserRegistry.instance.exportParserToJson(id);
    if (json != null) {
      await Clipboard.setData(ClipboardData(text: json));
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Parser JSON disalin ke clipboard!'),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  void _showImportParserDialog() {
    final textController = TextEditingController();
    final urlController = TextEditingController();
    int activeTab = 0;
    String? validationMessage;
    CustomSourceConfig? parsedConfig;
    bool isFetching = false;

    showDialog(
      context: context,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (innerCtx, setDialogState) {
          void validateInput(String raw) {
            if (raw.trim().isEmpty) {
              setDialogState(() {
                validationMessage = null;
                parsedConfig = null;
              });
              return;
            }
            try {
              final cfg = ParserImporter.fromJsonString(raw);
              setDialogState(() {
                parsedConfig = cfg;
                validationMessage = null;
              });
            } catch (e) {
              setDialogState(() {
                parsedConfig = null;
                validationMessage = e.toString().replaceFirst('FormatException: ', '');
              });
            }
          }

          return AlertDialog(
            title: const Text('Import Manga Parser', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            content: SizedBox(
              width: double.maxFinite,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: ChoiceChip(
                            label: const Center(child: Text('Paste JSON', style: TextStyle(fontSize: 12))),
                            selected: activeTab == 0,
                            onSelected: (_) => setDialogState(() => activeTab = 0),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: ChoiceChip(
                            label: const Center(child: Text('Import URL', style: TextStyle(fontSize: 12))),
                            selected: activeTab == 1,
                            onSelected: (_) => setDialogState(() => activeTab = 1),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    if (activeTab == 0) ...[
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Parser JSON Spec', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                          Row(
                            children: [
                              TextButton(
                                style: TextButton.styleFrom(padding: EdgeInsets.zero, visualDensity: VisualDensity.compact),
                                onPressed: () async {
                                  final data = await Clipboard.getData(Clipboard.kTextPlain);
                                  if (data?.text != null) {
                                    textController.text = data!.text!;
                                    validateInput(data.text!);
                                  }
                                },
                                child: const Text('Paste', style: TextStyle(fontSize: 11, color: Color(0xFF00F0FF))),
                              ),
                              const SizedBox(width: 6),
                              PopupMenuButton<String>(
                                tooltip: 'Load Template',
                                child: const Text('Template ▾', style: TextStyle(fontSize: 11, color: Colors.grey)),
                                onSelected: (val) {
                                  final tpl = val == 'html'
                                      ? ParserImporter.sampleHtmlTemplate
                                      : ParserImporter.sampleRestTemplate;
                                  textController.text = tpl;
                                  validateInput(tpl);
                                },
                                itemBuilder: (_) => const [
                                  PopupMenuItem(value: 'html', child: Text('Template HTML Scraper', style: TextStyle(fontSize: 12))),
                                  PopupMenuItem(value: 'rest', child: Text('Template REST API', style: TextStyle(fontSize: 12))),
                                ],
                              ),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      TextField(
                        controller: textController,
                        maxLines: 8,
                        minLines: 4,
                        style: const TextStyle(fontSize: 11, fontFamily: 'monospace'),
                        decoration: const InputDecoration(
                          hintText: 'Paste kode JSON parser di sini...',
                          hintStyle: TextStyle(fontSize: 11),
                          isDense: true,
                          border: OutlineInputBorder(),
                        ),
                        onChanged: validateInput,
                      ),
                    ] else ...[
                      const Text('URL File Parser (.json)', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                      const SizedBox(height: 4),
                      TextField(
                        controller: urlController,
                        decoration: const InputDecoration(
                          hintText: 'https://raw.githubusercontent.com/.../parser.json',
                          hintStyle: TextStyle(fontSize: 11),
                          isDense: true,
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 8),
                      OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size.fromHeight(36),
                          side: const BorderSide(color: Color(0xFF00F0FF)),
                        ),
                        icon: isFetching
                            ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2))
                            : const Icon(Icons.cloud_download_outlined, size: 16, color: Color(0xFF00F0FF)),
                        label: Text(
                          isFetching ? 'Mengunduh...' : 'Unduh & Validasi Parser',
                          style: const TextStyle(fontSize: 12, color: Color(0xFF00F0FF)),
                        ),
                        onPressed: isFetching
                            ? null
                            : () async {
                                final url = urlController.text.trim();
                                if (url.isEmpty) return;
                                setDialogState(() => isFetching = true);
                                try {
                                  final cfg = await ParserImporter.fetchFromUrl(url);
                                  textController.text = ParserImporter.exportToJson(cfg);
                                  setDialogState(() {
                                    parsedConfig = cfg;
                                    validationMessage = null;
                                    isFetching = false;
                                  });
                                } catch (e) {
                                  setDialogState(() {
                                    parsedConfig = null;
                                    validationMessage = 'Gagal unduh: ${e.toString()}';
                                    isFetching = false;
                                  });
                                }
                              },
                      ),
                    ],
                    const SizedBox(height: 12),
                    if (parsedConfig != null)
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.green.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.green.shade600),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Icon(Icons.check_circle, color: Colors.green, size: 16),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: Text(
                                    parsedConfig!.name,
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                                  decoration: BoxDecoration(
                                    color: Colors.green.shade800,
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    parsedConfig!.type.toUpperCase(),
                                    style: const TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Colors.white),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Domain: ${parsedConfig!.domain} • Bahasa: ${parsedConfig!.locale.toUpperCase()}',
                              style: const TextStyle(fontSize: 11, color: Colors.grey),
                            ),
                          ],
                        ),
                      )
                    else if (validationMessage != null)
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.red.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.red.shade400),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.error_outline, color: Colors.redAccent, size: 16),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                validationMessage!,
                                style: const TextStyle(fontSize: 11, color: Colors.redAccent),
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogCtx),
                child: const Text('Batal'),
              ),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF00F0FF),
                  foregroundColor: Colors.black,
                ),
                icon: const Icon(Icons.download_done, size: 16),
                label: const Text('Pasang Parser', style: TextStyle(fontWeight: FontWeight.bold)),
                onPressed: parsedConfig == null
                    ? null
                    : () async {
                        final config = parsedConfig!;
                        await ParserRegistry.instance.addCustomSource(config);
                        final newParser = ParserRegistry.instance.getParser(config.id);
                        if (newParser != null) {
                          ref.read(selectedCategoryProvider.notifier).state = 'All';
                          ref.read(selectedGenreProvider.notifier).state = 'All';
                          ref.read(activeParserProvider.notifier).state = newParser;
                        }
                        if (dialogCtx.mounted) {
                          Navigator.pop(dialogCtx);
                        }
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Parser "${config.name}" berhasil dipasang!'),
                              backgroundColor: Colors.green,
                              duration: const Duration(seconds: 2),
                            ),
                          );
                        }
                      },
              ),
            ],
          );
        },
      ),
    );
  }

  void _showSourcePicker() {
    final parsers = ParserRegistry.instance.allParsers;
    final activeParser = ref.read(activeParserProvider);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Pilih Sumber Komik',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      Row(
                        children: [
                          IconButton(
                            icon: const Icon(Icons.file_download_outlined, color: Color(0xFF00F0FF)),
                            tooltip: 'Import Parser',
                            onPressed: () {
                              Navigator.pop(ctx);
                              _showImportParserDialog();
                            },
                          ),
                          IconButton(
                            icon: const Icon(Icons.add_circle_outline, color: Color(0xFF00F0FF)),
                            tooltip: 'Add Custom Source',
                            onPressed: () {
                              Navigator.pop(ctx);
                              _showAddSourceDialog();
                            },
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const Divider(),
                Flexible(
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: parsers.length,
                    itemBuilder: (context, index) {
                      final parser = parsers[index];
                      final isSelected = parser.id == activeParser.id;
                      final isCustom = parser.id.startsWith('custom_');

                      return ListTile(
                        leading: CircleAvatar(
                          backgroundColor: isSelected
                              ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.2)
                              : Theme.of(context).colorScheme.surfaceContainerHighest,
                          child: Text(
                            parser.locale.toUpperCase(),
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: isSelected ? Theme.of(context).colorScheme.primary : null,
                            ),
                          ),
                        ),
                        title: Row(
                          children: [
                            Flexible(
                              child: Text(
                                parser.name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                ),
                              ),
                            ),
                            if (isCustom) ...[
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                                decoration: BoxDecoration(
                                  color: Colors.amber.withValues(alpha: 0.2),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: const Text('CUSTOM', style: TextStyle(fontSize: 9, color: Colors.amber, fontWeight: FontWeight.bold)),
                              ),
                            ],
                          ],
                        ),
                        subtitle: Text(parser.domain, style: const TextStyle(fontSize: 12)),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (isSelected) ...[
                              Icon(Icons.check_circle, color: Theme.of(context).colorScheme.primary, size: 20),
                              const SizedBox(width: 4),
                            ],
                            if (isCustom)
                              PopupMenuButton<String>(
                                icon: const Icon(Icons.more_vert, size: 20),
                                tooltip: 'Opsi Parser',
                                onSelected: (value) async {
                                  if (value == 'edit') {
                                    _showEditDomainDialog(parser);
                                  } else if (value == 'export') {
                                    _exportParser(parser.id);
                                  } else if (value == 'delete') {
                                    await ParserRegistry.instance.removeCustomSource(parser.id);
                                    if (ref.read(activeParserProvider).id == parser.id) {
                                      ref.read(activeParserProvider.notifier).state = ParserRegistry.instance.defaultParser;
                                    }
                                    if (ctx.mounted) {
                                      Navigator.pop(ctx);
                                    }
                                  }
                                },
                                itemBuilder: (context) => [
                                  const PopupMenuItem(
                                    value: 'edit',
                                    child: Row(
                                      children: [
                                        Icon(Icons.edit_outlined, size: 18),
                                        SizedBox(width: 8),
                                        Text('Edit Domain'),
                                      ],
                                    ),
                                  ),
                                  const PopupMenuItem(
                                    value: 'export',
                                    child: Row(
                                      children: [
                                        Icon(Icons.file_upload_outlined, size: 18, color: Color(0xFF00F0FF)),
                                        SizedBox(width: 8),
                                        Text('Export JSON'),
                                      ],
                                    ),
                                  ),
                                  const PopupMenuItem(
                                    value: 'delete',
                                    child: Row(
                                      children: [
                                        Icon(Icons.delete_outline, size: 18, color: Colors.redAccent),
                                        SizedBox(width: 8),
                                        Text('Hapus Source', style: TextStyle(color: Colors.redAccent)),
                                      ],
                                    ),
                                  ),
                                ],
                              )
                            else
                              IconButton(
                                icon: const Icon(Icons.edit_outlined, size: 18),
                                tooltip: 'Edit Domain',
                                onPressed: () => _showEditDomainDialog(parser),
                              ),
                          ],
                        ),
                        onTap: () {
                          ref.read(selectedCategoryProvider.notifier).state = 'All';
                          ref.read(selectedGenreProvider.notifier).state = 'All';
                          ref.read(activeParserProvider.notifier).state = parser;
                          Navigator.pop(ctx);
                        },
                      );
                    },
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                  child: Column(
                    children: [
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          minimumSize: const Size.fromHeight(44),
                          backgroundColor: const Color(0xFF00F0FF),
                          foregroundColor: Colors.black,
                        ),
                        icon: const Icon(Icons.file_download_outlined, color: Colors.black),
                        label: const Text('Import Parser (.json / URL)', style: TextStyle(fontWeight: FontWeight.bold)),
                        onPressed: () {
                          Navigator.pop(ctx);
                          _showImportParserDialog();
                        },
                      ),
                      const SizedBox(height: 8),
                      OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size.fromHeight(40),
                          side: BorderSide(color: Colors.grey.shade700),
                        ),
                        icon: const Icon(Icons.add, size: 18, color: Colors.grey),
                        label: const Text('Tambah Manual Website (Template)', style: TextStyle(color: Colors.grey)),
                        onPressed: () {
                          Navigator.pop(ctx);
                          _showAddSourceDialog();
                        },
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showFilterBottomSheet(MangaParser parser) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (bContext) => Consumer(
        builder: (ctx, innerRef, _) {
          final tempCat = innerRef.watch(selectedCategoryProvider);
          final tempGenres = innerRef.watch(selectedGenresProvider);
          final legacyGenre = innerRef.watch(selectedGenreProvider);
          final activeGenres = tempGenres.isNotEmpty
              ? tempGenres
              : (legacyGenre != 'All' ? {legacyGenre} : <String>{});

          return DraggableScrollableSheet(
            initialChildSize: 0.7,
            minChildSize: 0.4,
            maxChildSize: 0.9,
            expand: false,
            builder: (_, scrollController) => Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                children: [
                  const SizedBox(height: 12),
                  Container(
                    width: 36,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade600,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Filter Bacaan',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      TextButton.icon(
                        icon: const Icon(Icons.refresh, size: 16),
                        label: const Text('Reset'),
                        onPressed: () {
                          innerRef.read(selectedCategoryProvider.notifier).state = 'All';
                          innerRef.read(selectedGenreProvider.notifier).state = 'All';
                          innerRef.read(selectedGenresProvider.notifier).state = {};
                        },
                      ),
                    ],
                  ),
                  const Divider(),
                  Expanded(
                    child: ListView(
                      controller: scrollController,
                      children: [
                        const SizedBox(height: 8),
                        const Text(
                          'Kategori / Format',
                          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: parser.availableCategories.map((cat) {
                            final isSel = tempCat.toLowerCase() == cat.toLowerCase();
                            return ChoiceChip(
                              label: Text(cat == 'All' ? 'Semua' : cat),
                              selected: isSel,
                              selectedColor: Theme.of(context).colorScheme.primary.withValues(alpha: 0.3),
                              labelStyle: TextStyle(
                                color: isSel ? Theme.of(context).colorScheme.primary : null,
                                fontWeight: isSel ? FontWeight.bold : FontWeight.normal,
                              ),
                              side: BorderSide(
                                color: isSel
                                    ? Theme.of(context).colorScheme.primary
                                    : Theme.of(context).dividerColor,
                              ),
                              onSelected: (_) {
                                innerRef.read(selectedCategoryProvider.notifier).state = cat;
                              },
                            );
                          }).toList(),
                        ),
                        const SizedBox(height: 20),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'Genre',
                              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
                            ),
                            if (activeGenres.isNotEmpty)
                              Text(
                                '${activeGenres.length} genre dipilih',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Theme.of(context).colorScheme.primary,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: parser.availableGenres.map((g) {
                            final isAll = g.toLowerCase() == 'all';
                            final isSel = isAll
                                ? activeGenres.isEmpty
                                : activeGenres.any((tg) => tg.toLowerCase() == g.toLowerCase());
                            return FilterChip(
                              showCheckmark: !isAll,
                              label: Text(isAll ? 'Semua Genre' : g),
                              selected: isSel,
                              selectedColor: Theme.of(context).colorScheme.primary.withValues(alpha: 0.25),
                              labelStyle: TextStyle(
                                color: isSel ? Theme.of(context).colorScheme.primary : null,
                                fontWeight: isSel ? FontWeight.bold : FontWeight.normal,
                              ),
                              side: BorderSide(
                                color: isSel
                                    ? Theme.of(context).colorScheme.primary
                                    : Theme.of(context).dividerColor,
                              ),
                              onSelected: (_) {
                                if (isAll) {
                                  innerRef.read(selectedGenresProvider.notifier).state = {};
                                  innerRef.read(selectedGenreProvider.notifier).state = 'All';
                                } else {
                                  final next = Set<String>.from(activeGenres);
                                  if (isSel) {
                                    next.removeWhere((tg) => tg.toLowerCase() == g.toLowerCase());
                                  } else {
                                    next.add(g);
                                  }
                                  innerRef.read(selectedGenresProvider.notifier).state = next;
                                  innerRef.read(selectedGenreProvider.notifier).state =
                                      next.isEmpty ? 'All' : next.first;
                                }
                              },
                            );
                          }).toList(),
                        ),
                        const SizedBox(height: 24),
                      ],
                    ),
                  ),
                  SafeArea(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          minimumSize: const Size.fromHeight(48),
                          backgroundColor: Theme.of(context).colorScheme.primary,
                          foregroundColor: Colors.black,
                        ),
                        onPressed: () => Navigator.pop(bContext),
                        child: const Text('Terapkan Filter', style: TextStyle(fontWeight: FontWeight.bold)),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildFilterBar(MangaParser parser) {
    final selectedCat = ref.watch(selectedCategoryProvider);
    final selectedGenres = ref.watch(selectedGenresProvider);
    final legacyGenre = ref.watch(selectedGenreProvider);
    final activeGenres = selectedGenres.isNotEmpty
        ? selectedGenres.toList()
        : (legacyGenre != 'All' ? [legacyGenre] : <String>[]);
    final hasActiveFilter = selectedCat != 'All' || activeGenres.isNotEmpty;

    return Container(
      height: 48,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        border: Border(
          bottom: BorderSide(
            color: Theme.of(context).dividerColor.withValues(alpha: 0.2),
          ),
        ),
      ),
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
            child: ActionChip(
              avatar: Icon(
                Icons.filter_list,
                size: 16,
                color: hasActiveFilter ? Theme.of(context).colorScheme.primary : null,
              ),
              label: Text(
                activeGenres.isNotEmpty ? 'Filter (${activeGenres.length})' : 'Filter',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: hasActiveFilter ? FontWeight.bold : FontWeight.normal,
                  color: hasActiveFilter ? Theme.of(context).colorScheme.primary : null,
                ),
              ),
              backgroundColor: hasActiveFilter
                  ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.15)
                  : null,
              side: BorderSide(
                color: hasActiveFilter
                    ? Theme.of(context).colorScheme.primary
                    : Theme.of(context).dividerColor,
              ),
              onPressed: () => _showFilterBottomSheet(parser),
            ),
          ),
          ...activeGenres.map((g) {
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
              child: InputChip(
                label: Text(
                  g,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
                deleteIconColor: Theme.of(context).colorScheme.primary,
                backgroundColor: Theme.of(context).colorScheme.primary.withValues(alpha: 0.2),
                side: BorderSide(color: Theme.of(context).colorScheme.primary),
                onDeleted: () {
                  final next = Set<String>.from(ref.read(selectedGenresProvider));
                  next.removeWhere((item) => item.toLowerCase() == g.toLowerCase());
                  ref.read(selectedGenresProvider.notifier).state = next;
                  ref.read(selectedGenreProvider.notifier).state =
                      next.isEmpty ? 'All' : next.first;
                },
                onPressed: () => _showFilterBottomSheet(parser),
              ),
            );
          }),
          ...parser.availableCategories.map((cat) {
            final isSelected = selectedCat.toLowerCase() == cat.toLowerCase();
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
              child: ChoiceChip(
                label: Text(
                  cat == 'All' ? 'Semua' : cat,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                    color: isSelected ? Theme.of(context).colorScheme.primary : null,
                  ),
                ),
                selected: isSelected,
                selectedColor: Theme.of(context).colorScheme.primary.withValues(alpha: 0.2),
                side: BorderSide(
                  color: isSelected
                      ? Theme.of(context).colorScheme.primary
                      : Theme.of(context).dividerColor,
                ),
                onSelected: (_) {
                  ref.read(selectedCategoryProvider.notifier).state = cat;
                },
              ),
            );
          }),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final activeParser = ref.watch(activeParserProvider);
    final catalogState = ref.watch(catalogProvider);
    final selectedCat = ref.watch(selectedCategoryProvider);
    final selectedGenre = ref.watch(selectedGenreProvider);
    final hasActiveFilter = selectedCat != 'All' || selectedGenre != 'All';

    return Scaffold(
      appBar: AppBar(
        title: _isSearching
            ? TextField(
                controller: _searchController,
                autofocus: true,
                decoration: InputDecoration(
                  hintText: 'Search manga in ${activeParser.name}...',
                  border: InputBorder.none,
                ),
                onSubmitted: (query) {
                  ref.read(searchQueryProvider.notifier).state = query.trim();
                },
              )
            : Row(
                children: [
                  const Text('Kuroku', style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 0.5)),
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: _showSourcePicker,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.15),
                        border: Border.all(color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.4)),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            activeParser.name,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Icon(Icons.arrow_drop_down, size: 14, color: Theme.of(context).colorScheme.primary),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
        actions: [
          IconButton(
            icon: Icon(_isSearching ? Icons.close : Icons.search),
            onPressed: () {
              setState(() {
                if (_isSearching) {
                  _isSearching = false;
                  _searchController.clear();
                  ref.read(searchQueryProvider.notifier).state = '';
                } else {
                  _isSearching = true;
                }
              });
            },
          ),
          IconButton(
            icon: Badge(
              isLabelVisible: hasActiveFilter,
              smallSize: 8,
              child: const Icon(Icons.filter_list_rounded),
            ),
            tooltip: 'Filter Kategori & Genre',
            onPressed: () => _showFilterBottomSheet(activeParser),
          ),
          IconButton(
            icon: const Icon(Icons.tune),
            tooltip: 'Sources',
            onPressed: _showSourcePicker,
          ),
        ],
      ),
      body: Column(
        children: [
          _buildFilterBar(activeParser),
          Expanded(
            child: RefreshIndicator(
              onRefresh: () async {
                await ref.read(catalogProvider.notifier).loadFirstPage();
              },
              child: _buildBody(catalogState),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBody(CatalogState state) {
    if (state.isLoading && state.items.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    if (state.error != null && state.items.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.cloud_off, size: 48, color: Colors.redAccent),
              const SizedBox(height: 12),
              Text(
                'Failed to load manga catalog',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              const SizedBox(height: 6),
              Text(
                state.error!,
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey.shade400, fontSize: 12),
              ),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: () => ref.read(catalogProvider.notifier).loadFirstPage(),
                icon: const Icon(Icons.refresh),
                label: const Text('Try Again'),
              ),
            ],
          ),
        ),
      );
    }

    if (state.items.isEmpty) {
      return const Center(
        child: Text('No manga found. Try searching or change source.'),
      );
    }

    return GridView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.all(12),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 0.65,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
      ),
      itemCount: state.items.length + (state.hasMore ? 1 : 0),
      itemBuilder: (context, index) {
        if (index == state.items.length) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: CircularProgressIndicator(),
            ),
          );
        }

        final manga = state.items[index];
        return _buildMangaCard(context, manga);
      },
    );
  }

  Widget _buildMangaCard(BuildContext context, Manga manga) {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => MangaDetailScreen(manga: manga),
          ),
        );
      },
      child: Card(
        clipBehavior: Clip.antiAlias,
        child: Stack(
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: manga.coverUrl.isNotEmpty
                      ? ExtendedImage.network(
                          manga.coverUrl,
                          fit: BoxFit.cover,
                          headers: ref.read(activeParserProvider).headers,
                          cache: true,
                          loadStateChanged: (state) {
                            if (state.extendedImageLoadState == LoadState.loading) {
                              return Container(
                                color: Colors.black26,
                                child: const Center(
                                  child: SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(strokeWidth: 2),
                                  ),
                                ),
                              );
                            }
                            if (state.extendedImageLoadState == LoadState.failed) {
                              return Container(
                                color: Colors.black26,
                                child: const Center(
                                  child: Icon(Icons.broken_image_outlined, color: Colors.white38, size: 28),
                                ),
                              );
                            }
                            return null;
                          },
                        )
                      : Container(
                          color: Colors.black26,
                          child: const Center(
                            child: Icon(Icons.broken_image_outlined, color: Colors.white38, size: 28),
                          ),
                        ),
                ),
                Container(
                  padding: const EdgeInsets.all(8),
                  child: Text(
                    manga.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      height: 1.2,
                    ),
                  ),
                ),
              ],
            ),
            // Gradient Shadow for text readability
            Positioned(
              top: 8,
              left: 8,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.black87,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  manga.sourceId.toUpperCase(),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 9,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
