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
  final double initialOffset;

  const ReaderArgs({
    required this.manga,
    required this.chapter,
    this.initialPage = 0,
    this.initialOffset = 0.0,
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
  final double currentOffset;
  final bool isLoading;
  final String? error;

  const ReaderState({
    this.pages = const [],
    this.currentPage = 0,
    this.currentOffset = 0.0,
    this.isLoading = false,
    this.error,
  });

  ReaderState copyWith({
    List<MangaPage>? pages,
    int? currentPage,
    double? currentOffset,
    bool? isLoading,
    String? error,
  }) {
    return ReaderState(
      pages: pages ?? this.pages,
      currentPage: currentPage ?? this.currentPage,
      currentOffset: currentOffset ?? this.currentOffset,
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
          currentOffset: arg.initialOffset,
          isLoading: false,
        );

        await AppDatabase.instance.recordHistory(
          manga: arg.manga,
          chapter: arg.chapter,
          page: arg.initialPage,
          scrollOffset: arg.initialOffset,
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
        currentOffset: arg.initialOffset,
        isLoading: false,
      );

      // Record reading history in SQLite
      await AppDatabase.instance.recordHistory(
        manga: arg.manga,
        chapter: arg.chapter,
        page: arg.initialPage,
        scrollOffset: arg.initialOffset,
      );
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  void onPageChanged(int index) {
    if (index == state.currentPage) return;
    state = state.copyWith(currentPage: index, currentOffset: 0.0);

    final isFinished = state.pages.isNotEmpty && index >= state.pages.length - 1;
    AppDatabase.instance.updateChapterProgress(
      arg.chapter.id,
      index,
      isFinished,
      scrollOffset: 0.0,
      mangaId: arg.manga.id,
      chapterNumber: arg.chapter.number,
      chapterUrl: arg.chapter.url,
    );

    AppDatabase.instance.recordHistory(
      manga: arg.manga,
      chapter: arg.chapter,
      page: index,
      scrollOffset: 0.0,
    );
  }

  void onPositionChanged(int index, double offset) {
    if (index == state.currentPage && (offset - state.currentOffset).abs() < 0.01) return;
    state = state.copyWith(currentPage: index, currentOffset: offset);

    final isFinished = state.pages.isNotEmpty && index >= state.pages.length - 1;
    AppDatabase.instance.updateChapterProgress(
      arg.chapter.id,
      index,
      isFinished,
      scrollOffset: offset,
      mangaId: arg.manga.id,
      chapterNumber: arg.chapter.number,
      chapterUrl: arg.chapter.url,
    );

    AppDatabase.instance.recordHistory(
      manga: arg.manga,
      chapter: arg.chapter,
      page: index,
      scrollOffset: offset,
    );
  }
}

final readerProvider = StateNotifierProvider.family<ReaderNotifier, ReaderState, ReaderArgs>(
  (ref, args) => ReaderNotifier(args),
);
