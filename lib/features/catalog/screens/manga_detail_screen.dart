import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:extended_image/extended_image.dart';
import '../../../core/database/app_database.dart';
import '../../../core/database/models/manga.dart';
import '../../../core/database/models/chapter.dart';
import '../../../core/parser/parser_registry.dart';
import '../../../core/download/download_manager.dart';
import '../../library/providers/library_provider.dart';
import '../../reader/providers/reader_provider.dart';
import '../../reader/screens/manga_reader_screen.dart';

class MangaDetailScreen extends ConsumerStatefulWidget {
  final Manga manga;

  const MangaDetailScreen({super.key, required this.manga});

  @override
  ConsumerState<MangaDetailScreen> createState() => _MangaDetailScreenState();
}

class _MangaDetailScreenState extends ConsumerState<MangaDetailScreen> {
  late Manga _currentManga;
  List<MangaChapter> _chapters = [];
  bool _isLoading = true;
  bool _isFavorite = false;
  bool _isSynopsisExpanded = false;
  File? _localCoverFile;

  // Chapter list drawer state
  bool _isAscending = false;
  String _chapterSearchQuery = '';
  bool _isSearchActive = false;
  bool _filterDownloadedOnly = false;
  final TextEditingController _searchController = TextEditingController();

  static const List<String> _months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
  ];

  @override
  void initState() {
    super.initState();
    _currentManga = widget.manga;
    _initScreenData();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _initScreenData() async {
    await _loadLocalCache();
    await _checkLocalCover();
    _fetchRemoteData();
  }

  Future<void> _checkLocalCover() async {
    final file = await DownloadManager.instance.getLocalCoverFile(widget.manga.id);
    if (mounted && file != null) {
      setState(() {
        _localCoverFile = file;
      });
    }
  }

  Future<void> _loadLocalCache() async {
    final savedManga = await AppDatabase.instance.getManga(widget.manga.id);
    final savedChapters = await AppDatabase.instance.getChapters(widget.manga.id);

    if (mounted) {
      setState(() {
        if (savedManga != null) {
          _isFavorite = savedManga.isFavorite;
          _currentManga = savedManga;
        }
        if (savedChapters.isNotEmpty) {
          _chapters = savedChapters;
          _isLoading = false;
        }
      });
    }
  }

  Future<void> _fetchRemoteData() async {
    try {
      final parser = ParserRegistry.instance.getParser(widget.manga.sourceId) ??
          ParserRegistry.instance.defaultParser;

      final detailedManga = await parser.getDetails(_currentManga);
      final chapters = await parser.getChapters(detailedManga);

      if (!mounted) return;

      if (chapters.isNotEmpty) {
        final savedChapters = await AppDatabase.instance.getChapters(widget.manga.id);
        final readMap = {for (var c in savedChapters) c.id: c};

        final mergedChapters = chapters.map((c) {
          final saved = readMap[c.id];
          if (saved != null) {
            return c.copyWith(
              isRead: saved.isRead,
              lastReadPage: saved.lastReadPage,
            );
          }
          return c;
        }).toList();

        setState(() {
          _currentManga = detailedManga.copyWith(
            isFavorite: _isFavorite,
            description: (detailedManga.description != null && detailedManga.description!.trim().isNotEmpty)
                ? detailedManga.description
                : _currentManga.description,
            author: detailedManga.author ?? _currentManga.author,
            artist: detailedManga.artist ?? _currentManga.artist,
            altTitle: detailedManga.altTitle ?? _currentManga.altTitle,
            status: detailedManga.status,
          );
          _chapters = mergedChapters;
          _isLoading = false;
        });

        await AppDatabase.instance.upsertManga(_currentManga);
        await AppDatabase.instance.upsertChapters(_chapters);
      } else {
        if (_chapters.isEmpty) {
          final savedChapters = await AppDatabase.instance.getChapters(widget.manga.id);
          if (savedChapters.isNotEmpty) {
            setState(() {
              _chapters = savedChapters;
            });
          }
        }
        setState(() {
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        if (_chapters.isEmpty) {
          final savedChapters = await AppDatabase.instance.getChapters(widget.manga.id);
          if (savedChapters.isNotEmpty) {
            setState(() {
              _chapters = savedChapters;
            });
          }
        }
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _toggleFavorite() async {
    final newStatus = await ref.read(libraryProvider.notifier).toggleFavorite(_currentManga);
    if (mounted) {
      setState(() {
        _isFavorite = newStatus;
        _currentManga = _currentManga.copyWith(isFavorite: newStatus);
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(newStatus ? 'Ditambahkan ke Library' : 'Dihapus dari Library'),
          duration: const Duration(seconds: 1),
        ),
      );
    }
  }

  MangaChapter? get _resumeChapter {
    if (_chapters.isEmpty) return null;
    final inProgress = _chapters.where((c) => c.lastReadPage > 0 && !c.isRead).toList();
    if (inProgress.isNotEmpty) return inProgress.first;
    final read = _chapters.where((c) => c.isRead).toList();
    if (read.isNotEmpty) {
      final lastReadIndex = _chapters.indexOf(read.first);
      if (lastReadIndex > 0) return _chapters[lastReadIndex - 1];
      return read.first;
    }
    final downloaded = _chapters.where((c) => DownloadManager.instance.isDownloaded(c.id)).toList();
    if (downloaded.isNotEmpty) return downloaded.last;
    return _chapters.last;
  }

  Future<void> _downloadChapter(MangaChapter chapter) async {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Mengunduh ${chapter.title}...'),
        duration: const Duration(seconds: 1),
      ),
    );

    try {
      await DownloadManager.instance.downloadChapter(
        manga: _currentManga,
        chapter: chapter,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${chapter.title} berhasil diunduh'),
            backgroundColor: Colors.green.shade800,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Download gagal: $e'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  void _confirmDeleteDownload(MangaChapter chapter) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Hapus Unduhan'),
        content: Text('Hapus file offline untuk ${chapter.title}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () async {
              Navigator.pop(ctx);
              await DownloadManager.instance.deleteDownload(chapter);
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Unduhan dihapus')),
                );
              }
            },
            child: const Text('Hapus'),
          ),
        ],
      ),
    );
  }

  Future<void> _downloadAllChapters() async {
    final unDownloaded = _chapters.where((c) => !DownloadManager.instance.isDownloaded(c.id)).toList();
    if (unDownloaded.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Semua chapter sudah terunduh')),
      );
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Memulai unduh ${unDownloaded.length} chapter...'),
      ),
    );

    for (final ch in unDownloaded) {
      if (!mounted) break;
      try {
        await DownloadManager.instance.downloadChapter(
          manga: _currentManga,
          chapter: ch,
        );
      } catch (_) {}
    }
  }

  void _openReader(MangaChapter chapter, [int initialPage = 0]) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => MangaReaderScreen(
          args: ReaderArgs(
            manga: _currentManga,
            chapter: chapter,
            initialPage: initialPage,
          ),
        ),
      ),
    ).then((_) {
      _initScreenData();
    });
  }

  String _formatDate(DateTime? dt) {
    if (dt == null) return '';
    return '${_months[dt.month - 1]} ${dt.day}, ${dt.year}';
  }

  String _cleanChapterTitle(String rawTitle, double number) {
    final numStr = number.toString().replaceAll(RegExp(r'\.0$'), '');
    final match = RegExp(r'^Chapter\s+[0-9.]+\s*[:\-–]\s*(.+)$', caseSensitive: false).firstMatch(rawTitle);
    if (match != null && match.group(1) != null) {
      return match.group(1)!.trim();
    }
    if (rawTitle.toLowerCase().trim() == 'chapter $numStr') {
      return 'Chapter $numStr';
    }
    return rawTitle;
  }

  List<MangaChapter> get _filteredChapters {
    var list = List<MangaChapter>.from(_chapters);

    if (_filterDownloadedOnly) {
      list = list.where((c) => DownloadManager.instance.isDownloaded(c.id)).toList();
    }

    if (_chapterSearchQuery.trim().isNotEmpty) {
      final q = _chapterSearchQuery.trim().toLowerCase();
      list = list.where((c) =>
        c.title.toLowerCase().contains(q) ||
        c.number.toString().contains(q)
      ).toList();
    }

    if (_isAscending) {
      list.sort((a, b) => a.number.compareTo(b.number));
    } else {
      list.sort((a, b) => b.number.compareTo(a.number));
    }

    return list;
  }

  Widget _buildCoverImage({required double width, required double height, Map<String, String>? headers}) {
    if (_localCoverFile != null) {
      return ExtendedImage.file(
        _localCoverFile!,
        width: width,
        height: height,
        fit: BoxFit.cover,
      );
    }
    if (_currentManga.coverUrl.isNotEmpty) {
      return ExtendedImage.network(
        _currentManga.coverUrl,
        width: width,
        height: height,
        fit: BoxFit.cover,
        headers: headers,
        cache: true,
      );
    }
    return Container(
      width: width,
      height: height,
      color: Colors.black38,
      child: const Center(
        child: Icon(Icons.broken_image_outlined, color: Colors.white38),
      ),
    );
  }

  String _formatSynopsis(String raw) {
    var text = raw
        .replaceAll('&quot;', '"')
        .replaceAll('&#39;', "'")
        .replaceAll('&rsquo;', "'")
        .replaceAll('&lsquo;', "'")
        .replaceAll('&amp;', '&')
        .replaceAll('&#x20;', ' ')
        .replaceAll('&nbsp;', ' ')
        .replaceAll(RegExp(r'<br\s*/?>', caseSensitive: false), '\n')
        .replaceAll(RegExp(r'<[^>]*>'), '')
        .trim();

    text = text.replaceAll(RegExp(r'\r\n|\r'), '\n');
    return text;
  }

  Widget _buildSynopsisSection() {
    final rawDesc = _currentManga.description;
    if (rawDesc == null || rawDesc.trim().isEmpty) return const SizedBox.shrink();

    final formatted = _formatSynopsis(rawDesc);
    final isLong = formatted.length > 150 || formatted.contains('\n');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Synopsis',
          style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.white),
        ),
        const SizedBox(height: 6),
        Text(
          formatted,
          maxLines: _isSynopsisExpanded ? null : 3,
          overflow: _isSynopsisExpanded ? TextOverflow.visible : TextOverflow.ellipsis,
          style: const TextStyle(
            fontSize: 12.5,
            height: 1.45,
            color: Colors.white70,
            letterSpacing: 0.2,
          ),
        ),
        if (isLong) ...[
          const SizedBox(height: 4),
          InkWell(
            onTap: () {
              setState(() {
                _isSynopsisExpanded = !_isSynopsisExpanded;
              });
            },
            borderRadius: BorderRadius.circular(4),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    _isSynopsisExpanded ? 'Lebih Sedikit' : 'Selengkapnya',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFFA8C7FA),
                    ),
                  ),
                  const SizedBox(width: 4),
                  Icon(
                    _isSynopsisExpanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                    size: 16,
                    color: const Color(0xFFA8C7FA),
                  ),
                ],
              ),
            ),
          ),
        ],
        const SizedBox(height: 16),
      ],
    );
  }

  String _getTranslationLabel() {
    final s = _currentManga.sourceId.toLowerCase();
    if (s.contains('shinigami') || s.contains('komiku')) {
      return '🇮🇩 Indonesia';
    }
    if (s.contains('weeb') || s.contains('pill')) {
      return '🇬🇧 English';
    }
    return _currentManga.sourceId.toUpperCase();
  }

  Widget _buildMetadataCard() {
    final readCount = _chapters.where((c) => c.isRead).length;
    final totalCount = _chapters.length;
    final progressPercent = totalCount > 0 ? (readCount / totalCount * 100).toInt() : 0;
    final progressFraction = totalCount > 0 ? (readCount / totalCount) : 0.0;

    final sourceDisplay = _currentManga.sourceId.isNotEmpty
        ? '${_currentManga.sourceId[0].toUpperCase()}${_currentManga.sourceId.substring(1)}'
        : 'Shinigami';

    final authorDisplay = _currentManga.author?.isNotEmpty == true
        ? _currentManga.author!
        : (_currentManga.artist?.isNotEmpty == true ? _currentManga.artist! : '-');

    final stateDisplay = _currentManga.status == MangaStatus.completed ? 'Completed' : 'Ongoing';

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF1E2026),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white10),
      ),
      child: Column(
        children: [
          // Row 1: Source & Author
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Row(
                  children: [
                    const Text('Source', style: TextStyle(fontSize: 12, color: Colors.grey)),
                    const SizedBox(width: 10),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.white12,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        sourceDisplay.substring(0, 1),
                        style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.white),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Flexible(
                      child: Text(
                        sourceDisplay,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.white),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Row(
                  children: [
                    const Text('Author', style: TextStyle(fontSize: 12, color: Colors.grey)),
                    const SizedBox(width: 10),
                    Flexible(
                      child: Text(
                        authorDisplay,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFFA8C7FA),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Row 2: Translation & State
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Row(
                  children: [
                    const Text('Translation', style: TextStyle(fontSize: 12, color: Colors.grey)),
                    const SizedBox(width: 10),
                    Flexible(
                      child: Text(
                        _getTranslationLabel(),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.white),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Row(
                  children: [
                    const Text('State', style: TextStyle(fontSize: 12, color: Colors.grey)),
                    const SizedBox(width: 10),
                    Text(
                      stateDisplay,
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.white),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Row 3: Chapters & Progress
          Row(
            children: [
              const Text('Chapters', style: TextStyle(fontSize: 12, color: Colors.grey)),
              const SizedBox(width: 10),
              Text(
                'Chapter $readCount of $totalCount',
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.white),
              ),
            ],
          ),
          const SizedBox(height: 8),

          // Row 4: Progress Bar
          Row(
            children: [
              const Text('Progress', style: TextStyle(fontSize: 12, color: Colors.grey)),
              const SizedBox(width: 12),
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: progressFraction,
                    minHeight: 8,
                    backgroundColor: Colors.white12,
                    valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFFA8C7FA)),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Text(
                '$progressPercent%',
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white70),
              ),
            ],
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final parser = ParserRegistry.instance.getParser(_currentManga.sourceId);
    final displayedChapters = _filteredChapters;
    final resumeCh = _resumeChapter;

    return Scaffold(
      backgroundColor: const Color(0xFF0D0E11),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.download_for_offline_rounded, color: Color(0xFFA8C7FA)),
            tooltip: 'Download All Chapters',
            onPressed: _downloadAllChapters,
          ),
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
            tooltip: 'Refresh',
            onPressed: () => _fetchRemoteData(),
          ),
        ],
      ),
      body: Stack(
        children: [
          // Background / Scrollable Manga Info Layer
          Positioned.fill(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 380),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header Row: Cover thumbnail + Title & Subtitle + Category Pill
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: _buildCoverImage(
                          width: 105,
                          height: 148,
                          headers: parser?.headers,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _currentManga.title,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                                height: 1.25,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              _currentManga.altTitle?.isNotEmpty == true
                                  ? _currentManga.altTitle!
                                  : (_currentManga.author ?? _currentManga.title),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 12,
                                color: Colors.grey,
                              ),
                            ),
                            const SizedBox(height: 14),

                            // Rounded Category / Library Button (like in the screenshot)
                            InkWell(
                              onTap: _toggleFavorite,
                              borderRadius: BorderRadius.circular(20),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF1E2026),
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(
                                    color: _isFavorite ? const Color(0xFFA8C7FA) : Colors.white24,
                                    width: 1,
                                  ),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      _isFavorite ? Icons.bookmark : Icons.bookmark_border,
                                      size: 16,
                                      color: const Color(0xFFA8C7FA),
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      _isFavorite ? 'In Library' : 'Read later',
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                        color: _isFavorite ? const Color(0xFFA8C7FA) : Colors.white,
                                      ),
                                    ),
                                    const SizedBox(width: 4),
                                    const Icon(Icons.arrow_drop_down, size: 16, color: Colors.grey),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),

                  // Metadata Card
                  _buildMetadataCard(),
                  const SizedBox(height: 18),

                  // Synopsis
                  _buildSynopsisSection(),

                  // Genres
                  if (_currentManga.genres.isNotEmpty) ...[
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: _currentManga.genres.map((g) {
                        return Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(
                            color: const Color(0xFF1E2026),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.white12),
                          ),
                          child: Text(
                            g,
                            style: const TextStyle(fontSize: 11, color: Colors.white70),
                          ),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 16),
                  ],
                ],
              ),
            ),
          ),

          // Bottom Chapter Drawer (Draggable Bottom Sheet)
          DraggableScrollableSheet(
            initialChildSize: 0.42,
            minChildSize: 0.13,
            maxChildSize: 0.94,
            snap: true,
            snapSizes: const [0.13, 0.42, 0.94],
            builder: (context, scrollController) {
              return Container(
                decoration: const BoxDecoration(
                  color: Color(0xFF181B22),
                  borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black87,
                      blurRadius: 16,
                      offset: Offset(0, -4),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    // Centered Drag Handle
                    const SizedBox(height: 10),
                    Center(
                      child: Container(
                        width: 36,
                        height: 4,
                        decoration: BoxDecoration(
                          color: Colors.white24,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),

                    // Drawer Controls & Action Button Bar
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Row(
                        children: [
                          // Left View/Filter Controls
                          IconButton(
                            visualDensity: VisualDensity.compact,
                            icon: Icon(
                              _isAscending ? Icons.arrow_upward_rounded : Icons.arrow_downward_rounded,
                              size: 20,
                              color: _isAscending ? const Color(0xFFA8C7FA) : Colors.white70,
                            ),
                            tooltip: _isAscending ? 'Oldest first' : 'Newest first',
                            onPressed: () {
                              setState(() {
                                _isAscending = !_isAscending;
                              });
                            },
                          ),
                          IconButton(
                            visualDensity: VisualDensity.compact,
                            icon: Icon(
                              _filterDownloadedOnly ? Icons.download_done_rounded : Icons.file_download_outlined,
                              size: 20,
                              color: _filterDownloadedOnly ? const Color(0xFFA8C7FA) : Colors.white70,
                            ),
                            tooltip: 'Filter downloaded chapters',
                            onPressed: () {
                              setState(() {
                                _filterDownloadedOnly = !_filterDownloadedOnly;
                              });
                            },
                          ),
                          IconButton(
                            visualDensity: VisualDensity.compact,
                            icon: Icon(
                              Icons.search_rounded,
                              size: 20,
                              color: _isSearchActive ? const Color(0xFFA8C7FA) : Colors.white70,
                            ),
                            tooltip: 'Search chapters',
                            onPressed: () {
                              setState(() {
                                _isSearchActive = !_isSearchActive;
                                if (!_isSearchActive) {
                                  _chapterSearchQuery = '';
                                  _searchController.clear();
                                }
                              });
                            },
                          ),

                          const Spacer(),

                          // Right Side Action Button: "Continue" (Kotatsu-style split pill button)
                          InkWell(
                            onTap: () {
                              if (resumeCh != null) {
                                _openReader(resumeCh, resumeCh.lastReadPage);
                              } else if (_chapters.isNotEmpty) {
                                _openReader(_chapters.last);
                              }
                            },
                            borderRadius: BorderRadius.circular(20),
                            child: Container(
                              height: 38,
                              padding: const EdgeInsets.symmetric(horizontal: 16),
                              decoration: BoxDecoration(
                                color: const Color(0xFFA8C7FA),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    resumeCh != null && resumeCh.lastReadPage > 0
                                        ? 'Continue'
                                        : (_chapters.any((c) => c.isRead) ? 'Continue' : 'Start'),
                                    style: const TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.black,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Container(
                                    width: 1,
                                    height: 16,
                                    color: Colors.black26,
                                  ),
                                  const SizedBox(width: 6),
                                  const Icon(
                                    Icons.keyboard_arrow_down_rounded,
                                    size: 18,
                                    color: Colors.black,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Quick Search Bar (Collapsible)
                    if (_isSearchActive)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                        child: TextField(
                          controller: _searchController,
                          autofocus: true,
                          style: const TextStyle(fontSize: 13, color: Colors.white),
                          decoration: InputDecoration(
                            hintText: 'Cari chapter...',
                            hintStyle: const TextStyle(fontSize: 12, color: Colors.grey),
                            prefixIcon: const Icon(Icons.search, size: 18, color: Colors.grey),
                            suffixIcon: _chapterSearchQuery.isNotEmpty
                                ? IconButton(
                                    icon: const Icon(Icons.clear, size: 16, color: Colors.grey),
                                    onPressed: () {
                                      setState(() {
                                        _chapterSearchQuery = '';
                                        _searchController.clear();
                                      });
                                    },
                                  )
                                : null,
                            filled: true,
                            fillColor: const Color(0xFF222731),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide: BorderSide.none,
                            ),
                          ),
                          onChanged: (val) {
                            setState(() {
                              _chapterSearchQuery = val;
                            });
                          },
                        ),
                      ),

                    const Divider(height: 16, color: Colors.white10),

                    // Chapter List (Driven by DraggableScrollableSheet controller)
                    Expanded(
                      child: _isLoading && _chapters.isEmpty
                          ? const Center(
                              child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFFA8C7FA)),
                            )
                          : displayedChapters.isEmpty
                              ? Center(
                                  child: Padding(
                                    padding: const EdgeInsets.all(24),
                                    child: Text(
                                      _chapterSearchQuery.isNotEmpty
                                          ? 'Tidak ada chapter yang cocok'
                                          : 'Chapter belum tersedia',
                                      style: const TextStyle(color: Colors.grey, fontSize: 13),
                                    ),
                                  ),
                                )
                              : ListView.separated(
                                  controller: scrollController,
                                  padding: const EdgeInsets.symmetric(vertical: 4),
                                  itemCount: displayedChapters.length,
                                  separatorBuilder: (_, context) => const Divider(height: 1, color: Colors.white10),
                                  itemBuilder: (context, index) {
                                    final ch = displayedChapters[index];
                                    final cleanTitle = _cleanChapterTitle(ch.title, ch.number);
                                    final numStr = ch.number.toString().replaceAll(RegExp(r'\.0$'), '');
                                    final dateStr = _formatDate(ch.uploadDate);
                                    final subtitleStr = dateStr.isNotEmpty
                                        ? '#$numStr • $dateStr'
                                        : '#$numStr';

                                    return ListTile(
                                      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 2),
                                      title: Text(
                                        cleanTitle,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          fontSize: 13.5,
                                          fontWeight: ch.isRead ? FontWeight.normal : FontWeight.w600,
                                          color: ch.isRead ? Colors.grey : Colors.white,
                                        ),
                                      ),
                                      subtitle: Text(
                                        subtitleStr,
                                        style: const TextStyle(
                                          fontSize: 11.5,
                                          color: Colors.grey,
                                        ),
                                      ),
                                      trailing: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          ValueListenableBuilder<Set<String>>(
                                            valueListenable: DownloadManager.instance.downloadedChapterIds,
                                            builder: (context, downloadedIds, _) {
                                              final isDownloaded = downloadedIds.contains(ch.id);
                                              return ValueListenableBuilder<Map<String, double>>(
                                                valueListenable: DownloadManager.instance.activeDownloads,
                                                builder: (context, activeMap, _) {
                                                  final progress = activeMap[ch.id];
                                                  if (progress != null) {
                                                    return SizedBox(
                                                      width: 22,
                                                      height: 22,
                                                      child: Padding(
                                                        padding: const EdgeInsets.all(2),
                                                        child: CircularProgressIndicator(
                                                          value: progress > 0.05 ? progress : null,
                                                          strokeWidth: 2,
                                                          color: const Color(0xFFA8C7FA),
                                                        ),
                                                      ),
                                                    );
                                                  }
                                                  if (isDownloaded) {
                                                    return IconButton(
                                                      visualDensity: VisualDensity.compact,
                                                      icon: const Icon(Icons.download_done_rounded, color: Color(0xFFA8C7FA), size: 20),
                                                      tooltip: 'Unduhan offline - Tap untuk hapus',
                                                      onPressed: () => _confirmDeleteDownload(ch),
                                                    );
                                                  }
                                                  return IconButton(
                                                    visualDensity: VisualDensity.compact,
                                                    icon: const Icon(Icons.download_outlined, size: 20, color: Colors.white60),
                                                    tooltip: 'Unduh chapter untuk offline',
                                                    onPressed: () => _downloadChapter(ch),
                                                  );
                                                },
                                              );
                                            },
                                          ),
                                          if (ch.isRead)
                                            const Padding(
                                              padding: EdgeInsets.only(left: 4),
                                              child: Icon(Icons.check_circle_rounded, size: 16, color: Colors.green),
                                            ),
                                        ],
                                      ),
                                      onTap: () => _openReader(ch, ch.lastReadPage),
                                    );
                                  },
                                ),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}
