import 'dart:convert';

import 'package:dart_mobi/dart_mobi.dart';
import 'package:flutter/foundation.dart';

import 'package:hume/models/book_chapter.dart';

class MobiService {
  static Future<MobiBookData?> parse(Uint8List bytes) async {
    try {
      final mobiData = await DartMobiReader.read(bytes);
      return MobiBookData(mobiData);
    } catch (e) {
      debugPrint('Error parsing MOBI: $e');
      return null;
    }
  }

  static Future<String> extractContent(Uint8List bytes) async {
    final bookData = await parse(bytes);
    if (bookData == null) return '';

    return bookData.textContent;
  }

  static Future<List<BookChapter>> extractChapters(Uint8List bytes) async {
    final bookData = await parse(bytes);
    if (bookData == null) return [];

    return bookData.chapters;
  }
}

class MobiBookData {
  final dynamic _mobiData;

  MobiBookData(this._mobiData);

  String get title {
    try {
      final fullName = _mobiData.pdbHeader?.fullName;
      if (fullName != null && fullName.isNotEmpty) {
        return fullName;
      }
    } catch (_) {}
    return 'Untitled';
  }

  String get author {
    try {
      final exth = _mobiData.exth;
      if (exth != null) {
        final authorRecord = exth.records?.firstWhere(
          (r) => r.type == 100,
          orElse: () => null,
        );
        if (authorRecord != null) {
          return utf8.decode(List<int>.from(authorRecord.data ?? []));
        }
      }
    } catch (_) {}
    return 'Unknown Author';
  }

  String get textContent {
    try {
      final rawml = _mobiData.parseOpt(true, true, false);
      if (rawml?.markup?.data != null) {
        final htmlContent = utf8.decode(List<int>.from(rawml.markup.data));
        return _htmlToPlainText(htmlContent);
      }
    } catch (_) {}
    return '';
  }

  String get htmlContent {
    try {
      final rawml = _mobiData.parseOpt(true, true, false);
      if (rawml?.markup?.data != null) {
        return utf8.decode(List<int>.from(rawml.markup.data));
      }
    } catch (_) {}
    return '';
  }

  List<BookChapter> get chapters {
    final html = htmlContent;
    if (html.isEmpty) return [];

    final chapterPattern = RegExp(
      r'<(?:h[1-6]|chapter|title)[^>]*>(.*?)</(?:h[1-6]|chapter|title)>',
      caseSensitive: false,
    );

    final matches = chapterPattern.allMatches(html);

    if (matches.isEmpty) {
      return [
        BookChapter(
          title: 'Full Text',
          content: textContent,
          htmlContent: _cleanHtml(html),
          index: 0,
        ),
      ];
    }

    final chapterList = <BookChapter>[];
    int lastIndex = 0;
    int index = 0;

    for (final match in matches) {
      final chapterTitle = _stripHtml(match.group(1) ?? 'Chapter ${index + 1}');
      final chapterStart = match.start;

      if (lastIndex < chapterStart) {
        final chapterHtml = html.substring(lastIndex, chapterStart);
        if (chapterHtml.trim().isNotEmpty) {
          chapterList.add(
            BookChapter(
              title: chapterTitle,
              content: _htmlToPlainText(chapterHtml),
              htmlContent: _cleanHtml(chapterHtml),
              index: index,
            ),
          );
          index++;
        }
      }

      lastIndex = chapterStart;
    }

    if (lastIndex < html.length) {
      final remainingHtml = html.substring(lastIndex);
      if (remainingHtml.trim().isNotEmpty) {
        chapterList.add(
          BookChapter(
            title: 'Chapter ${index + 1}',
            content: _htmlToPlainText(remainingHtml),
            htmlContent: _cleanHtml(remainingHtml),
            index: index,
          ),
        );
      }
    }

    return chapterList;
  }

  Uint8List? get coverImage {
    try {
      final coverOffset = _mobiData.mobiHeader?.coverOffset;
      if (coverOffset != null && coverOffset >= 0) {
        final records = _mobiData.pdbHeader?.records;
        if (records != null && coverOffset < records.length) {
          final record = records[coverOffset];
          if (record.data != null) {
            return Uint8List.fromList(List<int>.from(record.data));
          }
        }
      }
    } catch (_) {}
    return null;
  }

  String _htmlToPlainText(String html) {
    return html
        .replaceAll(
          RegExp(r'<script[^>]*>[\s\S]*?</script>', caseSensitive: false),
          '',
        )
        .replaceAll(
          RegExp(r'<style[^>]*>[\s\S]*?</style>', caseSensitive: false),
          '',
        )
        .replaceAll(RegExp(r'<[^>]+>'), '\n')
        .replaceAll('&nbsp;', ' ')
        .replaceAll('&amp;', '&')
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .replaceAll('&quot;', '"')
        .replaceAll('&#39;', "'")
        .replaceAll(RegExp(r'\n\s*\n'), '\n\n')
        .replaceAll(RegExp(r' +'), ' ')
        .trim();
  }

  String _stripHtml(String html) {
    return html
        .replaceAll(RegExp(r'<[^>]+>'), '')
        .replaceAll('&nbsp;', ' ')
        .replaceAll('&amp;', '&')
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .replaceAll('&quot;', '"')
        .replaceAll('&#39;', "'")
        .trim();
  }

  String _cleanHtml(String html) {
    return html
        .replaceAll(
          RegExp(r'<script[^>]*>[\s\S]*?</script>', caseSensitive: false),
          '',
        )
        .replaceAll(
          RegExp(r'<style[^>]*>[\s\S]*?</style>', caseSensitive: false),
          '',
        )
        .trim();
  }
}
