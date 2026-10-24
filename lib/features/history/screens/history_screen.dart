import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:extended_image/extended_image.dart';
import '../../../core/database/app_database.dart';
import '../../../core/database/models/manga.dart';
import '../../../core/parser/parser_registry.dart';
import '../../../core/download/download_manager.dart';
import '../providers/history_provider.dart';
import '../../reader/providers/reader_provider.dart';
import '../../reader/screens/manga_reader_screen.dart';
import '../../catalog/screens/manga_detail_screen.dart';

class HistoryScreen extends ConsumerStatefulWidget {
  const HistoryScreen({super.key});

  @override
  ConsumerState<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends ConsumerState<HistoryScreen> {
  HistoryFilter _currentFilter = HistoryFilter.all;

  String _formatTimeAgo(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);

    if (diff.inSeconds < 60) return 'Baru saja';
    if (diff.inMinutes < 60) return '${diff.inMinutes} mnt lalu';
    if (diff.inHours < 24) return '${diff.inHours} jam lalu';
    if (diff.inDays == 1) return 'Kemarin';
    if (diff.inDays < 7) return '${diff.inDays} hari lalu';
    return '${dt.day}/${dt.month}/${dt.year}';
  }

  void _showClearDialog(BuildContext context, HistoryNotifier notifier) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF161B24),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                child: Text(
                  'Hapus History',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                ),
              ),
              const Divider(color: Colors.white12),
              ListTile(
                leading: const Icon(Icons.auto_stories_outlined, color: Colors.white70),
                title: const Text('Hapus Riwayat Bacaan'),
                subtitle: const Text('Menghapus catatan chapter dan halaman yang terakhir dibaca', style: TextStyle(fontSize: 12, color: Colors.grey)),
                onTap: () async {
                  Navigator.pop(ctx);
                  await notifier.clearReadingHistory();
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Riwayat bacaan dibersihkan')),
                    );
                  }
                },
              ),
              ListTile(
                leading: const Icon(Icons.notifications_off_outlined, color: Color(0xFF00F0FF)),
                title: const Text('Hapus Notifikasi Update'),
                subtitle: const Text('Menghapus riwayat pemberitahuan chapter baru', style: TextStyle(fontSize: 12, color: Colors.grey)),
                onTap: () async {
                  Navigator.pop(ctx);
                  await notifier.clearUpdateNotifications();
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Notifikasi update dibersihkan')),
                    );
                  }
                },
              ),
              ListTile(
                leading: const Icon(Icons.delete_forever, color: Colors.redAccent),
                title: const Text('Hapus Semua', style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold)),
                subtitle: const Text('Kosongkan seluruh riwayat baca dan notifikasi update', style: TextStyle(fontSize: 12, color: Colors.grey)),
                onTap: () async {
                  Navigator.pop(ctx);
                  await notifier.clearAll();
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Semua riwayat dibersihkan')),
                    );
                  }
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _handleItemTap(UnifiedHistoryItem item) async {
    if (item.isUpdate) {
      // Mark as seen
      if (item.updateEntry != null) {
        final db = await AppDatabase.instance.database;
        await db.update('chapter_updates', {'is_seen': 1}, where: 'id = ?', whereArgs: [item.updateEntry!.id]);
      }

      // Check DB for full Manga model
      Manga? manga = await AppDatabase.instance.getManga(item.mangaId);
      manga ??= Manga(
        id: item.mangaId,
        title: item.mangaTitle,
        url: item.mangaId,
        coverUrl: item.coverUrl,
        sourceId: item.sourceId,
      );

      if (!mounted) return;
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => MangaDetailScreen(manga: manga!),
        ),
      ).then((_) {
        ref.read(historyProvider.notifier).loadHistory();
      });
    } else if (item.readEntry != null) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => MangaReaderScreen(
            args: ReaderArgs(
              manga: item.readEntry!.manga,
              chapter: item.readEntry!.chapter,
              initialPage: item.readEntry!.page,
            ),
          ),
        ),
      ).then((_) {
        ref.read(historyProvider.notifier).loadHistory();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final historyAsync = ref.watch(historyProvider);
    final notifier = ref.read(historyProvider.notifier);

    return Scaffold(
      appBar: AppBar(
        title: const Text('History & Updates', style: TextStyle(fontWeight: FontWeight.w900)),
        actions: [
          IconButton(
            icon: const Icon(Icons.done_all_rounded),
            tooltip: 'Tandai semua notifikasi terbaca',
            onPressed: () => notifier.markAllUpdatesSeen(),
          ),
          IconButton(
            icon: const Icon(Icons.delete_sweep_outlined),
            tooltip: 'Hapus riwayat',
            onPressed: () => _showClearDialog(context, notifier),
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Muat ulang',
            onPressed: () => notifier.loadHistory(),
          ),
        ],
      ),
      body: historyAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => Center(child: Text('Gagal memuat history: $err')),
        data: (data) {
          final items = data.allItems.where((it) {
            if (_currentFilter == HistoryFilter.readOnly) return !it.isUpdate;
            if (_currentFilter == HistoryFilter.updatesOnly) return it.isUpdate;
            return true;
          }).toList();

          return Column(
            children: [
              // Filter chips bar
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: const BoxDecoration(
                  border: Border(bottom: BorderSide(color: Colors.white10)),
                ),
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      FilterChip(
                        selected: _currentFilter == HistoryFilter.all,
                        label: Text('Semua (${data.allItems.length})'),
                        onSelected: (_) => setState(() => _currentFilter = HistoryFilter.all),
                        backgroundColor: Colors.white.withValues(alpha: 0.05),
                        selectedColor: const Color(0xFF00F0FF).withValues(alpha: 0.2),
                        checkmarkColor: const Color(0xFF00F0FF),
                        labelStyle: TextStyle(
                          color: _currentFilter == HistoryFilter.all ? const Color(0xFF00F0FF) : Colors.white70,
                          fontSize: 12,
                          fontWeight: _currentFilter == HistoryFilter.all ? FontWeight.bold : FontWeight.normal,
                        ),
                      ),
                      const SizedBox(width: 8),
                      FilterChip(
                        selected: _currentFilter == HistoryFilter.readOnly,
                        label: Text('Riwayat Baca (${data.readCount})'),
                        onSelected: (_) => setState(() => _currentFilter = HistoryFilter.readOnly),
                        backgroundColor: Colors.white.withValues(alpha: 0.05),
                        selectedColor: const Color(0xFF00F0FF).withValues(alpha: 0.2),
                        checkmarkColor: const Color(0xFF00F0FF),
                        labelStyle: TextStyle(
                          color: _currentFilter == HistoryFilter.readOnly ? const Color(0xFF00F0FF) : Colors.white70,
                          fontSize: 12,
                          fontWeight: _currentFilter == HistoryFilter.readOnly ? FontWeight.bold : FontWeight.normal,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Badge(
                        isLabelVisible: data.unseenUpdateCount > 0,
                        label: Text('${data.unseenUpdateCount}'),
                        backgroundColor: const Color(0xFF00F0FF),
                        textColor: Colors.black,
                        child: FilterChip(
                          selected: _currentFilter == HistoryFilter.updatesOnly,
                          label: Text('Update Notifikasi (${data.updateCount})'),
                          onSelected: (_) => setState(() => _currentFilter = HistoryFilter.updatesOnly),
                          backgroundColor: Colors.white.withValues(alpha: 0.05),
                          selectedColor: const Color(0xFF00F0FF).withValues(alpha: 0.2),
                          checkmarkColor: const Color(0xFF00F0FF),
                          labelStyle: TextStyle(
                            color: _currentFilter == HistoryFilter.updatesOnly ? const Color(0xFF00F0FF) : Colors.white70,
                            fontSize: 12,
                            fontWeight: _currentFilter == HistoryFilter.updatesOnly ? FontWeight.bold : FontWeight.normal,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // Empty State or List
              Expanded(
                child: items.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              _currentFilter == HistoryFilter.updatesOnly
                                  ? Icons.notifications_none_rounded
                                  : Icons.history_toggle_off,
                              size: 64,
                              color: Colors.grey.shade600,
                            ),
                            const SizedBox(height: 16),
                            Text(
                              _currentFilter == HistoryFilter.updatesOnly
                                  ? 'Belum Ada Notifikasi Update'
                                  : 'Belum Ada Riwayat Bacaan',
                              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 8),
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 32),
                              child: Text(
                                _currentFilter == HistoryFilter.updatesOnly
                                    ? 'Ketika ada chapter baru dari komik favoritmu, riwayat notifikasi akan muncul di sini.'
                                    : 'Mulai baca komik dari katalog dan riwayat bacaanmu akan tersimpan di sini.',
                                textAlign: TextAlign.center,
                                style: const TextStyle(color: Colors.grey, fontSize: 12),
                              ),
                            ),
                          ],
                        ),
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        itemCount: items.length,
                        separatorBuilder: (_, context) => const Divider(height: 1, color: Colors.white10),
                        itemBuilder: (context, index) {
                          final item = items[index];
                          final parser = ParserRegistry.instance.getParser(item.sourceId);

                          return InkWell(
                            onTap: () => _handleItemTap(item),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.center,
                                children: [
                                  // Cover Image
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(6),
                                    child: FutureBuilder<File?>(
                                      future: DownloadManager.instance.getLocalCoverFile(item.mangaId),
                                      builder: (context, snapshot) {
                                        final localFile = snapshot.data;
                                        if (localFile != null) {
                                          return ExtendedImage.file(
                                            localFile,
                                            width: 50,
                                            height: 68,
                                            fit: BoxFit.cover,
                                          );
                                        }
                                        if (item.coverUrl.isNotEmpty) {
                                          return ExtendedImage.network(
                                            item.coverUrl,
                                            width: 50,
                                            height: 68,
                                            fit: BoxFit.cover,
                                            headers: parser?.headers,
                                            cache: true,
                                          );
                                        }
                                        return Container(
                                          width: 50,
                                          height: 68,
                                          color: Colors.black26,
                                          child: const Center(
                                            child: Icon(Icons.broken_image_outlined, color: Colors.white38, size: 20),
                                          ),
                                        );
                                      },
                                    ),
                                  ),
                                  const SizedBox(width: 12),

                                  // Details Column
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        // Badge row
                                        Row(
                                          children: [
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                              decoration: BoxDecoration(
                                                color: item.isUpdate
                                                    ? const Color(0xFF00F0FF).withValues(alpha: 0.15)
                                                    : Colors.blueGrey.withValues(alpha: 0.2),
                                                borderRadius: BorderRadius.circular(4),
                                                border: Border.all(
                                                  color: item.isUpdate
                                                      ? const Color(0xFF00F0FF).withValues(alpha: 0.4)
                                                      : Colors.white24,
                                                  width: 0.8,
                                                ),
                                              ),
                                              child: Row(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  Icon(
                                                    item.isUpdate
                                                        ? Icons.bolt_rounded
                                                        : Icons.menu_book_rounded,
                                                    size: 11,
                                                    color: item.isUpdate ? const Color(0xFF00F0FF) : Colors.white70,
                                                  ),
                                                  const SizedBox(width: 4),
                                                  Text(
                                                    item.isUpdate ? 'UPDATE BARU' : 'DIBACA',
                                                    style: TextStyle(
                                                      fontSize: 9,
                                                      fontWeight: FontWeight.bold,
                                                      letterSpacing: 0.5,
                                                      color: item.isUpdate ? const Color(0xFF00F0FF) : Colors.white70,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                            const SizedBox(width: 6),
                                            if (item.isUpdate && !item.isSeen)
                                              Container(
                                                width: 7,
                                                height: 7,
                                                decoration: const BoxDecoration(
                                                  color: Color(0xFF00F0FF),
                                                  shape: BoxShape.circle,
                                                ),
                                              ),
                                            const Spacer(),
                                            Text(
                                              _formatTimeAgo(item.timestamp),
                                              style: const TextStyle(fontSize: 10, color: Colors.grey),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 5),

                                        // Manga Title
                                        Text(
                                          item.mangaTitle,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 14,
                                            color: Colors.white,
                                          ),
                                        ),
                                        const SizedBox(height: 3),

                                        // Subtitle info
                                        Text(
                                          item.chapterTitle.isNotEmpty
                                              ? item.chapterTitle
                                              : 'Chapter ${item.chapterNumber.toString().replaceAll(RegExp(r"\.0$"), "")}',
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: item.isUpdate ? const Color(0xFF00F0FF) : Colors.grey.shade300,
                                          ),
                                        ),
                                        if (!item.isUpdate)
                                          Padding(
                                            padding: const EdgeInsets.only(top: 2),
                                            child: Text(
                                              'Halaman ${item.page + 1}',
                                              style: TextStyle(
                                                fontSize: 11,
                                                fontWeight: FontWeight.w600,
                                                color: Theme.of(context).colorScheme.primary,
                                              ),
                                            ),
                                          ),
                                      ],
                                    ),
                                  ),

                                  // Trailing Action Button
                                  const SizedBox(width: 8),
                                  IconButton(
                                    icon: Icon(
                                      item.isUpdate ? Icons.arrow_forward_ios_rounded : Icons.play_circle_fill,
                                      color: const Color(0xFF00F0FF),
                                      size: item.isUpdate ? 16 : 28,
                                    ),
                                    onPressed: () => _handleItemTap(item),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
              ),
            ],
          );
        },
      ),
    );
  }
}
