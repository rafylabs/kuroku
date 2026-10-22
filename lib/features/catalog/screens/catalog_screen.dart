import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:extended_image/extended_image.dart';
import '../../../core/database/models/manga.dart';
import '../../../core/parser/parser_registry.dart';
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

  void _showSourcePicker() {
    final parsers = ParserRegistry.instance.allParsers;
    final activeParser = ref.read(activeParserProvider);

    showModalBottomSheet(
      context: context,
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
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                  child: Text(
                    'Select Manga Source',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ),
                const Divider(),
                ...parsers.map((parser) {
                  final isSelected = parser.id == activeParser.id;
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
                    title: Text(
                      parser.name,
                      style: TextStyle(
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                      ),
                    ),
                    subtitle: Text(parser.domain, style: const TextStyle(fontSize: 12)),
                    trailing: isSelected
                        ? Icon(Icons.check_circle, color: Theme.of(context).colorScheme.primary)
                        : null,
                    onTap: () {
                      ref.read(activeParserProvider.notifier).state = parser;
                      Navigator.pop(ctx);
                    },
                  );
                }),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final activeParser = ref.watch(activeParserProvider);
    final catalogState = ref.watch(catalogProvider);

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
                  const Text('Kotatsu', style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 0.5)),
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
            icon: const Icon(Icons.tune),
            onPressed: _showSourcePicker,
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          await ref.read(catalogProvider.notifier).loadFirstPage();
        },
        child: _buildBody(catalogState),
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
                  child: ExtendedImage.network(
                    manga.coverUrl,
                    fit: BoxFit.cover,
                    headers: ref.read(activeParserProvider).headers,
                    cache: true,
                    loadStateChanged: (state) {
                      if (state.extendedImageLoadState == LoadState.loading) {
                        return Container(color: Colors.black26);
                      }
                      if (state.extendedImageLoadState == LoadState.failed) {
                        return Container(
                          color: Colors.black26,
                          child: const Icon(Icons.broken_image, color: Colors.grey),
                        );
                      }
                      return null;
                    },
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
