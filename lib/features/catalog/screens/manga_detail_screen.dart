import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:extended_image/extended_image.dart';
import '../../../core/database/app_database.dart';
import '../../../core/database/models/manga.dart';
import '../../../core/database/models/chapter.dart';
import '../../../core/parser/parser_registry.dart';
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

  @override
  void initState() {
    super.initState();
    _currentManga = widget.manga;
    _checkFavorite();
    _loadMangaData();
  }

  Future<void> _checkFavorite() async {
    final existing = await AppDatabase.instance.getManga(widget.manga.id);
    if (mounted && existing != null) {
      setState(() {
        _isFavorite = existing.isFavorite;
        _currentManga = existing;
      });
    }
  }

  Future<void> _loadMangaData() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final parser = ParserRegistry.instance.getParser(widget.manga.sourceId) ??
          ParserRegistry.instance.defaultParser;

      // 1. Fetch details
      final detailedManga = await parser.getDetails(widget.manga);
      
      // 2. Fetch chapters
      final chapters = await parser.getChapters(detailedManga);

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

      if (mounted) {
        setState(() {
          _currentManga = detailedManga.copyWith(isFavorite: _isFavorite);
          _chapters = mergedChapters;
          _isLoading = false;
        });

        // Save metadata to SQLite
        await AppDatabase.instance.upsertManga(_currentManga);
        await AppDatabase.instance.upsertChapters(_chapters);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _error = e.toString();
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
    return _chapters.last;
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
      _loadMangaData();
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
                  ExtendedImage.network(
                    _currentManga.coverUrl,
                    fit: BoxFit.cover,
                    headers: parser?.headers,
                    cache: true,
                  ),
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
                          child: ExtendedImage.network(
                            _currentManga.coverUrl,
                            width: 100,
                            height: 140,
                            fit: BoxFit.cover,
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
                  if (_currentManga.description != null && _currentManga.description!.isNotEmpty) ...[
                    const Text(
                      'Synopsis',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      _currentManga.description!,
                      style: const TextStyle(fontSize: 13, height: 1.4, color: Colors.grey),
                    ),
                    const SizedBox(height: 20),
                  ],

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
                    trailing: ch.isRead
                        ? const Icon(Icons.check_circle, size: 18, color: Colors.green)
                        : const Icon(Icons.chevron_right, size: 18),
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
