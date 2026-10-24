import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:extended_image/extended_image.dart';
import 'package:scrollable_positioned_list/scrollable_positioned_list.dart';
import '../../../core/database/app_database.dart';
import '../../../core/database/models/manga_page.dart';
import '../../../core/parser/parser_registry.dart';
import '../providers/reader_provider.dart';

class MangaReaderScreen extends ConsumerStatefulWidget {
  final ReaderArgs args;

  const MangaReaderScreen({super.key, required this.args});

  @override
  ConsumerState<MangaReaderScreen> createState() => _MangaReaderScreenState();
}

class _MangaReaderScreenState extends ConsumerState<MangaReaderScreen> {
  bool _showHud = true;
  late ExtendedPageController _pageController;
  final ItemScrollController _itemScrollController = ItemScrollController();
  final ScrollOffsetController _scrollOffsetController = ScrollOffsetController();
  final ItemPositionsListener _itemPositionsListener = ItemPositionsListener.create();
  bool _didApplyInitialOffset = false;

  @override
  void initState() {
    super.initState();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    _pageController = ExtendedPageController(initialPage: widget.args.initialPage);

    _itemPositionsListener.itemPositions.addListener(_onWebtoonPositionChanged);
  }

  void _onWebtoonPositionChanged() {
    final positions = _itemPositionsListener.itemPositions.value.toList();
    if (positions.isEmpty) return;

    // Reading focal point: 35% from the top of the viewport
    const double focalPoint = 0.35;

    ItemPosition? target;
    for (final pos in positions) {
      if (pos.itemLeadingEdge <= focalPoint && pos.itemTrailingEdge > focalPoint) {
        target = pos;
        break;
      }
    }

    if (target == null) {
      final visible = positions.where((p) => p.itemTrailingEdge > 0 && p.itemLeadingEdge < 1.0).toList();
      if (visible.isNotEmpty) {
        visible.sort((a, b) {
          final visA = a.itemTrailingEdge.clamp(0.0, 1.0) - a.itemLeadingEdge.clamp(0.0, 1.0);
          final visB = b.itemTrailingEdge.clamp(0.0, 1.0) - b.itemLeadingEdge.clamp(0.0, 1.0);
          return visB.compareTo(visA);
        });
        target = visible.first;
      } else {
        positions.sort((a, b) => a.itemLeadingEdge.compareTo(b.itemLeadingEdge));
        target = positions.first;
      }
    }

    ref.read(readerProvider(widget.args).notifier).onPositionChanged(
      target.index,
      target.itemLeadingEdge,
    );
  }

  void _applyInitialSubPageOffset() {
    if (_didApplyInitialOffset) return;
    _didApplyInitialOffset = true;

    final initialOffset = widget.args.initialOffset;
    if (initialOffset < -0.02) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        final screenHeight = MediaQuery.of(context).size.height;
        final scrollDelta = (-initialOffset * screenHeight).clamp(0.0, screenHeight * 3);
        if (scrollDelta > 5) {
          try {
            if (_itemScrollController.isAttached) {
              _scrollOffsetController.animateScroll(
                offset: scrollDelta,
                duration: const Duration(milliseconds: 250),
                curve: Curves.easeOutCubic,
              );
            }
          } catch (_) {}
        }
      });
    }
  }

  @override
  void dispose() {
    _saveFinalProgress();
    _itemPositionsListener.itemPositions.removeListener(_onWebtoonPositionChanged);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    _pageController.dispose();
    super.dispose();
  }

  void _saveFinalProgress() {
    try {
      final readerState = ref.read(readerProvider(widget.args));
      final activeCh = readerState.activeChapter;
      final currentPage = readerState.currentPage;
      final currentOffset = readerState.currentOffset;
      final isFinished = readerState.pages.isNotEmpty && currentPage >= readerState.pages.length - 1;

      AppDatabase.instance.updateChapterProgress(
        activeCh.id,
        currentPage,
        isFinished,
        scrollOffset: currentOffset,
        mangaId: widget.args.manga.id,
        chapterNumber: activeCh.number,
        chapterUrl: activeCh.url,
      );

      AppDatabase.instance.recordHistory(
        manga: widget.args.manga,
        chapter: activeCh,
        page: currentPage,
        scrollOffset: currentOffset,
      );
    } catch (_) {}
  }

  void _toggleHud() {
    setState(() {
      _showHud = !_showHud;
    });
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<ReaderState>(readerProvider(widget.args), (prev, next) {
      if (next.prependedCount != null && next.prependedCount! > 0) {
        final count = next.prependedCount!;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          try {
            final positions = _itemPositionsListener.itemPositions.value.toList();
            if (positions.isNotEmpty) {
              positions.sort((a, b) => a.index.compareTo(b.index));
              final firstPos = positions.first;
              _itemScrollController.jumpTo(
                index: firstPos.index + count,
                alignment: firstPos.itemLeadingEdge,
              );
            }
          } catch (_) {}
        });
      }
    });

    final readerState = ref.watch(readerProvider(widget.args));
    final readerNotifier = ref.read(readerProvider(widget.args).notifier);
    final readerMode = ref.watch(readerModeProvider);
    final parser = ParserRegistry.instance.getParser(widget.args.manga.sourceId);

    if (readerState.isLoading) {
      return Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(color: Color(0xFF00F0FF)),
              const SizedBox(height: 16),
              Text(
                'Loading ${widget.args.chapter.title}...',
                style: const TextStyle(color: Colors.white70, fontSize: 13),
              ),
            ],
          ),
        ),
      );
    }

    if (readerState.error != null) {
      return Scaffold(
        backgroundColor: Colors.black,
        appBar: AppBar(backgroundColor: Colors.transparent),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.error_outline, size: 48, color: Colors.redAccent),
                const SizedBox(height: 12),
                const Text(
                  'Failed to load chapter pages',
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Text(
                  readerState.error!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.white60, fontSize: 12),
                ),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () => readerNotifier.loadPages(),
                  child: const Text('Retry'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final activeChapter = readerState.activeChapter;
    final totalPages = readerState.pages.length;
    final prevChapter = readerNotifier.getPreviousChapter(activeChapter);
    final nextChapter = readerNotifier.getNextChapter(activeChapter);

    return PopScope(
      canPop: true,
      onPopInvokedWithResult: (didPop, result) {
        _saveFinalProgress();
      },
      child: Scaffold(
        backgroundColor: Colors.black,
        body: Stack(
          children: [
            // 1. READER VIEW CANVAS
            GestureDetector(
              onTap: _toggleHud,
              behavior: HitTestBehavior.opaque,
              child: readerMode == ReaderMode.webtoon
                  ? _buildWebtoonView(readerState, readerNotifier, parser?.headers)
                  : _buildPagedView(readerState, readerNotifier, parser?.headers, readerMode),
            ),

            // 2. TOP HUD (App Bar)
            AnimatedPositioned(
              duration: const Duration(milliseconds: 200),
              top: _showHud ? 0 : -100,
              left: 0,
              right: 0,
              child: Container(
                padding: EdgeInsets.only(
                  top: MediaQuery.of(context).padding.top + 8,
                  bottom: 12,
                  left: 8,
                  right: 16,
                ),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.black.withValues(alpha: 0.85),
                      Colors.transparent,
                    ],
                  ),
                ),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back, color: Colors.white),
                      onPressed: () {
                        _saveFinalProgress();
                        Navigator.pop(context);
                      },
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            widget.args.manga.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            activeChapter.title.isNotEmpty ? activeChapter.title : widget.args.chapter.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(color: Color(0xFF00F0FF), fontSize: 12, fontWeight: FontWeight.w600),
                          ),
                        ],
                      ),
                    ),
                    // Reader Mode Switcher Popup
                    PopupMenuButton<ReaderMode>(
                      icon: const Icon(Icons.chrome_reader_mode, color: Colors.white),
                      tooltip: 'Reader Mode',
                      onSelected: (mode) {
                        ref.read(readerModeProvider.notifier).state = mode;
                      },
                      itemBuilder: (ctx) => [
                        const PopupMenuItem(
                          value: ReaderMode.webtoon,
                          child: Text('Webtoon (Vertical Continuous)'),
                        ),
                        const PopupMenuItem(
                          value: ReaderMode.pagedRtl,
                          child: Text('Paged RTL (Manga Standard)'),
                        ),
                        const PopupMenuItem(
                          value: ReaderMode.pagedLtr,
                          child: Text('Paged LTR (Western Comic)'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            // 3. BOTTOM HUD (Scrubber & Page info & Prev/Next controls)
            AnimatedPositioned(
              duration: const Duration(milliseconds: 200),
              bottom: _showHud ? 0 : -140,
              left: 0,
              right: 0,
              child: Container(
                padding: EdgeInsets.only(
                  bottom: MediaQuery.of(context).padding.bottom + 12,
                  top: 14,
                  left: 16,
                  right: 16,
                ),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.bottomCenter,
                    end: Alignment.topCenter,
                    colors: [
                      Colors.black.withValues(alpha: 0.92),
                      Colors.transparent,
                    ],
                  ),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Chapter navigation controls: Prev Ch | Title | Next Ch
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        TextButton.icon(
                          style: TextButton.styleFrom(
                            foregroundColor: prevChapter != null ? Colors.white : Colors.white24,
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          ),
                          icon: const Icon(Icons.skip_previous, size: 18),
                          label: const Text('Prev Ch', style: TextStyle(fontSize: 12)),
                          onPressed: prevChapter != null
                              ? () {
                                  readerNotifier.jumpToChapter(prevChapter);
                                  if (readerMode == ReaderMode.webtoon && _itemScrollController.isAttached) {
                                    _itemScrollController.jumpTo(index: 0);
                                  } else if (_pageController.hasClients) {
                                    _pageController.jumpToPage(0);
                                  }
                                }
                              : null,
                        ),
                        Expanded(
                          child: Text(
                            activeChapter.title,
                            textAlign: TextAlign.center,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Color(0xFF00F0FF),
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                            ),
                          ),
                        ),
                        TextButton.icon(
                          style: TextButton.styleFrom(
                            foregroundColor: nextChapter != null ? Colors.white : Colors.white24,
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          ),
                          label: const Text('Next Ch', style: TextStyle(fontSize: 12)),
                          icon: const Icon(Icons.skip_next, size: 18),
                          onPressed: nextChapter != null
                              ? () {
                                  readerNotifier.jumpToChapter(nextChapter);
                                  if (readerMode == ReaderMode.webtoon && _itemScrollController.isAttached) {
                                    _itemScrollController.jumpTo(index: 0);
                                  } else if (_pageController.hasClients) {
                                    _pageController.jumpToPage(0);
                                  }
                                }
                              : null,
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Halaman ${readerState.currentPage + 1} / ${totalPages > 0 ? totalPages : 1}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          readerMode == ReaderMode.webtoon
                              ? 'Webtoon (Continuous)'
                              : readerMode == ReaderMode.pagedRtl
                                  ? 'Paged RTL'
                                  : 'Paged LTR',
                          style: const TextStyle(color: Color(0xFF00F0FF), fontSize: 11),
                        ),
                      ],
                    ),
                    if (totalPages > 1)
                      Slider(
                        value: readerState.currentPage.toDouble().clamp(0.0, (totalPages - 1).toDouble()),
                        min: 0,
                        max: (totalPages - 1).toDouble(),
                        divisions: totalPages > 1 ? totalPages - 1 : 1,
                        activeColor: const Color(0xFF00F0FF),
                        inactiveColor: Colors.white24,
                        onChanged: (val) {
                          final target = val.round();
                          if (readerMode == ReaderMode.webtoon) {
                            int targetItemIdx = -1;
                            for (int i = 0; i < readerState.items.length; i++) {
                              final item = readerState.items[i];
                              if (item is ReaderPageItem &&
                                  item.chapter.id == activeChapter.id &&
                                  item.pageIndex == target) {
                                targetItemIdx = i;
                                break;
                              }
                            }
                            if (targetItemIdx >= 0 && _itemScrollController.isAttached) {
                              _itemScrollController.jumpTo(index: targetItemIdx);
                            }
                          } else {
                            _pageController.jumpToPage(target);
                          }
                          readerNotifier.onPageChanged(target);
                        },
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPageItem(
    MangaPage page,
    Map<String, String>? headers, {
    bool inPageView = false,
  }) {
    final isLocal = !page.url.startsWith('http');

    if (isLocal) {
      return ExtendedImage.file(
        File(page.url),
        fit: BoxFit.contain,
        mode: ExtendedImageMode.gesture,
        initGestureConfigHandler: (state) {
          return GestureConfig(
            minScale: 1.0,
            animationMinScale: 0.8,
            maxScale: 3.0,
            animationMaxScale: 3.5,
            speed: 1.0,
            inertialSpeed: 100.0,
            initialScale: 1.0,
            inPageView: inPageView,
          );
        },
        loadStateChanged: (state) {
          if (state.extendedImageLoadState == LoadState.loading) {
            return inPageView
                ? const Center(
                    child: CircularProgressIndicator(color: Color(0xFF00F0FF), strokeWidth: 2),
                  )
                : Container(
                    height: 450,
                    color: Colors.black,
                    child: const Center(
                      child: CircularProgressIndicator(color: Color(0xFF00F0FF), strokeWidth: 2),
                    ),
                  );
          }
          if (state.extendedImageLoadState == LoadState.failed) {
            return Container(
              height: 300,
              color: Colors.black26,
              child: const Center(
                child: Icon(Icons.broken_image_outlined, color: Colors.grey, size: 36),
              ),
            );
          }
          return null;
        },
      );
    }

    return ExtendedImage.network(
      page.url,
      fit: BoxFit.contain,
      headers: headers,
      cache: true,
      mode: ExtendedImageMode.gesture,
      initGestureConfigHandler: (state) {
        return GestureConfig(
          minScale: 1.0,
          animationMinScale: 0.8,
          maxScale: 3.0,
          animationMaxScale: 3.5,
          speed: 1.0,
          inertialSpeed: 100.0,
          initialScale: 1.0,
          inPageView: inPageView,
        );
      },
      loadStateChanged: (state) {
        if (state.extendedImageLoadState == LoadState.loading) {
          return inPageView
              ? const Center(
                  child: CircularProgressIndicator(color: Color(0xFF00F0FF), strokeWidth: 2),
                )
                : Container(
                    height: 450,
                    color: Colors.black,
                    child: const Center(
                      child: CircularProgressIndicator(color: Color(0xFF00F0FF), strokeWidth: 2),
                    ),
                  );
        }
        if (state.extendedImageLoadState == LoadState.failed) {
          return Container(
            height: 300,
            color: Colors.black26,
            child: const Center(
              child: Icon(Icons.broken_image_outlined, color: Colors.grey, size: 36),
            ),
          );
        }
        return null;
      },
    );
  }

  Widget _buildChapterTransition(ReaderChapterTransitionItem item) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
      padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
      decoration: BoxDecoration(
        color: const Color(0xFF16181F),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF00F0FF).withValues(alpha: 0.3)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.check_circle_outline, size: 16, color: Colors.grey),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  'Akhir ${item.fromChapter.title}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Colors.grey, fontSize: 13),
                ),
              ),
            ],
          ),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 10),
            child: Divider(color: Color(0xFF00F0FF), thickness: 0.8),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.arrow_downward_rounded, size: 18, color: Color(0xFF00F0FF)),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  item.toChapter.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBoundary(ReaderBoundaryItem item, ReaderNotifier notifier) {
    final isTop = item.isTop;
    final hasMore = item.hasMore;
    final isLoading = item.isLoading;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 16),
      margin: const EdgeInsets.symmetric(vertical: 8),
      color: Colors.black,
      child: Center(
        child: isLoading
            ? Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(color: Color(0xFF00F0FF), strokeWidth: 2),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    isTop ? 'Memuat chapter sebelumnya...' : 'Memuat chapter selanjutnya...',
                    style: const TextStyle(color: Colors.white70, fontSize: 12),
                  ),
                ],
              )
            : hasMore
                ? InkWell(
                    onTap: isTop ? () => notifier.loadPreviousChapter() : () => notifier.loadNextChapter(),
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1B1D24),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.white12),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            isTop ? Icons.arrow_upward_rounded : Icons.arrow_downward_rounded,
                            size: 16,
                            color: const Color(0xFF00F0FF),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            isTop
                                ? '⬆️ Scroll atau ketuk untuk chapter sebelumnya'
                                : '⬇️ Scroll atau ketuk untuk chapter selanjutnya',
                            style: const TextStyle(color: Colors.white70, fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                  )
                : Text(
                    isTop ? 'Ini adalah chapter pertama' : 'Ini adalah chapter terbaru',
                    style: const TextStyle(color: Colors.white38, fontSize: 12),
                  ),
      ),
    );
  }

  // Webtoon (Continuous multi-chapter vertical list via ScrollablePositionedList)
  Widget _buildWebtoonView(
    ReaderState readerState,
    ReaderNotifier readerNotifier,
    Map<String, String>? headers,
  ) {
    _applyInitialSubPageOffset();
    final initialIndex = (widget.args.initialPage + 1).clamp(0, readerState.items.isEmpty ? 0 : readerState.items.length - 1);

    return ScrollablePositionedList.builder(
      itemScrollController: _itemScrollController,
      scrollOffsetController: _scrollOffsetController,
      itemPositionsListener: _itemPositionsListener,
      initialScrollIndex: initialIndex,
      initialAlignment: 0.0,
      itemCount: readerState.items.length,
      itemBuilder: (context, index) {
        final item = readerState.items[index];
        if (item is ReaderPageItem) {
          return _buildPageItem(item.page, headers, inPageView: false);
        } else if (item is ReaderChapterTransitionItem) {
          return _buildChapterTransition(item);
        } else if (item is ReaderBoundaryItem) {
          return _buildBoundary(item, readerNotifier);
        }
        return const SizedBox.shrink();
      },
    );
  }

  // Paged Horizontal Viewer (RTL or LTR)
  Widget _buildPagedView(
    ReaderState readerState,
    ReaderNotifier notifier,
    Map<String, String>? headers,
    ReaderMode mode,
  ) {
    final pages = readerState.pages;
    final isRtl = mode == ReaderMode.pagedRtl;
    final activeChapter = readerState.activeChapter;
    final nextChapter = notifier.getNextChapter(activeChapter);

    final hasNextCard = nextChapter != null;
    final totalCount = pages.length + (hasNextCard ? 1 : 0);

    return ExtendedImageGesturePageView.builder(
      controller: _pageController,
      reverse: isRtl,
      itemCount: totalCount,
      onPageChanged: (index) {
        if (index < pages.length) {
          notifier.onPageChanged(index);
        }
      },
      itemBuilder: (context, index) {
        if (index < pages.length) {
          final page = pages[index];
          return _buildPageItem(page, headers, inPageView: true);
        }
        return Center(
          child: Container(
            margin: const EdgeInsets.all(32),
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: const Color(0xFF1B1D24),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFF00F0FF).withValues(alpha: 0.4)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Akhir ${activeChapter.title}',
                  style: const TextStyle(color: Colors.white70, fontSize: 14),
                ),
                const SizedBox(height: 16),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF00F0FF),
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  ),
                  icon: const Icon(Icons.arrow_forward),
                  label: Text('Lanjut ke ${nextChapter!.title}', style: const TextStyle(fontWeight: FontWeight.bold)),
                  onPressed: () {
                    notifier.jumpToChapter(nextChapter);
                    _pageController.jumpToPage(0);
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
