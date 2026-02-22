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
  final MobiData _mobiData;

  MobiBookData(this._mobiData);

  String get title {
    try {
      String? rawTitle;

      final pdbName = _mobiData.pdbHeader?.name;
      if (pdbName != null && pdbName.isNotEmpty) {
        rawTitle = pdbName.trim();
      }

      if (rawTitle == null || rawTitle.isEmpty) {
        final fullname = _mobiData.mobiHeader?.fullname;
        if (fullname != null && fullname.isNotEmpty) {
          rawTitle = fullname;
        }
      }

      if (rawTitle == null || rawTitle.isEmpty) {
        final exthTitle = _getExthData(503);
        if (exthTitle != null && exthTitle.isNotEmpty) {
          rawTitle = exthTitle;
        }
      }

      if (rawTitle != null && rawTitle.isNotEmpty) {
        return _cleanTitle(rawTitle);
      }
    } catch (_) {}
    return 'Untitled';
  }

  String _cleanTitle(String title) {
    var cleaned = title
        .replaceAll('\x00', '')
        .replaceAll('_', ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();

    final garbagePatterns = [
      RegExp(r'\s*[A-Za-z0-9]{20,}\s*$', caseSensitive: false),
      RegExp(r'\s*code\s*$', caseSensitive: true),
      RegExp(r'\s*\{.*\}\s*$', caseSensitive: false),
      RegExp(r'\s*\\x[0-9a-fA-F]+\s*$', caseSensitive: false),
    ];

    for (final pattern in garbagePatterns) {
      cleaned = cleaned.replaceAll(pattern, '');
    }

    return cleaned.trim();
  }

  String get author {
    try {
      final author = _getExthData(100);
      if (author != null && author.isNotEmpty) {
        return author;
      }
    } catch (_) {}
    return 'Unknown Author';
  }

  String? _getExthData(int tag) {
    var exth = _mobiData.mobiExthHeader;
    while (exth != null) {
      if (exth.tag == tag && exth.data != null) {
        return utf8.decode(exth.data!);
      }
      exth = exth.next;
    }
    return null;
  }

  String get textContent {
    final html = htmlContent;
    if (html.isEmpty) return '';
    return _htmlToPlainText(html);
  }

  String get htmlContent {
    try {
      final rawml = _mobiData.parseOpt(true, true, false);
      final data = rawml.markup?.data;
      if (data != null) {
        return utf8.decode(data);
      }
    } catch (_) {}

    return _extractContentDirectly();
  }

  String _extractContentDirectly() {
    try {
      final record0 = _mobiData.record0header;
      if (record0 == null) return '';

      final compressionType = record0.compressionType ?? 1;
      final textRecordCount = record0.textRecordCount ?? 0;

      if (textRecordCount == 0) return '';

      final allContent = <int>[];
      var record = _mobiData.mobiPdbRecord;

      if (record == null) return '';

      record = record.next;

      for (int i = 0; i < textRecordCount && record != null; i++) {
        if (record.data != null && record.data!.isNotEmpty) {
          if (compressionType == 2) {
            final decompressed = _decompressPalmDoc(record.data!);
            allContent.addAll(decompressed);
          } else if (compressionType == 1) {
            allContent.addAll(record.data!);
          }
        }
        record = record.next;
      }

      if (allContent.isNotEmpty) {
        try {
          return utf8.decode(allContent);
        } catch (e) {
          final stringBuffer = StringBuffer();
          for (int i = 0; i < allContent.length; i++) {
            final byte = allContent[i];
            if (byte >= 32 && byte < 127) {
              stringBuffer.writeCharCode(byte);
            } else if (byte == 10 || byte == 13) {
              stringBuffer.writeCharCode(byte);
            } else {
              stringBuffer.write(' ');
            }
          }
          return stringBuffer.toString();
        }
      }
    } catch (e) {
      debugPrint('Error extracting content directly: $e');
    }
    return '';
  }

  List<int> _decompressPalmDoc(Uint8List data) {
    final output = <int>[];
    int i = 0;

    while (i < data.length) {
      final byte = data[i++];

      if (byte == 0x00) {
        // Literal character
        output.add(byte);
      } else if (byte >= 0x01 && byte <= 0x08) {
        // Copy next N bytes literally (1-8)
        final count = byte;
        for (int j = 0; j < count && i < data.length; j++) {
          output.add(data[i++]);
        }
      } else if (byte >= 0x09 && byte <= 0x7F) {
        // Literal character
        output.add(byte);
      } else if (byte >= 0x80 && byte <= 0xBF) {
        // Length-distance pair (Type B command)
        if (i >= data.length) break;
        final nextByte = data[i++];

        // Combine the two bytes: 16 bits total
        // Format: 10xxxxxx xxxxxxxx
        //   - First 2 bits (10) are discarded
        //   - Next 11 bits = distance (offset from end of uncompressed)
        //   - Last 3 bits = length - 3
        final combined = (byte << 8) | nextByte;

        // Distance: bits 3-13 (11 bits) - no +1 needed
        final distance = ((combined >> 3) & 0x7FF);

        // Length: bits 0-2 (3 bits), add 3
        final length = (combined & 0x07) + 3;

        // Copy 'length' bytes from 'distance' bytes back
        for (int j = 0; j < length; j++) {
          final srcIndex = output.length - distance;
          if (srcIndex >= 0 && srcIndex < output.length) {
            output.add(output[srcIndex]);
          }
        }
      } else if (byte >= 0xC0 && byte <= 0xFF) {
        // Space + character (Type C command)
        // 0xC0 = space + (0x00 ^ 0x80), so space + 0x00 = "A"
        output.add(0x20); // space
        output.add(byte ^ 0x80);
      }
    }

    return output;
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
      final rawml = _mobiData.parseOpt(true, true, false);
      var resource = rawml.resources;
      while (resource != null) {
        final fileType = resource.fileType;
        if ((fileType == MobiFileType.jpg ||
                fileType == MobiFileType.png ||
                fileType == MobiFileType.gif ||
                fileType == MobiFileType.bmp) &&
            resource.data != null) {
          return resource.data!;
        }
        resource = resource.next;
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
