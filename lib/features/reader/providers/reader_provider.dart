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

abstract class ReaderItem {
  const ReaderItem();
}

class ReaderPageItem extends ReaderItem {
  final MangaPage page;
  final MangaChapter chapter;
  final int pageIndex; // 0-based page index in chapter
  final int totalPages;

  const ReaderPageItem({
    required this.page,
    required this.chapter,
    required this.pageIndex,
    required this.totalPages,
  });
}

class ReaderChapterTransitionItem extends ReaderItem {
  final MangaChapter fromChapter;
  final MangaChapter toChapter;

  const ReaderChapterTransitionItem({
    required this.fromChapter,
    required this.toChapter,
  });
}

class ReaderBoundaryItem extends ReaderItem {
  final MangaChapter chapter;
  final bool isTop;
  final bool hasMore;
  final bool isLoading;

  const ReaderBoundaryItem({
    required this.chapter,
    required this.isTop,
    required this.hasMore,
    this.isLoading = false,
  });

  ReaderBoundaryItem copyWith({
    MangaChapter? chapter,
    bool? isTop,
    bool? hasMore,
    bool? isLoading,
  }) {
    return ReaderBoundaryItem(
      chapter: chapter ?? this.chapter,
      isTop: isTop ?? this.isTop,
      hasMore: hasMore ?? this.hasMore,
      isLoading: isLoading ?? this.isLoading,
    );
  }
}

class ReaderArgs {
  final Manga manga;
  final MangaChapter chapter;
  final int initialPage;
  final double initialOffset;
  final List<MangaChapter>? chapters;

  const ReaderArgs({
    required this.manga,
    required this.chapter,
    this.initialPage = 0,
    this.initialOffset = 0.0,
    this.chapters,
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
  final List<MangaPage> pages; // Current chapter's pages
  final List<ReaderItem> items; // Flattened list for continuous Webtoon
  final List<MangaChapter> chapters; // Sorted ascending chronologically (1..N)
  final MangaChapter? currentChapter;
  final int currentPage;
  final double currentOffset;
  final bool isLoading;
  final bool isLoadingNext;
  final bool isLoadingPrev;
  final int? prependedCount;
  final String? error;

  const ReaderState({
    this.pages = const [],
    this.items = const [],
    this.chapters = const [],
    this.currentChapter,
    this.currentPage = 0,
    this.currentOffset = 0.0,
    this.isLoading = false,
    this.isLoadingNext = false,
    this.isLoadingPrev = false,
    this.prependedCount,
    this.error,
  });

  MangaChapter get activeChapter =>
      currentChapter ??
      (chapters.isNotEmpty
          ? chapters.first
          : const MangaChapter(id: '', mangaId: '', title: '', number: 0.0, url: ''));

  ReaderState copyWith({
    List<MangaPage>? pages,
    List<ReaderItem>? items,
    List<MangaChapter>? chapters,
    MangaChapter? currentChapter,
    int? currentPage,
    double? currentOffset,
    bool? isLoading,
    bool? isLoadingNext,
    bool? isLoadingPrev,
    int? prependedCount,
    String? error,
  }) {
    return ReaderState(
      pages: pages ?? this.pages,
      items: items ?? this.items,
      chapters: chapters ?? this.chapters,
      currentChapter: currentChapter ?? this.currentChapter,
      currentPage: currentPage ?? this.currentPage,
      currentOffset: currentOffset ?? this.currentOffset,
      isLoading: isLoading ?? this.isLoading,
      isLoadingNext: isLoadingNext ?? this.isLoadingNext,
      isLoadingPrev: isLoadingPrev ?? this.isLoadingPrev,
      prependedCount: prependedCount,
      error: error,
    );
  }
}

class ReaderNotifier extends StateNotifier<ReaderState> {
  final ReaderArgs arg;

  ReaderNotifier(this.arg) : super(ReaderState(currentChapter: arg.chapter)) {
    loadPages();
  }

  MangaChapter? getPreviousChapter(MangaChapter current) {
    if (state.chapters.isEmpty) return null;
    final idx = state.chapters.indexWhere((c) => c.id == current.id);
    if (idx > 0) return state.chapters[idx - 1];
    final earlier = state.chapters.where((c) => c.number < current.number).toList();
    return earlier.isNotEmpty ? earlier.last : null;
  }

  MangaChapter? getNextChapter(MangaChapter current) {
    if (state.chapters.isEmpty) return null;
    final idx = state.chapters.indexWhere((c) => c.id == current.id);
    if (idx >= 0 && idx < state.chapters.length - 1) return state.chapters[idx + 1];
    final later = state.chapters.where((c) => c.number > current.number).toList();
    return later.isNotEmpty ? later.first : null;
  }

  Future<List<MangaPage>> _fetchChapterPages(MangaChapter chapter) async {
    try {
      final downloadedPages = await DownloadManager.instance.getDownloadedPages(chapter);
      if (downloadedPages != null && downloadedPages.isNotEmpty) {
        return downloadedPages;
      }
    } catch (_) {}
    final parser = ParserRegistry.instance.getParser(arg.manga.sourceId) ??
        ParserRegistry.instance.defaultParser;
    return await parser.getPages(chapter);
  }

  Future<void> loadPages() async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      // 1. Resolve chapter list sorted ascending (1..N)
      List<MangaChapter> sortedChapters = [];
      if (arg.chapters != null && arg.chapters!.isNotEmpty) {
        sortedChapters = List<MangaChapter>.from(arg.chapters!);
      } else {
        try {
          sortedChapters = await AppDatabase.instance.getChapters(arg.manga.id);
        } catch (_) {}
      }
      if (sortedChapters.isEmpty) {
        sortedChapters = [arg.chapter];
      }
      sortedChapters.sort((a, b) => a.number.compareTo(b.number));

      // 2. Fetch pages for target chapter
      final chapterToLoad = arg.chapter;
      final pages = await _fetchChapterPages(chapterToLoad);
      if (!mounted) return;

      // 3. Build initial items list
      final prevCh = getPreviousChapterForList(sortedChapters, chapterToLoad);
      final nextCh = getNextChapterForList(sortedChapters, chapterToLoad);

      final List<ReaderItem> items = [];
      items.add(ReaderBoundaryItem(
        chapter: chapterToLoad,
        isTop: true,
        hasMore: prevCh != null,
      ));
      for (int i = 0; i < pages.length; i++) {
        items.add(ReaderPageItem(
          page: pages[i],
          chapter: chapterToLoad,
          pageIndex: i,
          totalPages: pages.length,
        ));
      }
      items.add(ReaderBoundaryItem(
        chapter: chapterToLoad,
        isTop: false,
        hasMore: nextCh != null,
      ));

      state = state.copyWith(
        pages: pages,
        items: items,
        chapters: sortedChapters,
        currentChapter: chapterToLoad,
        currentPage: arg.initialPage,
        currentOffset: arg.initialOffset,
        isLoading: false,
      );

      try {
        await AppDatabase.instance.recordHistory(
          manga: arg.manga,
          chapter: chapterToLoad,
          page: arg.initialPage,
          scrollOffset: arg.initialOffset,
        );
      } catch (_) {}
    } catch (e) {
      if (mounted) {
        state = state.copyWith(isLoading: false, error: e.toString());
      }
    }
  }

  MangaChapter? getPreviousChapterForList(List<MangaChapter> list, MangaChapter current) {
    final idx = list.indexWhere((c) => c.id == current.id);
    if (idx > 0) return list[idx - 1];
    final earlier = list.where((c) => c.number < current.number).toList();
    return earlier.isNotEmpty ? earlier.last : null;
  }

  MangaChapter? getNextChapterForList(List<MangaChapter> list, MangaChapter current) {
    final idx = list.indexWhere((c) => c.id == current.id);
    if (idx >= 0 && idx < list.length - 1) return list[idx + 1];
    final later = list.where((c) => c.number > current.number).toList();
    return later.isNotEmpty ? later.first : null;
  }

  Future<void> loadNextChapter() async {
    if (state.isLoadingNext || state.items.isEmpty) return;

    // Find last chapter currently loaded
    MangaChapter? lastCh;
    for (int i = state.items.length - 1; i >= 0; i--) {
      final item = state.items[i];
      if (item is ReaderPageItem) {
        lastCh = item.chapter;
        break;
      }
    }
    if (lastCh == null) return;

    final nextCh = getNextChapter(lastCh);
    if (nextCh == null) return;

    // Show loading in boundary
    final lastItem = state.items.last;
    if (lastItem is ReaderBoundaryItem && !lastItem.isTop) {
      final updated = List<ReaderItem>.from(state.items);
      updated[updated.length - 1] = lastItem.copyWith(isLoading: true);
      state = state.copyWith(items: updated, isLoadingNext: true);
    } else {
      state = state.copyWith(isLoadingNext: true);
    }

    try {
      final newPages = await _fetchChapterPages(nextCh);
      if (newPages.isEmpty) {
        state = state.copyWith(isLoadingNext: false);
        return;
      }

      final furtherNext = getNextChapter(nextCh);
      final updatedItems = List<ReaderItem>.from(state.items);

      if (updatedItems.isNotEmpty && updatedItems.last is ReaderBoundaryItem) {
        updatedItems.removeLast();
      }

      // Add chapter transition card
      updatedItems.add(ReaderChapterTransitionItem(
        fromChapter: lastCh,
        toChapter: nextCh,
      ));

      // Append pages
      for (int i = 0; i < newPages.length; i++) {
        updatedItems.add(ReaderPageItem(
          page: newPages[i],
          chapter: nextCh,
          pageIndex: i,
          totalPages: newPages.length,
        ));
      }

      // Append new bottom boundary
      updatedItems.add(ReaderBoundaryItem(
        chapter: nextCh,
        isTop: false,
        hasMore: furtherNext != null,
      ));

      if (!mounted) return;
      state = state.copyWith(
        items: updatedItems,
        isLoadingNext: false,
      );
    } catch (e) {
      if (!mounted) return;
      final reverted = List<ReaderItem>.from(state.items);
      if (reverted.isNotEmpty && reverted.last is ReaderBoundaryItem) {
        reverted[reverted.length - 1] = (reverted.last as ReaderBoundaryItem).copyWith(isLoading: false);
      }
      state = state.copyWith(items: reverted, isLoadingNext: false);
    }
  }

  Future<void> loadPreviousChapter() async {
    if (state.isLoadingPrev || state.items.isEmpty) return;

    // Find first chapter currently loaded
    MangaChapter? firstCh;
    for (int i = 0; i < state.items.length; i++) {
      final item = state.items[i];
      if (item is ReaderPageItem) {
        firstCh = item.chapter;
        break;
      }
    }
    if (firstCh == null) return;

    final prevCh = getPreviousChapter(firstCh);
    if (prevCh == null) return;

    // Show loading in top boundary
    final firstItem = state.items.first;
    if (firstItem is ReaderBoundaryItem && firstItem.isTop) {
      final updated = List<ReaderItem>.from(state.items);
      updated[0] = firstItem.copyWith(isLoading: true);
      state = state.copyWith(items: updated, isLoadingPrev: true);
    } else {
      state = state.copyWith(isLoadingPrev: true);
    }

    try {
      final prevPages = await _fetchChapterPages(prevCh);
      if (!mounted) return;
      if (prevPages.isEmpty) {
        state = state.copyWith(isLoadingPrev: false);
        return;
      }

      final furtherPrev = getPreviousChapter(prevCh);
      final updatedItems = List<ReaderItem>.from(state.items);

      if (updatedItems.isNotEmpty && updatedItems.first is ReaderBoundaryItem) {
        updatedItems.removeAt(0);
      }

      final List<ReaderItem> prepended = [];
      prepended.add(ReaderBoundaryItem(
        chapter: prevCh,
        isTop: true,
        hasMore: furtherPrev != null,
      ));
      for (int i = 0; i < prevPages.length; i++) {
        prepended.add(ReaderPageItem(
          page: prevPages[i],
          chapter: prevCh,
          pageIndex: i,
          totalPages: prevPages.length,
        ));
      }
      prepended.add(ReaderChapterTransitionItem(
        fromChapter: prevCh,
        toChapter: firstCh,
      ));

      final countAdded = prepended.length - 1;
      updatedItems.insertAll(0, prepended);

      state = state.copyWith(
        items: updatedItems,
        isLoadingPrev: false,
        prependedCount: countAdded,
      );
    } catch (e) {
      if (!mounted) return;
      final reverted = List<ReaderItem>.from(state.items);
      if (reverted.isNotEmpty && reverted.first is ReaderBoundaryItem) {
        reverted[0] = (reverted.first as ReaderBoundaryItem).copyWith(isLoading: false);
      }
      state = state.copyWith(items: reverted, isLoadingPrev: false);
    }
  }

  Future<void> jumpToChapter(MangaChapter chapter) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final pages = await _fetchChapterPages(chapter);
      if (!mounted) return;
      final prevCh = getPreviousChapter(chapter);
      final nextCh = getNextChapter(chapter);

      final List<ReaderItem> items = [];
      items.add(ReaderBoundaryItem(
        chapter: chapter,
        isTop: true,
        hasMore: prevCh != null,
      ));
      for (int i = 0; i < pages.length; i++) {
        items.add(ReaderPageItem(
          page: pages[i],
          chapter: chapter,
          pageIndex: i,
          totalPages: pages.length,
        ));
      }
      items.add(ReaderBoundaryItem(
        chapter: chapter,
        isTop: false,
        hasMore: nextCh != null,
      ));

      state = state.copyWith(
        pages: pages,
        items: items,
        currentChapter: chapter,
        currentPage: 0,
        currentOffset: 0.0,
        isLoading: false,
      );

      try {
        await AppDatabase.instance.recordHistory(
          manga: arg.manga,
          chapter: chapter,
          page: 0,
          scrollOffset: 0.0,
        );
      } catch (_) {}
    } catch (e) {
      if (mounted) {
        state = state.copyWith(isLoading: false, error: e.toString());
      }
    }
  }

  void onPageChanged(int index) {
    if (index == state.currentPage) return;
    state = state.copyWith(currentPage: index, currentOffset: 0.0);

    final activeCh = state.activeChapter;
    final isFinished = state.pages.isNotEmpty && index >= state.pages.length - 1;
    try {
      AppDatabase.instance.updateChapterProgress(
        activeCh.id,
        index,
        isFinished,
        scrollOffset: 0.0,
        mangaId: arg.manga.id,
        chapterNumber: activeCh.number,
        chapterUrl: activeCh.url,
      ).catchError((_) {});

      AppDatabase.instance.recordHistory(
        manga: arg.manga,
        chapter: activeCh,
        page: index,
        scrollOffset: 0.0,
      ).catchError((_) {});
    } catch (_) {}
  }

  void onPositionChanged(int itemIndex, double offset) {
    if (state.items.isEmpty || itemIndex < 0 || itemIndex >= state.items.length) return;
    final item = state.items[itemIndex];

    if (item is ReaderPageItem) {
      final ch = item.chapter;
      final pageIdx = item.pageIndex;
      final isNewChapter = state.currentChapter?.id != ch.id;

      if (isNewChapter || pageIdx != state.currentPage || (offset - state.currentOffset).abs() >= 0.01) {
        state = state.copyWith(
          currentChapter: ch,
          currentPage: pageIdx,
          currentOffset: offset,
        );

        final isFinished = pageIdx >= item.totalPages - 1;
        try {
          AppDatabase.instance.updateChapterProgress(
            ch.id,
            pageIdx,
            isFinished,
            scrollOffset: offset,
            mangaId: arg.manga.id,
            chapterNumber: ch.number,
            chapterUrl: ch.url,
          ).catchError((_) {});

          AppDatabase.instance.recordHistory(
            manga: arg.manga,
            chapter: ch,
            page: pageIdx,
            scrollOffset: offset,
          ).catchError((_) {});
        } catch (_) {}
      }
    }

    // Trigger auto-append near bottom (within 3 items)
    if (itemIndex >= state.items.length - 3 && !state.isLoadingNext) {
      loadNextChapter();
    }
    // Trigger auto-prepend near top (within 1 item)
    if (itemIndex <= 1 && !state.isLoadingPrev) {
      loadPreviousChapter();
    }
  }
}

final readerProvider = StateNotifierProvider.family<ReaderNotifier, ReaderState, ReaderArgs>(
  (ref, args) => ReaderNotifier(args),
);
