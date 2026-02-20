import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_html/flutter_html.dart';
import 'package:hume/models/book.dart';
import 'package:hume/models/book_chapter.dart';
import 'package:hume/services/book_service.dart';
import 'package:hume/utils/platform_utils.dart';

class ReaderScreen extends StatefulWidget {
  final Book book;

  const ReaderScreen({super.key, required this.book});

  @override
  State<ReaderScreen> createState() => _ReaderScreenState();
}

class _ReaderScreenState extends State<ReaderScreen>
    with WidgetsBindingObserver {
  late Future<String> _contentFuture;
  late ScrollController _scrollController;
  late BookService _bookService;

  String _content = '';
  String _htmlContent = '';
  double _fontSize = 18;
  List<BookChapter>? _chapters;
  int _currentChapterIndex = 0;
  bool _isLoadingChapter = false;
  bool _isRestoringPosition = false;

  // Reading time tracking
  Timer? _readingTimer;
  int _accumulatedMinutes = 0;
  bool _isTrackingTime = false;

  static const double _lineHeight = 1.8;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _scrollController = ScrollController();
    _currentChapterIndex = widget.book.currentChapterIndex;
    _scrollController.addListener(_onScrollChanged);
    _contentFuture = _loadContent();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive) {
      _pauseReadingTimer();
      _saveReadingPosition();
    } else if (state == AppLifecycleState.resumed) {
      _resumeReadingTimer();
    }
  }

  @override
  void dispose() {
    _stopReadingTimer();
    _saveReadingPosition();
    WidgetsBinding.instance.removeObserver(this);
    _scrollController.removeListener(_onScrollChanged);
    _scrollController.dispose();
    super.dispose();
  }

  // ==================== Reading Time Tracking ====================

  void _startReadingTimer() {
    if (_isTrackingTime) return;
    _isTrackingTime = true;

    // Timer fires every 1 minute - efficient, minimal CPU usage
    _readingTimer = Timer.periodic(const Duration(minutes: 1), (_) {
      _accumulatedMinutes++;
      _saveAccumulatedTime();
    });
  }

  void _pauseReadingTimer() {
    _readingTimer?.cancel();
    _readingTimer = null;
    _isTrackingTime = false;
    // Save any remaining accumulated time
    if (_accumulatedMinutes > 0) {
      _saveAccumulatedTime();
    }
  }

  void _resumeReadingTimer() {
    _startReadingTimer();
  }

  void _stopReadingTimer() {
    _readingTimer?.cancel();
    _readingTimer = null;
    _isTrackingTime = false;
    // Save remaining time on exit
    _saveAccumulatedTime();
  }

  Future<void> _saveAccumulatedTime() async {
    if (_accumulatedMinutes <= 0) return;

    final minutesToSave = _accumulatedMinutes;
    _accumulatedMinutes = 0;

    try {
      await _bookService.addReadingTime(minutesToSave);
    } catch (e) {
      debugPrint('Error saving reading time: $e');
      // Restore accumulated time if save failed
      _accumulatedMinutes += minutesToSave;
    }
  }

  void _onScrollChanged() {
    // Throttled save - only save every 500 pixels of scroll to reduce I/O
    if (_scrollController.offset % 500 < 10) {
      _saveReadingPosition();
    }
  }

  Future<void> _saveReadingPosition() async {
    if (_isRestoringPosition) return;

    try {
      await _bookService.saveReadingPosition(
        book: widget.book,
        chapterIndex: _currentChapterIndex,
        scrollPosition: _scrollController.hasClients
            ? _scrollController.offset
            : 0,
      );
    } catch (e) {
      debugPrint('Error saving reading position: $e');
    }
  }

  Future<String> _loadContent() async {
    _bookService = await BookService.create();

    if (widget.book.format == 'epub') {
      _chapters = await _bookService.getEpubChapters(widget.book);
      if (_chapters != null && _chapters!.isNotEmpty) {
        // Clamp chapter index to valid range
        final validIndex = _currentChapterIndex.clamp(0, _chapters!.length - 1);
        setState(() {
          _currentChapterIndex = validIndex;
          _content = _chapters![validIndex].content;
          _htmlContent = _chapters![validIndex].htmlContent ?? _content;
        });

        // Restore scroll position after content loads
        _restoreScrollPosition();
        // Start tracking reading time
        _startReadingTimer();
        return _content;
      }
    }

    final content = await _bookService.getBookContent(widget.book);
    setState(() => _content = content);

    // Restore scroll position for TXT files
    _restoreScrollPosition();
    // Start tracking reading time
    _startReadingTimer();
    return content;
  }

  void _restoreScrollPosition() {
    if (widget.book.scrollPosition > 0) {
      _isRestoringPosition = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scrollController.hasClients) {
          _scrollController.jumpTo(widget.book.scrollPosition);
        }
        _isRestoringPosition = false;
      });
    }
  }

  void _loadChapter(int index) {
    if (_chapters == null || index < 0 || index >= _chapters!.length) return;

    // Save position before changing chapter
    _saveReadingPosition();

    setState(() {
      _isLoadingChapter = true;
      _currentChapterIndex = index;
      _content = _chapters![index].content;
      _htmlContent = _chapters![index].htmlContent ?? _content;
    });

    _scrollController.jumpTo(0);

    setState(() => _isLoadingChapter = false);

    // Save position after chapter change
    _saveReadingPosition();
  }

  void _nextChapter() {
    if (_chapters != null && _currentChapterIndex < _chapters!.length - 1) {
      _loadChapter(_currentChapterIndex + 1);
    }
  }

  void _previousChapter() {
    if (_currentChapterIndex > 0) {
      _loadChapter(_currentChapterIndex - 1);
    }
  }

  void _increaseFontSize() {
    setState(() {
      _fontSize = (_fontSize + 2).clamp(12, 32);
    });
  }

  void _decreaseFontSize() {
    setState(() {
      _fontSize = (_fontSize - 2).clamp(12, 32);
    });
  }

  void _scrollToTop() {
    _scrollController.animateTo(
      0,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOut,
    );
  }

  void _scrollToBottom() {
    _scrollController.animateTo(
      _scrollController.position.maxScrollExtent,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          _chapters != null && _chapters!.isNotEmpty
              ? _chapters![_currentChapterIndex].title
              : widget.book.title,
          overflow: TextOverflow.ellipsis,
        ),
        actions: [
          if (_chapters != null && _chapters!.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.list),
              onPressed: () => _showChapterList(context),
              tooltip: 'Chapters',
            ),
          IconButton(
            icon: const Icon(Icons.text_decrease),
            onPressed: _decreaseFontSize,
          ),
          IconButton(
            icon: const Icon(Icons.text_increase),
            onPressed: _increaseFontSize,
          ),
        ],
      ),
      body: FutureBuilder<String>(
        future: _contentFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            final isPermissionIssue =
                PlatformUtils.isMacOS &&
                PlatformUtils.isPermissionError(snapshot.error!);
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      isPermissionIssue
                          ? Icons.lock_outline
                          : Icons.error_outline,
                      size: 48,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      isPermissionIssue
                          ? 'File Access Permission Required'
                          : 'Error: ${snapshot.error}',
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    if (isPermissionIssue) ...[
                      ElevatedButton.icon(
                        onPressed: () =>
                            PlatformUtils.showMacOSPermissionTip(context),
                        icon: const Icon(Icons.info_outline),
                        label: const Text('How to Grant Permission'),
                      ),
                      const SizedBox(height: 8),
                    ],
                    ElevatedButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Go Back'),
                    ),
                  ],
                ),
              ),
            );
          }

          return Stack(
            children: [
              GestureDetector(
                onHorizontalDragEnd: (details) {
                  if (details.primaryVelocity == null) return;

                  if (details.primaryVelocity! > 0) {
                    _previousChapter();
                  } else if (details.primaryVelocity! < 0) {
                    _nextChapter();
                  }
                },
                child: Scrollbar(
                  controller: _scrollController,
                  child: SingleChildScrollView(
                    controller: _scrollController,
                    padding: const EdgeInsets.all(24),
                    child: _buildContent(),
                  ),
                ),
              ),
              if (_isLoadingChapter)
                const Positioned.fill(
                  child: Center(child: CircularProgressIndicator()),
                ),
            ],
          );
        },
      ),
      floatingActionButton: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          FloatingActionButton.small(
            heroTag: 'top',
            onPressed: _scrollToTop,
            child: const Icon(Icons.arrow_upward),
          ),
          const SizedBox(height: 8),
          FloatingActionButton.small(
            heroTag: 'bottom',
            onPressed: _scrollToBottom,
            child: const Icon(Icons.arrow_downward),
          ),
        ],
      ),
      bottomNavigationBar:
          _chapters != null && _chapters!.isNotEmpty && _chapters!.length > 1
          ? _buildChapterNavigation()
          : null,
    );
  }

  Widget _buildContent() {
    if (widget.book.format == 'epub' && _htmlContent.isNotEmpty) {
      return Html(
        data: _htmlContent,
        style: {
          'body': Style(
            fontSize: FontSize(_fontSize),
            lineHeight: LineHeight(_lineHeight),
            margin: Margins.zero,
            padding: HtmlPaddings.zero,
          ),
          'h1': Style(
            fontSize: FontSize(_fontSize * 1.8),
            fontWeight: FontWeight.bold,
            lineHeight: LineHeight(1.3),
            margin: Margins.only(bottom: 16, top: 24),
          ),
          'h2': Style(
            fontSize: FontSize(_fontSize * 1.5),
            fontWeight: FontWeight.bold,
            lineHeight: LineHeight(1.3),
            margin: Margins.only(bottom: 12, top: 20),
          ),
          'h3': Style(
            fontSize: FontSize(_fontSize * 1.3),
            fontWeight: FontWeight.bold,
            lineHeight: LineHeight(1.4),
            margin: Margins.only(bottom: 10, top: 16),
          ),
          'h4': Style(
            fontSize: FontSize(_fontSize * 1.15),
            fontWeight: FontWeight.bold,
            lineHeight: LineHeight(1.4),
            margin: Margins.only(bottom: 8, top: 12),
          ),
          'h5': Style(
            fontSize: FontSize(_fontSize * 1.0),
            fontWeight: FontWeight.bold,
            lineHeight: LineHeight(1.5),
            margin: Margins.only(bottom: 6, top: 10),
          ),
          'h6': Style(
            fontSize: FontSize(_fontSize * 0.9),
            fontWeight: FontWeight.bold,
            lineHeight: LineHeight(1.5),
            margin: Margins.only(bottom: 6, top: 10),
          ),
          'p': Style(
            fontSize: FontSize(_fontSize),
            lineHeight: LineHeight(_lineHeight),
            margin: Margins.only(bottom: 12),
          ),
          'blockquote': Style(
            fontSize: FontSize(_fontSize * 0.95),
            fontStyle: FontStyle.italic,
            padding: HtmlPaddings.only(left: 16),
            margin: Margins.only(bottom: 12, top: 12),
            border: Border(left: BorderSide(width: 4)),
          ),
          'li': Style(
            fontSize: FontSize(_fontSize),
            lineHeight: LineHeight(_lineHeight),
          ),
        },
      );
    }

    return SelectableText(
      _content,
      style: TextStyle(fontSize: _fontSize, height: _lineHeight),
    );
  }

  Widget _buildChapterNavigation() {
    final canGoPrevious = _currentChapterIndex > 0;
    final canGoNext = _currentChapterIndex < _chapters!.length - 1;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        border: Border(
          top: BorderSide(color: Theme.of(context).colorScheme.outlineVariant),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(
            onPressed: canGoPrevious ? _previousChapter : null,
            icon: const Icon(Icons.arrow_back),
            tooltip: 'Previous Chapter',
          ),
          Text(
            'Chapter ${_currentChapterIndex + 1} of ${_chapters!.length}',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          IconButton(
            onPressed: canGoNext ? _nextChapter : null,
            icon: const Icon(Icons.arrow_forward),
            tooltip: 'Next Chapter',
          ),
        ],
      ),
    );
  }

  void _showChapterList(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        maxChildSize: 0.9,
        minChildSize: 0.3,
        expand: false,
        builder: (context, scrollController) => Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Chapters',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: ListView.builder(
                controller: scrollController,
                itemCount: _chapters?.length ?? 0,
                itemBuilder: (context, index) {
                  final chapter = _chapters![index];
                  final isSelected = index == _currentChapterIndex;

                  return ListTile(
                    leading: Text(
                      '${index + 1}',
                      style: TextStyle(
                        fontWeight: isSelected ? FontWeight.bold : null,
                        color: isSelected
                            ? Theme.of(context).colorScheme.primary
                            : null,
                      ),
                    ),
                    title: Text(
                      chapter.title,
                      style: TextStyle(
                        fontWeight: isSelected ? FontWeight.bold : null,
                        color: isSelected
                            ? Theme.of(context).colorScheme.primary
                            : null,
                      ),
                    ),
                    selected: isSelected,
                    onTap: () {
                      _loadChapter(index);
                      Navigator.pop(context);
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
