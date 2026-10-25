import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import '../../../core/database/models/manga.dart';
import '../../../core/parser/manga_parser.dart';
import '../../../core/parser/parser_registry.dart';

final activeParserProvider = StateProvider<MangaParser>((ref) {
  return ParserRegistry.instance.activeParser;
});

final searchQueryProvider = StateProvider<String>((ref) => '');
final selectedCategoryProvider = StateProvider<String>((ref) => 'All');
final selectedGenreProvider = StateProvider<String>((ref) => 'All');
final selectedGenresProvider = StateProvider<Set<String>>((ref) => {});
final bottomNavIndexProvider = StateProvider<int>((ref) => 0);

class CatalogState {
  final List<Manga> items;
  final int page;
  final bool isLoading;
  final bool hasMore;
  final String? error;

  const CatalogState({
    this.items = const [],
    this.page = 1,
    this.isLoading = false,
    this.hasMore = true,
    this.error,
  });

  CatalogState copyWith({
    List<Manga>? items,
    int? page,
    bool? isLoading,
    bool? hasMore,
    String? error,
  }) {
    return CatalogState(
      items: items ?? this.items,
      page: page ?? this.page,
      isLoading: isLoading ?? this.isLoading,
      hasMore: hasMore ?? this.hasMore,
      error: error,
    );
  }
}

class CatalogNotifier extends StateNotifier<CatalogState> {
  final Ref ref;

  CatalogNotifier(this.ref) : super(const CatalogState()) {
    loadFirstPage();
  }

  Future<void> loadFirstPage() async {
    state = state.copyWith(isLoading: true, error: null, page: 1);
    final parser = ref.read(activeParserProvider);
    final query = ref.read(searchQueryProvider);
    final category = ref.read(selectedCategoryProvider);
    final genres = ref.read(selectedGenresProvider);
    final singleGenre = ref.read(selectedGenreProvider);

    final activeGenres = genres.isNotEmpty
        ? genres.toList()
        : (singleGenre != 'All' ? [singleGenre] : null);

    try {
      final items = await parser.getList(
        page: 1,
        order: SortOrder.updated,
        query: query.isNotEmpty ? query : null,
        category: category != 'All' ? category : null,
        genre: activeGenres != null && activeGenres.isNotEmpty ? activeGenres.first : null,
        genres: activeGenres,
      );

      state = state.copyWith(
        items: items,
        isLoading: false,
        page: 1,
        hasMore: items.isNotEmpty,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: e.toString(),
      );
    }
  }

  Future<void> loadNextPage() async {
    if (state.isLoading || !state.hasMore) return;

    state = state.copyWith(isLoading: true);
    final parser = ref.read(activeParserProvider);
    final query = ref.read(searchQueryProvider);
    final category = ref.read(selectedCategoryProvider);
    final genres = ref.read(selectedGenresProvider);
    final singleGenre = ref.read(selectedGenreProvider);
    final nextPage = state.page + 1;

    final activeGenres = genres.isNotEmpty
        ? genres.toList()
        : (singleGenre != 'All' ? [singleGenre] : null);

    try {
      final nextItems = await parser.getList(
        page: nextPage,
        order: SortOrder.updated,
        query: query.isNotEmpty ? query : null,
        category: category != 'All' ? category : null,
        genre: activeGenres != null && activeGenres.isNotEmpty ? activeGenres.first : null,
        genres: activeGenres,
      );

      state = state.copyWith(
        items: [...state.items, ...nextItems],
        isLoading: false,
        page: nextPage,
        hasMore: nextItems.isNotEmpty,
      );
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }
}

final catalogProvider = StateNotifierProvider<CatalogNotifier, CatalogState>((ref) {
  // Reload when parser, search query, category, or genres change
  ref.watch(activeParserProvider);
  ref.watch(searchQueryProvider);
  ref.watch(selectedCategoryProvider);
  ref.watch(selectedGenreProvider);
  ref.watch(selectedGenresProvider);
  return CatalogNotifier(ref);
});
