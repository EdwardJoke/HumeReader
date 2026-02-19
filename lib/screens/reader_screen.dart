import 'package:flutter/material.dart';
import 'package:hume/models/book.dart';
import 'package:hume/services/book_service.dart';
import 'package:hume/utils/platform_utils.dart';

class ReaderScreen extends StatefulWidget {
  final Book book;

  const ReaderScreen({super.key, required this.book});

  @override
  State<ReaderScreen> createState() => _ReaderScreenState();
}

class _ReaderScreenState extends State<ReaderScreen> {
  late Future<String> _contentFuture;
  late ScrollController _scrollController;

  String _content = '';
  double _fontSize = 18;

  static const double _lineHeight = 1.8;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
    _contentFuture = _loadContent();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Future<String> _loadContent() async {
    final service = await BookService.create();
    final content = await service.getBookContent(widget.book);
    setState(() => _content = content);
    return content;
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
        title: Text(widget.book.title, overflow: TextOverflow.ellipsis),
        actions: [
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

          return GestureDetector(
            onHorizontalDragEnd: (details) {
              if (details.primaryVelocity == null) return;

              if (details.primaryVelocity! > 0) {
                Navigator.pop(context);
              }
            },
            child: Scrollbar(
              controller: _scrollController,
              child: SingleChildScrollView(
                controller: _scrollController,
                padding: const EdgeInsets.all(24),
                child: SelectableText(
                  _content,
                  style: TextStyle(fontSize: _fontSize, height: _lineHeight),
                ),
              ),
            ),
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
    );
  }
}
