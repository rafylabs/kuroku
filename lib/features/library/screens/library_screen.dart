import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:extended_image/extended_image.dart';
import '../../../core/database/app_database.dart';
import '../../../core/database/models/manga.dart';
import '../../../core/database/models/chapter_update.dart';
import '../../../core/parser/parser_registry.dart';
import '../../../core/download/download_manager.dart';
import '../../../core/services/library_update_service.dart';
import '../providers/library_provider.dart';
import '../../catalog/screens/manga_detail_screen.dart';

class LibraryScreen extends ConsumerWidget {
  const LibraryScreen({super.key});

  String _formatTimeAgo(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inSeconds < 60) return 'Baru saja';
    if (diff.inMinutes < 60) return '${diff.inMinutes} menit lalu';
    if (diff.inHours < 24) return '${diff.inHours} jam lalu';
    if (diff.inDays < 7) return '${diff.inDays} hari lalu';
    return '${dt.day}/${dt.month}/${dt.year}';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final libraryAsync = ref.watch(libraryProvider);
    final activeFilter = ref.watch(libraryFilterProvider);
    final updatesAsync = ref.watch(updatesListProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Library', style: TextStyle(fontWeight: FontWeight.w900)),
        actions: [
          ValueListenableBuilder<bool>(
            valueListenable: LibraryUpdateService.instance.isCheckingUpdates,
            builder: (context, isChecking, _) {
              if (isChecking) {
                return const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 14),
                  child: SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Color(0xFF00F0FF),
                    ),
                  ),
                );
              }
              return IconButton(
                icon: const Icon(Icons.sync_rounded),
                tooltip: 'Periksa Update Chapter',
                onPressed: () async {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Memeriksa update chapter untuk manga favorit...'),
                      duration: Duration(seconds: 1),
                    ),
                  );
                  final found = await ref.read(libraryProvider.notifier).checkUpdates(silent: false);
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          found > 0
                              ? 'Ditemukan $found chapter baru!'
                              : 'Tidak ada chapter baru untuk saat ini',
                        ),
                        duration: const Duration(seconds: 2),
                      ),
                    );
                  }
                },
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Muat Ulang',
            onPressed: () {
              ref.read(libraryProvider.notifier).loadManga();
              ref.invalidate(updatesListProvider);
            },
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(48),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            child: ListView(
              scrollDirection: Axis.horizontal,
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
                const SizedBox(width: 8),
                ValueListenableBuilder<int>(
                  valueListenable: LibraryUpdateService.instance.unseenUpdateCount,
                  builder: (context, unseen, _) {
                    return ChoiceChip(
                      label: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.notifications_active_rounded, size: 14),
                          const SizedBox(width: 4),
                          const Text('Update Terbaru'),
                          if (unseen > 0) ...[
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                              decoration: BoxDecoration(
                                color: Colors.redAccent,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text(
                                '$unseen',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      selected: activeFilter == LibraryFilter.updates,
                      selectedColor: Theme.of(context).colorScheme.primary.withValues(alpha: 0.2),
                      side: BorderSide(
                        color: activeFilter == LibraryFilter.updates
                            ? Theme.of(context).colorScheme.primary
                            : Theme.of(context).dividerColor,
                      ),
                      labelStyle: TextStyle(
                        color: activeFilter == LibraryFilter.updates
                            ? Theme.of(context).colorScheme.primary
                            : null,
                        fontWeight: activeFilter == LibraryFilter.updates
                            ? FontWeight.bold
                            : FontWeight.normal,
                        fontSize: 12,
                      ),
                      onSelected: (_) async {
                        ref.read(libraryFilterProvider.notifier).state = LibraryFilter.updates;
                        await AppDatabase.instance.markAllUpdatesSeen();
                        await LibraryUpdateService.instance.refreshUnseenCount();
                      },
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      ),
      body: activeFilter == LibraryFilter.updates
          ? _buildUpdatesView(context, ref, updatesAsync)
          : _buildMangaGridView(context, ref, libraryAsync, activeFilter),
    );
  }

  Widget _buildUpdatesView(
    BuildContext context,
    WidgetRef ref,
    AsyncValue<List<ChapterUpdate>> updatesAsync,
  ) {
    return updatesAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (err, _) => Center(child: Text('Gagal memuat update: $err')),
      data: (updates) {
        if (updates.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.notifications_none_rounded, size: 64, color: Colors.grey.shade600),
                  const SizedBox(height: 16),
                  const Text(
                    'Belum Ada Notifikasi Update',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Tambahkan manga ke Favorit. Ketika chapter baru dirilis, Kuroku akan otomatis mengirim notifikasi seperti Kotatsu.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.grey, fontSize: 13),
                  ),
                  const SizedBox(height: 20),
                  ElevatedButton.icon(
                    onPressed: () {
                      ref.read(libraryProvider.notifier).checkUpdates(silent: false);
                    },
                    icon: const Icon(Icons.sync),
                    label: const Text('Periksa Update Sekarang'),
                  ),
                ],
              ),
            ),
          );
        }

        return ListView.separated(
          padding: const EdgeInsets.symmetric(vertical: 8),
          itemCount: updates.length,
          separatorBuilder: (_, _) => const Divider(height: 1),
          itemBuilder: (context, index) {
            final u = updates[index];
            final parser = ParserRegistry.instance.getParser(u.sourceId);

            return ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              leading: ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: FutureBuilder<File?>(
                  future: DownloadManager.instance.getLocalCoverFile(u.mangaId),
                  builder: (context, snapshot) {
                    final localFile = snapshot.data;
                    if (localFile != null) {
                      return ExtendedImage.file(
                        localFile,
                        width: 48,
                        height: 64,
                        fit: BoxFit.cover,
                      );
                    }
                    if (u.coverUrl.isNotEmpty) {
                      return ExtendedImage.network(
                        u.coverUrl,
                        width: 48,
                        height: 64,
                        fit: BoxFit.cover,
                        headers: parser?.headers,
                        cache: true,
                      );
                    }
                    return Container(
                      width: 48,
                      height: 64,
                      color: Colors.black26,
                      child: const Center(
                        child: Icon(Icons.broken_image_outlined, color: Colors.white38, size: 20),
                      ),
                    );
                  },
                ),
              ),
              title: Text(
                u.mangaTitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
              ),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(0xFF00F0FF).withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          '1 new chapter',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        _formatTimeAgo(u.detectedAt),
                        style: const TextStyle(fontSize: 11, color: Colors.grey),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    u.chapterTitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 12, color: Colors.white70),
                  ),
                ],
              ),
              trailing: const Icon(Icons.chevron_right, size: 20, color: Colors.grey),
              onTap: () async {
                final manga = await AppDatabase.instance.getManga(u.mangaId);
                if (manga != null && context.mounted) {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => MangaDetailScreen(manga: manga),
                    ),
                  ).then((_) {
                    ref.read(libraryProvider.notifier).loadManga();
                    ref.invalidate(updatesListProvider);
                  });
                }
              },
            );
          },
        );
      },
    );
  }

  Widget _buildMangaGridView(
    BuildContext context,
    WidgetRef ref,
    AsyncValue<List<Manga>> libraryAsync,
    LibraryFilter activeFilter,
  ) {
    final progressMap = ref.watch(libraryProgressProvider).value ?? const {};
    return libraryAsync.when(
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
            final cleanId = manga.id.contains('_') ? manga.id.substring(manga.id.indexOf('_') + 1) : manga.id;
            final progress = progressMap[manga.id] ?? progressMap[cleanId] ?? 0.0;

            return GestureDetector(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => MangaDetailScreen(manga: manga),
                  ),
                ).then((_) {
                  ref.read(libraryProvider.notifier).loadManga();
                  ref.invalidate(updatesListProvider);
                  ref.invalidate(libraryProgressProvider);
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
                          child: Stack(
                            fit: StackFit.expand,
                            children: [
                              FutureBuilder<File?>(
                                future: DownloadManager.instance.getLocalCoverFile(manga.id),
                                builder: (context, snapshot) {
                                  final localFile = snapshot.data;
                                  if (localFile != null) {
                                    return ExtendedImage.file(
                                      localFile,
                                      fit: BoxFit.cover,
                                    );
                                  }
                                  if (manga.coverUrl.isNotEmpty) {
                                    return ExtendedImage.network(
                                      manga.coverUrl,
                                      fit: BoxFit.cover,
                                      headers: parser?.headers,
                                      cache: true,
                                    );
                                  }
                                  return Container(
                                    color: Colors.black26,
                                    child: const Center(
                                      child: Icon(Icons.broken_image_outlined, color: Colors.white38),
                                    ),
                                  );
                                },
                              ),
                              if (progress > 0)
                                Positioned(
                                  bottom: 0,
                                  left: 0,
                                  right: 0,
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: [
                                      Container(
                                        margin: const EdgeInsets.only(right: 6, bottom: 4),
                                        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: Colors.black.withValues(alpha: 0.8),
                                          borderRadius: BorderRadius.circular(4),
                                          border: Border.all(
                                            color: progress >= 1.0
                                                ? const Color(0xFF10B981)
                                                : const Color(0xFF00F0FF).withValues(alpha: 0.6),
                                            width: 0.8,
                                          ),
                                        ),
                                        child: Text(
                                          '${(progress * 100).toInt()}%',
                                          style: TextStyle(
                                            fontSize: 9.5,
                                            fontWeight: FontWeight.bold,
                                            color: progress >= 1.0
                                                ? const Color(0xFF10B981)
                                                : const Color(0xFF00F0FF),
                                          ),
                                        ),
                                      ),
                                      LinearProgressIndicator(
                                        value: progress,
                                        minHeight: 3,
                                        backgroundColor: Colors.black45,
                                        valueColor: AlwaysStoppedAnimation<Color>(
                                          progress >= 1.0
                                              ? const Color(0xFF10B981)
                                              : const Color(0xFF00F0FF),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                            ],
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
    );
  }
}
