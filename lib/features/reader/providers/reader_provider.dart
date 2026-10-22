import 'package:flutter_riverpod/legacy.dart';
import '../../../core/database/app_database.dart';
import '../../../core/database/models/manga.dart';
import '../../../core/database/models/chapter.dart';
import '../../../core/database/models/manga_page.dart';
import '../../../core/parser/parser_registry.dart';
import '../../../core/download/download_manager.dart';

enum ReaderMode {
  webtoon,
  pagedRtl,
  pagedLtr,
}

final readerModeProvider = StateProvider<ReaderMode>((ref) => ReaderMode.webtoon);

class ReaderArgs {
  final Manga manga;
  final MangaChapter chapter;
  final int initialPage;

  const ReaderArgs({
    required this.manga,
    required this.chapter,
    this.initialPage = 0,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ReaderArgs &&
          runtimeType == other.runtimeType &&
          chapter.id == other.chapter.id;

  @override
  int get hashCode => chapter.id.hashCode;
}

class ReaderState {
  final List<MangaPage> pages;
  final int currentPage;
  final bool isLoading;
  final String? error;

  const ReaderState({
    this.pages = const [],
    this.currentPage = 0,
    this.isLoading = false,
    this.error,
  });

  ReaderState copyWith({
    List<MangaPage>? pages,
    int? currentPage,
    bool? isLoading,
    String? error,
  }) {
    return ReaderState(
      pages: pages ?? this.pages,
      currentPage: currentPage ?? this.currentPage,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }
}

class ReaderNotifier extends StateNotifier<ReaderState> {
  final ReaderArgs arg;

  ReaderNotifier(this.arg) : super(const ReaderState()) {
    loadPages();
  }

  Future<void> loadPages() async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      // 1. Check if chapter is downloaded locally on device
      final downloadedPages = await DownloadManager.instance.getDownloadedPages(arg.chapter);
      if (downloadedPages != null && downloadedPages.isNotEmpty) {
        state = state.copyWith(
          pages: downloadedPages,
          currentPage: arg.initialPage,
          isLoading: false,
        );

        await AppDatabase.instance.recordHistory(
          manga: arg.manga,
          chapter: arg.chapter,
          page: arg.initialPage,
        );
        return;
      }

      // 2. Fetch from online parser
      final parser = ParserRegistry.instance.getParser(arg.manga.sourceId) ??
          ParserRegistry.instance.defaultParser;

      final pages = await parser.getPages(arg.chapter);
      state = state.copyWith(
        pages: pages,
        currentPage: arg.initialPage,
        isLoading: false,
      );

      // Record reading history in SQLite
      await AppDatabase.instance.recordHistory(
        manga: arg.manga,
        chapter: arg.chapter,
        page: arg.initialPage,
      );
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  void onPageChanged(int index) {
    if (index == state.currentPage) return;
    state = state.copyWith(currentPage: index);

    final isFinished = index >= state.pages.length - 1;
    AppDatabase.instance.updateChapterProgress(
      arg.chapter.id,
      index,
      isFinished,
    );

    AppDatabase.instance.recordHistory(
      manga: arg.manga,
      chapter: arg.chapter,
      page: index,
    );
  }
}

final readerProvider = StateNotifierProvider.family<ReaderNotifier, ReaderState, ReaderArgs>(
  (ref, args) => ReaderNotifier(args),
);
