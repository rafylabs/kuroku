import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:extended_image/extended_image.dart';
import '../../../core/parser/parser_registry.dart';
import '../providers/library_provider.dart';
import '../../catalog/screens/manga_detail_screen.dart';

class LibraryScreen extends ConsumerWidget {
  const LibraryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final libraryAsync = ref.watch(libraryProvider);
    final activeFilter = ref.watch(libraryFilterProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Library', style: TextStyle(fontWeight: FontWeight.w900)),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => ref.read(libraryProvider.notifier).loadManga(),
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(48),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            child: Row(
              children: [
                ChoiceChip(
                  label: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.bookmark_rounded, size: 14),
                      SizedBox(width: 4),
                      Text('Favorit'),
                    ],
                  ),
                  selected: activeFilter == LibraryFilter.favorites,
                  selectedColor: Theme.of(context).colorScheme.primary.withValues(alpha: 0.2),
                  side: BorderSide(
                    color: activeFilter == LibraryFilter.favorites
                        ? Theme.of(context).colorScheme.primary
                        : Theme.of(context).dividerColor,
                  ),
                  labelStyle: TextStyle(
                    color: activeFilter == LibraryFilter.favorites
                        ? Theme.of(context).colorScheme.primary
                        : null,
                    fontWeight: activeFilter == LibraryFilter.favorites
                        ? FontWeight.bold
                        : FontWeight.normal,
                    fontSize: 12,
                  ),
                  onSelected: (_) {
                    ref.read(libraryFilterProvider.notifier).state = LibraryFilter.favorites;
                  },
                ),
                const SizedBox(width: 8),
                ChoiceChip(
                  label: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.download_for_offline_rounded, size: 14),
                      SizedBox(width: 4),
                      Text('Didownload (Offline)'),
                    ],
                  ),
                  selected: activeFilter == LibraryFilter.downloaded,
                  selectedColor: Theme.of(context).colorScheme.primary.withValues(alpha: 0.2),
                  side: BorderSide(
                    color: activeFilter == LibraryFilter.downloaded
                        ? Theme.of(context).colorScheme.primary
                        : Theme.of(context).dividerColor,
                  ),
                  labelStyle: TextStyle(
                    color: activeFilter == LibraryFilter.downloaded
                        ? Theme.of(context).colorScheme.primary
                        : null,
                    fontWeight: activeFilter == LibraryFilter.downloaded
                        ? FontWeight.bold
                        : FontWeight.normal,
                    fontSize: 12,
                  ),
                  onSelected: (_) {
                    ref.read(libraryFilterProvider.notifier).state = LibraryFilter.downloaded;
                  },
                ),
              ],
            ),
          ),
        ),
      ),
      body: libraryAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => Center(
          child: Text('Failed to load library: $err'),
        ),
        data: (items) {
          if (items.isEmpty) {
            final isDownloadView = activeFilter == LibraryFilter.downloaded;
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      isDownloadView
                          ? Icons.download_done_rounded
                          : Icons.collections_bookmark_outlined,
                      size: 64,
                      color: Colors.grey.shade600,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      isDownloadView ? 'Belum Ada Manga Didownload' : 'Your Library is Empty',
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      isDownloadView
                          ? 'Buka manga dan tap tombol download chapter untuk membaca offline tanpa kuota/internet.'
                          : 'Browse sources and bookmark manga to read offline.',
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.grey, fontSize: 13),
                    ),
                  ],
                ),
              ),
            );
          }

          return GridView.builder(
            padding: const EdgeInsets.all(12),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              childAspectRatio: 0.65,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
            ),
            itemCount: items.length,
            itemBuilder: (context, index) {
              final manga = items[index];
              final parser = ParserRegistry.instance.getParser(manga.sourceId);

              return GestureDetector(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => MangaDetailScreen(manga: manga),
                    ),
                  ).then((_) {
                    ref.read(libraryProvider.notifier).loadManga();
                  });
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
                                    headers: parser?.headers,
                                    cache: true,
                                  )
                                : Container(
                                    color: Colors.black26,
                                    child: const Center(
                                      child: Icon(Icons.broken_image_outlined, color: Colors.white38),
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
                      Positioned(
                        top: 8,
                        right: 8,
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.7),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            activeFilter == LibraryFilter.downloaded
                                ? Icons.download_done_rounded
                                : Icons.bookmark,
                            size: 14,
                            color: activeFilter == LibraryFilter.downloaded
                                ? const Color(0xFF00F0FF)
                                : Colors.amber,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
