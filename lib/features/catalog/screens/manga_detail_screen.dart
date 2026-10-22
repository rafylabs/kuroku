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
  String? _error;
  bool _isFavorite = false;
  bool _isSynopsisExpanded = false;
  File? _localCoverFile;

  @override
  void initState() {
    super.initState();
    _currentManga = widget.manga;
    _initScreenData();
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
          _isLoading = false; // Show local data immediately
        }
      });
    }
  }

  Future<void> _fetchRemoteData() async {
    try {
      final parser = ParserRegistry.instance.getParser(widget.manga.sourceId) ??
          ParserRegistry.instance.defaultParser;

      // 1. Fetch details
      final detailedManga = await parser.getDetails(_currentManga);

      // 2. Fetch chapters
      final chapters = await parser.getChapters(detailedManga);

      if (!mounted) return;

      if (chapters.isNotEmpty) {
        // Check DB read progress for each chapter
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
          );
          _chapters = mergedChapters;
          _isLoading = false;
          _error = null;
        });

        // Save metadata to SQLite
        await AppDatabase.instance.upsertManga(_currentManga);
        await AppDatabase.instance.upsertChapters(_chapters);
      } else {
        // Remote returned empty (e.g. offline / network down)
        // Keep existing local chapters!
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
      // Remote failed (offline)
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
          content: Text(newStatus ? 'Added to Library' : 'Removed from Library'),
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
        content: Text('Downloading ${chapter.title}...'),
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
            content: Text('Downloaded ${chapter.title} for offline reading'),
            backgroundColor: Colors.green.shade800,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Download failed: $e'),
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
        title: const Text('Hapus Download'),
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
                  const SnackBar(content: Text('Download dihapus')),
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
        const SnackBar(content: Text('Semua chapter sudah terdownload')),
      );
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Memulai download ${unDownloaded.length} chapter...'),
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

  Widget _buildBannerBackground(Map<String, String>? headers) {
    if (_localCoverFile != null) {
      return ExtendedImage.file(
        _localCoverFile!,
        fit: BoxFit.cover,
      );
    }
    if (_currentManga.coverUrl.isNotEmpty) {
      return ExtendedImage.network(
        _currentManga.coverUrl,
        fit: BoxFit.cover,
        headers: headers,
        cache: true,
      );
    }
    return Container(color: Colors.black38);
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
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        Text(
          formatted,
          maxLines: _isSynopsisExpanded ? null : 4,
          overflow: _isSynopsisExpanded ? TextOverflow.visible : TextOverflow.ellipsis,
          style: const TextStyle(
            fontSize: 13,
            height: 1.5,
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
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    _isSynopsisExpanded ? 'Lebih Sedikit' : 'Selengkapnya',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Icon(
                    _isSynopsisExpanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                    size: 16,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ],
              ),
            ),
          ),
        ],
        const SizedBox(height: 20),
      ],
    );
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
      // Refresh read status after closing reader
      _initScreenData();
    });
  }

  @override
  Widget build(BuildContext context) {
    final parser = ParserRegistry.instance.getParser(_currentManga.sourceId);

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 280,
            pinned: true,
            flexibleSpace: FlexibleSpaceBar(
              background: Stack(
                fit: StackFit.expand,
                children: [
                  _buildBannerBackground(parser?.headers),
                  Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.black.withValues(alpha: 0.3),
                          Theme.of(context).scaffoldBackgroundColor.withValues(alpha: 0.9),
                          Theme.of(context).scaffoldBackgroundColor,
                        ],
                        stops: const [0.0, 0.7, 1.0],
                      ),
                    ),
                  ),
                  Positioned(
                    bottom: 16,
                    left: 16,
                    right: 16,
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: _buildCoverImage(
                            width: 100,
                            height: 140,
                            headers: parser?.headers,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                _currentManga.title,
                                maxLines: 3,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.2),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  _currentManga.sourceId.toUpperCase(),
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    color: Theme.of(context).colorScheme.primary,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              IconButton(
                icon: Icon(
                  _isFavorite ? Icons.bookmark : Icons.bookmark_border,
                  color: _isFavorite ? Colors.amber : Colors.white,
                ),
                onPressed: _toggleFavorite,
              ),
            ],
          ),

          // Details Content
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Action buttons
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: _resumeChapter != null
                              ? () => _openReader(_resumeChapter!, _resumeChapter!.lastReadPage)
                              : null,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Theme.of(context).colorScheme.primary,
                            foregroundColor: Colors.black,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                          icon: const Icon(Icons.play_arrow),
                          label: Text(
                            _resumeChapter != null && _resumeChapter!.lastReadPage > 0
                                ? 'Resume Ch. ${_resumeChapter!.number.toString().replaceAll(RegExp(r"\.0$"), "")} (p. ${_resumeChapter!.lastReadPage + 1})'
                                : _chapters.isNotEmpty
                                    ? 'Start Ch. ${_chapters.last.number.toString().replaceAll(RegExp(r"\.0$"), "")}'
                                    : 'Start Reading',
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      OutlinedButton.icon(
                        onPressed: _toggleFavorite,
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                        ),
                        icon: Icon(
                          _isFavorite ? Icons.favorite : Icons.favorite_border,
                          color: _isFavorite ? Colors.redAccent : null,
                        ),
                        label: Text(_isFavorite ? 'In Library' : 'Add to Library'),
                      ),
                    ],
                  ),

                  const SizedBox(height: 20),

                  // Synopsis
                  _buildSynopsisSection(),

                  // Genres
                  if (_currentManga.genres.isNotEmpty) ...[
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: _currentManga.genres.map((g) {
                        return Chip(
                          label: Text(g, style: const TextStyle(fontSize: 11)),
                          padding: EdgeInsets.zero,
                          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 20),
                  ],

                  // Chapters Header
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Chapters (${_chapters.length})',
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (_chapters.isNotEmpty)
                            IconButton(
                              icon: const Icon(Icons.download_for_offline_rounded, size: 22, color: Color(0xFF00F0FF)),
                              tooltip: 'Download All Chapters for Offline',
                              onPressed: _downloadAllChapters,
                            ),
                          if (_isLoading)
                            const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          // Chapter List
          if (_error != null)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Center(
                  child: Text('Error loading chapters: $_error'),
                ),
              ),
            )
          else
            SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, index) {
                  final ch = _chapters[index];
                  return ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
                    title: Text(
                      ch.title,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: ch.isRead ? FontWeight.normal : FontWeight.w600,
                        color: ch.isRead ? Colors.grey : null,
                      ),
                    ),
                    subtitle: ch.lastReadPage > 0
                        ? Text(
                            'Page ${ch.lastReadPage + 1}',
                            style: TextStyle(fontSize: 11, color: Theme.of(context).colorScheme.primary),
                          )
                        : null,
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
                                    width: 24,
                                    height: 24,
                                    child: Padding(
                                      padding: const EdgeInsets.all(3),
                                      child: CircularProgressIndicator(
                                        value: progress > 0.05 ? progress : null,
                                        strokeWidth: 2.5,
                                        color: const Color(0xFF00F0FF),
                                      ),
                                    ),
                                  );
                                }
                                if (isDownloaded) {
                                  return IconButton(
                                    icon: const Icon(Icons.download_done_rounded, color: Color(0xFF00F0FF), size: 20),
                                    tooltip: 'Downloaded (Offline) - Tap to delete',
                                    onPressed: () => _confirmDeleteDownload(ch),
                                  );
                                }
                                return IconButton(
                                  icon: const Icon(Icons.download_outlined, size: 20),
                                  tooltip: 'Download Chapter',
                                  onPressed: () => _downloadChapter(ch),
                                );
                              },
                            );
                          },
                        ),
                        if (ch.isRead)
                          const Padding(
                            padding: EdgeInsets.only(left: 4),
                            child: Icon(Icons.check_circle, size: 16, color: Colors.green),
                          )
                        else
                          const Icon(Icons.chevron_right, size: 18),
                      ],
                    ),
                    onTap: () => _openReader(ch, ch.lastReadPage),
                  );
                },
                childCount: _chapters.length,
              ),
            ),
        ],
      ),
    );
  }
}
