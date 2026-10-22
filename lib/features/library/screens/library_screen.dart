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

    return Scaffold(
      appBar: AppBar(
        title: const Text('Library', style: TextStyle(fontWeight: FontWeight.w900)),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => ref.read(libraryProvider.notifier).loadFavorites(),
          ),
        ],
      ),
      body: libraryAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => Center(
          child: Text('Failed to load library: $err'),
        ),
        data: (favorites) {
          if (favorites.isEmpty) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.collections_bookmark_outlined, size: 64, color: Colors.grey.shade600),
                  const SizedBox(height: 16),
                  const Text(
                    'Your Library is Empty',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Browse sources and bookmark manga to read offline.',
                    style: TextStyle(color: Colors.grey, fontSize: 13),
                  ),
                ],
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
            itemCount: favorites.length,
            itemBuilder: (context, index) {
              final manga = favorites[index];
              final parser = ParserRegistry.instance.getParser(manga.sourceId);

              return GestureDetector(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => MangaDetailScreen(manga: manga),
                    ),
                  ).then((_) {
                    ref.read(libraryProvider.notifier).loadFavorites();
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
                          child: const Icon(Icons.bookmark, size: 14, color: Colors.amber),
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
