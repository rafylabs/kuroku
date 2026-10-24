import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:extended_image/extended_image.dart';
import '../../../core/database/app_database.dart';
import '../../../core/database/models/manga.dart';
import '../providers/history_provider.dart';
import '../../reader/providers/reader_provider.dart';
import '../../reader/screens/manga_reader_screen.dart';
import '../../catalog/screens/manga_detail_screen.dart';

enum HistoryFilterType {
  all,
  readLater,
  updates,
  readHistory,
}

class HistoryScreen extends ConsumerStatefulWidget {
  const HistoryScreen({super.key});

  @override
  ConsumerState<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends ConsumerState<HistoryScreen> {
  HistoryFilterType _filter = HistoryFilterType.all;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() {
      final q = _searchController.text.trim().toLowerCase();
      if (q != _searchQuery) {
        setState(() {
          _searchQuery = q;
        });
      }
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  String _getDateHeader(DateTime dt) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final itemDate = DateTime(dt.year, dt.month, dt.day);
    final diffDays = today.difference(itemDate).inDays;

    if (diffDays == 0) return 'Today';
    if (diffDays == 1) return 'Yesterday';
    if (diffDays == 2) return '2 days ago';
    if (diffDays < 7) return '$diffDays days ago';
    if (diffDays < 30) {
      final weeks = (diffDays / 7).floor();
      return '$weeks ${weeks == 1 ? "week" : "weeks"} ago';
    }
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return '${months[dt.month - 1]} ${dt.day}, ${dt.year}';
  }

  String _formatTimeAgo(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);

    if (diff.inSeconds < 60) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays == 1) return 'Yesterday';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return '${dt.day}/${dt.month}';
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
                  'Manage History & Updates',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                ),
              ),
              const Divider(color: Colors.white12),
              ListTile(
                leading: const Icon(Icons.done_all_rounded, color: Color(0xFF00F0FF)),
                title: const Text('Mark All Updates as Seen'),
                onTap: () async {
                  Navigator.pop(ctx);
                  await notifier.markAllUpdatesSeen();
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('All chapter updates marked as seen')),
                    );
                  }
                },
              ),
              ListTile(
                leading: const Icon(Icons.auto_stories_outlined, color: Colors.white70),
                title: const Text('Clear Reading History'),
                subtitle: const Text('Remove read chapter progress logs', style: TextStyle(fontSize: 12, color: Colors.grey)),
                onTap: () async {
                  Navigator.pop(ctx);
                  await notifier.clearReadingHistory();
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Reading history cleared')),
                    );
                  }
                },
              ),
              ListTile(
                leading: const Icon(Icons.notifications_off_outlined, color: Color(0xFFFF4081)),
                title: const Text('Clear Update Notifications'),
                subtitle: const Text('Remove new chapter release alerts', style: TextStyle(fontSize: 12, color: Colors.grey)),
                onTap: () async {
                  Navigator.pop(ctx);
                  await notifier.clearUpdateNotifications();
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Update notifications cleared')),
                    );
                  }
                },
              ),
              ListTile(
                leading: const Icon(Icons.delete_forever, color: Colors.redAccent),
                title: const Text('Clear All', style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold)),
                subtitle: const Text('Remove both reading history and notifications', style: TextStyle(fontSize: 12, color: Colors.grey)),
                onTap: () async {
                  Navigator.pop(ctx);
                  await notifier.clearAll();
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('All history and updates cleared')),
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
      if (item.updateEntry != null) {
        final db = await AppDatabase.instance.database;
        await db.update('chapter_updates', {'is_seen': 1}, where: 'id = ?', whereArgs: [item.updateEntry!.id]);
      }

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
              initialOffset: item.readEntry!.scrollOffset,
            ),
          ),
        ),
      ).then((_) {
        ref.read(historyProvider.notifier).loadHistory();
      });
    }
  }

  void _openMangaDetailById(String mangaId, String title, String coverUrl, String sourceId) async {
    Manga? manga = await AppDatabase.instance.getManga(mangaId);
    manga ??= Manga(
      id: mangaId,
      title: title,
      url: mangaId,
      coverUrl: coverUrl,
      sourceId: sourceId,
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
  }

  @override
  Widget build(BuildContext context) {
    final historyAsync = ref.watch(historyProvider);
    final notifier = ref.read(historyProvider.notifier);

    return Scaffold(
      backgroundColor: const Color(0xFF0F1117),
      body: SafeArea(
        child: historyAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (err, _) => Center(child: Text('Failed to load history: $err')),
          data: (data) {
            // Apply search & filter
            final filteredItems = data.allItems.where((it) {
              if (_filter == HistoryFilterType.readLater) {
                if (!data.favoriteMangaIds.contains(it.mangaId)) return false;
              } else if (_filter == HistoryFilterType.updates) {
                if (!it.isUpdate) return false;
              } else if (_filter == HistoryFilterType.readHistory) {
                if (it.isUpdate) return false;
              }

              if (_searchQuery.isNotEmpty) {
                final matchTitle = it.mangaTitle.toLowerCase().contains(_searchQuery);
                final matchChap = it.chapterTitle.toLowerCase().contains(_searchQuery);
                return matchTitle || matchChap;
              }
              return true;
            }).toList();

            // Group items chronologically
            final Map<String, List<UnifiedHistoryItem>> grouped = {};
            for (final it in filteredItems) {
              final header = _getDateHeader(it.timestamp);
              grouped.putIfAbsent(header, () => []).add(it);
            }

            return RefreshIndicator(
              onRefresh: () => notifier.loadHistory(),
              child: CustomScrollView(
                slivers: [
                  // 1. Top Search Bar
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                      child: Container(
                        height: 48,
                        decoration: BoxDecoration(
                          color: const Color(0xFF1C2029),
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(color: Colors.white10),
                        ),
                        child: Row(
                          children: [
                            const SizedBox(width: 14),
                            const Icon(Icons.search, color: Colors.white54, size: 22),
                            const SizedBox(width: 10),
                            Expanded(
                              child: TextField(
                                controller: _searchController,
                                style: const TextStyle(color: Colors.white, fontSize: 14),
                                decoration: const InputDecoration(
                                  hintText: 'Search manga',
                                  hintStyle: TextStyle(color: Colors.white38, fontSize: 14),
                                  border: InputBorder.none,
                                  isDense: true,
                                ),
                              ),
                            ),
                            if (_searchQuery.isNotEmpty)
                              IconButton(
                                icon: const Icon(Icons.close, color: Colors.white54, size: 18),
                                onPressed: () {
                                  _searchController.clear();
                                },
                              ),
                            PopupMenuButton<String>(
                              icon: const Icon(Icons.more_vert, color: Colors.white70),
                              color: const Color(0xFF1E232E),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              onSelected: (val) {
                                if (val == 'clear_dialog') {
                                  _showClearDialog(context, notifier);
                                } else if (val == 'mark_read') {
                                  notifier.markAllUpdatesSeen();
                                } else if (val == 'refresh') {
                                  notifier.loadHistory();
                                }
                              },
                              itemBuilder: (ctx) => [
                                const PopupMenuItem(
                                  value: 'mark_read',
                                  child: Row(
                                    children: [
                                      Icon(Icons.done_all_rounded, color: Color(0xFF00F0FF), size: 18),
                                      SizedBox(width: 10),
                                      Text('Mark all as seen', style: TextStyle(color: Colors.white, fontSize: 13)),
                                    ],
                                  ),
                                ),
                                const PopupMenuItem(
                                  value: 'refresh',
                                  child: Row(
                                    children: [
                                      Icon(Icons.refresh, color: Colors.white70, size: 18),
                                      SizedBox(width: 10),
                                      Text('Refresh feed', style: TextStyle(color: Colors.white, fontSize: 13)),
                                    ],
                                  ),
                                ),
                                const PopupMenuDivider(),
                                const PopupMenuItem(
                                  value: 'clear_dialog',
                                  child: Row(
                                    children: [
                                      Icon(Icons.delete_sweep_outlined, color: Colors.redAccent, size: 18),
                                      SizedBox(width: 10),
                                      Text('Clear history...', style: TextStyle(color: Colors.redAccent, fontSize: 13)),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),

                  // 2. Filter Bar (Read later, All, Updates, History)
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: [
                            // Read later (Favorites) outline pill like Kotatsu
                            _buildFilterPill(
                              label: 'Read later',
                              icon: _filter == HistoryFilterType.readLater ? Icons.favorite : Icons.favorite_border,
                              isSelected: _filter == HistoryFilterType.readLater,
                              onTap: () {
                                setState(() {
                                  _filter = _filter == HistoryFilterType.readLater
                                      ? HistoryFilterType.all
                                      : HistoryFilterType.readLater;
                                });
                              },
                            ),
                            const SizedBox(width: 8),
                            _buildFilterPill(
                              label: 'All',
                              isSelected: _filter == HistoryFilterType.all,
                              onTap: () => setState(() => _filter = HistoryFilterType.all),
                            ),
                            const SizedBox(width: 8),
                            _buildFilterPill(
                              label: 'Updates',
                              badgeCount: data.unseenUpdateCount > 0 ? data.unseenUpdateCount : null,
                              isSelected: _filter == HistoryFilterType.updates,
                              onTap: () => setState(() => _filter = HistoryFilterType.updates),
                            ),
                            const SizedBox(width: 8),
                            _buildFilterPill(
                              label: 'History',
                              isSelected: _filter == HistoryFilterType.readHistory,
                              onTap: () => setState(() => _filter = HistoryFilterType.readHistory),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),

                  // 3. Top "Updates" Horizontal Carousel
                  if (_searchQuery.isEmpty && data.updateCards.isNotEmpty)
                    SliverToBoxAdapter(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Padding(
                            padding: const EdgeInsets.fromLTRB(16, 16, 16, 10),
                            child: Row(
                              children: [
                                const Text(
                                  'Updates',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                ),
                                const Spacer(),
                                if (data.updateCount > 0)
                                  GestureDetector(
                                    onTap: () {
                                      setState(() {
                                        _filter = HistoryFilterType.updates;
                                      });
                                    },
                                    child: const Text(
                                      'More',
                                      style: TextStyle(
                                        color: Color(0xFFFF4081),
                                        fontWeight: FontWeight.w600,
                                        fontSize: 13,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          SizedBox(
                            height: 200,
                            child: ListView.separated(
                              padding: const EdgeInsets.symmetric(horizontal: 16),
                              scrollDirection: Axis.horizontal,
                              itemCount: data.updateCards.length,
                              separatorBuilder: (_, _) => const SizedBox(width: 12),
                              itemBuilder: (ctx, idx) {
                                final card = data.updateCards[idx];
                                return _buildUpdateCard(context, card, notifier);
                              },
                            ),
                          ),
                        ],
                      ),
                    ),

                  // 4. Chronological Feed Groups (Today, Yesterday, 2 days ago...)
                  if (filteredItems.isEmpty)
                    SliverFillRemaining(
                      hasScrollBody: false,
                      child: Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              _searchQuery.isNotEmpty ? Icons.search_off : Icons.dynamic_feed_outlined,
                              size: 48,
                              color: Colors.white24,
                            ),
                            const SizedBox(height: 12),
                            Text(
                              _searchQuery.isNotEmpty ? 'No matches found' : 'No history or updates yet',
                              style: const TextStyle(color: Colors.white54, fontSize: 14),
                            ),
                          ],
                        ),
                      ),
                    )
                  else
                    ...grouped.entries.expand((entry) {
                      final dateHeader = entry.key;
                      final itemsInGroup = entry.value;

                      return [
                        // Group header (e.g. Today, Yesterday, 2 days ago)
                        SliverToBoxAdapter(
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
                            child: Text(
                              dateHeader,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                        // List items in this group
                        SliverList(
                          delegate: SliverChildBuilderDelegate(
                            (ctx, idx) {
                              final it = itemsInGroup[idx];
                              return _buildFeedItem(context, it, notifier);
                            },
                            childCount: itemsInGroup.length,
                          ),
                        ),
                      ];
                    }),

                  const SliverToBoxAdapter(child: SizedBox(height: 32)),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildFilterPill({
    required String label,
    IconData? icon,
    int? badgeCount,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFFFF4081).withValues(alpha: 0.15) : const Color(0xFF181C24),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? const Color(0xFFFF4081) : Colors.white12,
            width: 1.2,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(
                icon,
                size: 15,
                color: isSelected ? const Color(0xFFFF4081) : Colors.white70,
              ),
              const SizedBox(width: 6),
            ],
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                color: isSelected ? const Color(0xFFFF4081) : Colors.white70,
              ),
            ),
            if (badgeCount != null) ...[
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0xFFFF4081),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '$badgeCount',
                  style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.white),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildUpdateCard(BuildContext context, UpdateCardItem card, HistoryNotifier notifier) {
    return GestureDetector(
      onTap: () => _openMangaDetailById(card.mangaId, card.mangaTitle, card.coverUrl, card.sourceId),
      child: SizedBox(
        width: 110,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Thumbnail Card with Stack badges
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Container(
                height: 150,
                width: 110,
                color: const Color(0xFF1A1E26),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    if (card.coverUrl.isNotEmpty)
                      ExtendedImage.network(
                        card.coverUrl,
                        fit: BoxFit.cover,
                        headers: const {'Referer': 'https://shinigami.moe/'},
                        loadStateChanged: (state) {
                          if (state.extendedImageLoadState == LoadState.failed) {
                            return const Center(child: Icon(Icons.broken_image, color: Colors.white24));
                          }
                          return null;
                        },
                      )
                    else
                      const Center(child: Icon(Icons.menu_book, color: Colors.white24)),

                    // Dark gradient at bottom
                    Positioned.fill(
                      child: Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Colors.transparent,
                              Colors.black.withValues(alpha: 0.6),
                            ],
                          ),
                        ),
                      ),
                    ),

                    // Top-left: Heart favorite button in dark circle
                    Positioned(
                      top: 6,
                      left: 6,
                      child: GestureDetector(
                        onTap: () {
                          notifier.toggleFavorite(card.mangaId, card.mangaTitle, card.coverUrl, card.sourceId);
                        },
                        child: Container(
                          padding: const EdgeInsets.all(5),
                          decoration: const BoxDecoration(
                            color: Color(0x99000000),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            card.isFavorite ? Icons.favorite : Icons.favorite_border,
                            size: 14,
                            color: card.isFavorite ? const Color(0xFFFF4081) : Colors.white,
                          ),
                        ),
                      ),
                    ),

                    // Top-right: Pink badge with new chapter count (e.g. "3" or "1")
                    if (card.updateCount > 0)
                      Positioned(
                        top: 6,
                        right: 6,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFF4081),
                            borderRadius: BorderRadius.circular(10),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.4),
                                blurRadius: 4,
                              ),
                            ],
                          ),
                          child: Text(
                            '${card.updateCount}',
                            style: const TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w900,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),

                    // Bottom-right: Circular progress percentage badge (e.g. "98%")
                    if (card.readingProgress > 0)
                      Positioned(
                        bottom: 6,
                        right: 6,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                          decoration: BoxDecoration(
                            color: const Color(0xFF007AFF),
                            borderRadius: BorderRadius.circular(10),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.4),
                                blurRadius: 4,
                              ),
                            ],
                          ),
                          child: Text(
                            '${(card.readingProgress * 100).round()}%',
                            style: const TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 6),
            // Manga Title
            Text(
              card.mangaTitle,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Colors.white,
                height: 1.2,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFeedItem(BuildContext context, UnifiedHistoryItem item, HistoryNotifier notifier) {
    return Dismissible(
      key: Key('feed_${item.id}'),
      direction: DismissDirection.endToStart,
      background: Container(
        color: Colors.redAccent.withValues(alpha: 0.8),
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        child: const Icon(Icons.delete, color: Colors.white),
      ),
      onDismissed: (_) {
        notifier.deleteItem(item);
      },
      child: InkWell(
        onTap: () => _handleItemTap(item),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: [
              // Cover Thumbnail
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  width: 48,
                  height: 68,
                  color: const Color(0xFF1E232E),
                  child: item.coverUrl.isNotEmpty
                      ? ExtendedImage.network(
                          item.coverUrl,
                          fit: BoxFit.cover,
                          headers: const {'Referer': 'https://shinigami.moe/'},
                          loadStateChanged: (state) {
                            if (state.extendedImageLoadState == LoadState.failed) {
                              return const Center(child: Icon(Icons.broken_image, size: 18, color: Colors.white24));
                            }
                            return null;
                          },
                        )
                      : const Center(child: Icon(Icons.menu_book, size: 18, color: Colors.white24)),
                ),
              ),
              const SizedBox(width: 14),

              // Title and Chapter Subtitle
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.mangaTitle,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        // Accent status dot
                        Container(
                          width: 7,
                          height: 7,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: item.isUpdate
                                ? const Color(0xFFFF4081)
                                : const Color(0xFF64B5F6),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            item.isUpdate
                                ? (item.chapterTitle.isNotEmpty
                                    ? item.chapterTitle
                                    : '1 new chapter')
                                : 'Chapter ${item.chapterNumber.toString().replaceAll(RegExp(r'\.0$'), '')} • Page ${item.page + 1}',
                            style: TextStyle(
                              fontSize: 12,
                              color: item.isUpdate ? Colors.white70 : Colors.white54,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(width: 8),
              // Relative timestamp
              Text(
                _formatTimeAgo(item.timestamp),
                style: const TextStyle(fontSize: 11, color: Colors.white38),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
