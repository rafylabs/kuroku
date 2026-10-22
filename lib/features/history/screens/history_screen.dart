import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:extended_image/extended_image.dart';
import '../../../core/parser/parser_registry.dart';
import '../providers/history_provider.dart';
import '../../reader/providers/reader_provider.dart';
import '../../reader/screens/manga_reader_screen.dart';

class HistoryScreen extends ConsumerWidget {
  const HistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final historyAsync = ref.watch(historyProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('History', style: TextStyle(fontWeight: FontWeight.w900)),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => ref.read(historyProvider.notifier).loadHistory(),
          ),
        ],
      ),
      body: historyAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => Center(child: Text('Failed to load history: $err')),
        data: (entries) {
          if (entries.isEmpty) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.history_toggle_off, size: 64, color: Colors.grey.shade600),
                  const SizedBox(height: 16),
                  const Text(
                    'No Reading History',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Start reading manga from the catalog and your progress will show up here.',
                    style: TextStyle(color: Colors.grey, fontSize: 13),
                  ),
                ],
              ),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.symmetric(vertical: 8),
            itemCount: entries.length,
            separatorBuilder: (_, context) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final entry = entries[index];
              final parser = ParserRegistry.instance.getParser(entry.manga.sourceId);

              return ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                leading: ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: ExtendedImage.network(
                    entry.manga.coverUrl,
                    width: 48,
                    height: 64,
                    fit: BoxFit.cover,
                    headers: parser?.headers,
                    cache: true,
                  ),
                ),
                title: Text(
                  entry.manga.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                ),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 4),
                    Text(
                      entry.chapter.title,
                      style: const TextStyle(fontSize: 12),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Page ${entry.page + 1}',
                      style: TextStyle(
                        fontSize: 11,
                        color: Theme.of(context).colorScheme.primary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                trailing: IconButton(
                  icon: const Icon(Icons.play_circle_fill, color: Color(0xFF00F0FF), size: 28),
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => MangaReaderScreen(
                          args: ReaderArgs(
                            manga: entry.manga,
                            chapter: entry.chapter,
                            initialPage: entry.page,
                          ),
                        ),
                      ),
                    ).then((_) {
                      ref.read(historyProvider.notifier).loadHistory();
                    });
                  },
                ),
              );
            },
          );
        },
      ),
    );
  }
}
