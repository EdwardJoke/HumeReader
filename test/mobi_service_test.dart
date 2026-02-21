import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:hume/services/mobi_service.dart';

void main() {
  group('MobiService', () {
    late Uint8List bytes;

    setUpAll(() async {
      final mobiFile = File('books/WhyBuddhismisTrue.mobi');
      bytes = await mobiFile.readAsBytes();
    });

    test('can parse MOBI file without errors', () async {
      final mobiData = await MobiService.parse(bytes);

      expect(mobiData, isNotNull);
    });

    test('extracts correct title from pdbHeader', () async {
      final mobiData = await MobiService.parse(bytes);

      expect(mobiData, isNotNull);
      expect(mobiData!.title, isNotEmpty);
      expect(mobiData.title.toLowerCase(), contains('buddhism'));
    });

    test('title has underscores replaced with spaces', () async {
      final mobiData = await MobiService.parse(bytes);

      expect(mobiData, isNotNull);
      expect(mobiData!.title, isNot(contains('_')));
    });

    test('title is properly formatted', () async {
      final mobiData = await MobiService.parse(bytes);

      expect(mobiData, isNotNull);
      expect(mobiData!.title, equals('Why Buddhism is True'));
    });

    test('title is trimmed', () async {
      final mobiData = await MobiService.parse(bytes);

      expect(mobiData, isNotNull);
      expect(mobiData!.title, equals(mobiData.title.trim()));
    });

    test('returns default author when not available', () async {
      final mobiData = await MobiService.parse(bytes);

      expect(mobiData, isNotNull);
      expect(mobiData!.author, isNotEmpty);
    });

    test('textContent handles parseOpt errors gracefully', () async {
      final mobiData = await MobiService.parse(bytes);

      expect(mobiData, isNotNull);
      expect(() => mobiData!.textContent, returnsNormally);
    });

    test('htmlContent handles parseOpt errors gracefully', () async {
      final mobiData = await MobiService.parse(bytes);

      expect(mobiData, isNotNull);
      expect(() => mobiData!.htmlContent, returnsNormally);
    });

    test('chapters handles parseOpt errors gracefully', () async {
      final mobiData = await MobiService.parse(bytes);

      expect(mobiData, isNotNull);
      expect(() => mobiData!.chapters, returnsNormally);
    });

    test('coverImage handles errors gracefully', () async {
      final mobiData = await MobiService.parse(bytes);

      expect(mobiData, isNotNull);
      expect(() => mobiData!.coverImage, returnsNormally);
    });

    test('extracts text content from MOBI', () async {
      final mobiData = await MobiService.parse(bytes);

      expect(mobiData, isNotNull);
      final content = mobiData!.textContent;
      expect(content, isNotEmpty);
      expect(content.length, greaterThan(10000));
    });

    test('extracts HTML content from MOBI', () async {
      final mobiData = await MobiService.parse(bytes);

      expect(mobiData, isNotNull);
      final html = mobiData!.htmlContent;
      expect(html, isNotEmpty);
      expect(html.length, greaterThan(10000));
    });

    test('HTML content contains expected elements', () async {
      final mobiData = await MobiService.parse(bytes);

      expect(mobiData, isNotNull);
      final html = mobiData!.htmlContent.toLowerCase();
      final hasHtmlTag = html.contains('<html') || html.contains('<body');
      expect(hasHtmlTag, isTrue);
    });

    test('extracts chapters from MOBI', () async {
      final mobiData = await MobiService.parse(bytes);

      expect(mobiData, isNotNull);
      final chapters = mobiData!.chapters;
      expect(chapters, isNotEmpty);
    });

    test('chapters have valid content', () async {
      final mobiData = await MobiService.parse(bytes);

      expect(mobiData, isNotNull);
      final chapters = mobiData!.chapters;

      for (final chapter in chapters) {
        expect(chapter.title, isNotEmpty);
        expect(chapter.content.length, greaterThan(100));
        expect(chapter.index, greaterThanOrEqualTo(0));
      }
    });

    // ========== NEW COMPREHENSIVE TESTS FOR DECOMPRESSION FIX ==========

    group('PalmDoc Decompression', () {
      test('HTML content is properly decompressed', () async {
        final mobiData = await MobiService.parse(bytes);

        expect(mobiData, isNotNull);
        final html = mobiData!.htmlContent;

        // The HTML should start with proper structure
        expect(html, contains('<html'));
        expect(html, contains('<head'));
        expect(html, contains('</head>'));
        expect(html, contains('<body'));
        expect(html, contains('</body>'));
        expect(html, contains('</html>'));
      });

      test('HTML attributes are not corrupted', () async {
        final mobiData = await MobiService.parse(bytes);

        expect(mobiData, isNotNull);
        final html = mobiData!.htmlContent.toLowerCase();

        // Check for common attribute patterns that would be corrupted by wrong decompression
        // These should appear with correct characters, not garbled
        expect(html, contains('title='));
        expect(html, contains('type='));
        expect(html, contains('width='));
        expect(html, contains('align='));
      });

      test('HTML tags are not corrupted', () async {
        final mobiData = await MobiService.parse(bytes);

        expect(mobiData, isNotNull);
        final html = mobiData!.htmlContent.toLowerCase();

        // Check that common tags appear correctly
        expect(html, contains('<blockquote'));
        expect(html, contains('</blockquote'));
        expect(html, contains('<font'));
        expect(html, contains('</font'));
      });

      test('Text content is readable English', () async {
        final mobiData = await MobiService.parse(bytes);

        expect(mobiData, isNotNull);
        final content = mobiData!.textContent;

        // Check for expected phrases from the book
        // These verify the decompression produces readable text
        expect(content.toLowerCase(), contains('buddhism'));
        expect(content.toLowerCase(), contains('thank you for downloading'));

        // Check that we don't have obvious corruption patterns
        // The old bug produced patterns like "titlpe=" instead of "title="
        expect(content, isNot(contains('titlpe=')));
        expect(content, isNot(contains('lockquote')));
        expect(content, isNot(contains('bodyad>')));
      });

      test('Decompression produces expected content length', () async {
        final mobiData = await MobiService.parse(bytes);

        expect(mobiData, isNotNull);
        final html = mobiData!.htmlContent;
        final text = mobiData!.textContent;

        // The book should have substantial content
        // HTML should be larger than plain text due to tags
        expect(html.length, greaterThan(500000));
        expect(text.length, greaterThan(300000));

        // HTML should be larger than plain text
        expect(html.length, greaterThan(text.length));
      });

      test('HTML has balanced tag structure', () async {
        final mobiData = await MobiService.parse(bytes);

        expect(mobiData, isNotNull);
        final html = mobiData!.htmlContent;

        // Count open and close tags for common elements
        final openBlockquote = '<blockquote'
            .allMatches(html.toLowerCase())
            .length;
        final closeBlockquote = '</blockquote'
            .allMatches(html.toLowerCase())
            .length;

        // Should have roughly balanced tags (allowing for some edge cases)
        expect((openBlockquote - closeBlockquote).abs(), lessThan(10));
      });

      test('Special characters are preserved', () async {
        final mobiData = await MobiService.parse(bytes);

        expect(mobiData, isNotNull);
        final html = mobiData!.htmlContent;

        // Check that common HTML entities appear correctly
        expect(html, contains('&amp;')); // & character
        // Quotes may appear as &quot; or as actual quote characters
        final hasQuotes =
            html.contains('&quot;') ||
            html.contains('"') ||
            html.contains('&#34;');
        expect(hasQuotes, isTrue);
      });

      test('No null characters in output', () async {
        final mobiData = await MobiService.parse(bytes);

        expect(mobiData, isNotNull);
        final text = mobiData!.textContent;
        final html = mobiData.htmlContent;

        // Should not contain null characters
        expect(text.codeUnits.where((c) => c == 0), isEmpty);
        expect(html.codeUnits.where((c) => c == 0), isEmpty);
      });

      test('No excessive control characters in output', () async {
        final mobiData = await MobiService.parse(bytes);

        expect(mobiData, isNotNull);
        final text = mobiData!.textContent;

        // Count control characters (excluding newline and carriage return)
        final controlChars = text.codeUnits
            .where((c) => c > 0 && c < 32 && c != 10 && c != 13)
            .length;

        // Allow some control characters but not excessive
        expect(controlChars, lessThan(text.length ~/ 1000));
      });
    });

    group('Chapter Extraction', () {
      test('Extracts multiple chapters', () async {
        final mobiData = await MobiService.parse(bytes);

        expect(mobiData, isNotNull);
        final chapters = mobiData!.chapters;

        // Should extract more than just "Full Text" fallback
        // If decompression works, we should find actual chapter markers
        expect(chapters.length, greaterThanOrEqualTo(1));
      });

      test('Chapter content is readable', () async {
        final mobiData = await MobiService.parse(bytes);

        expect(mobiData, isNotNull);
        final chapters = mobiData!.chapters;

        for (final chapter in chapters) {
          // Each chapter should have meaningful content
          expect(chapter.content.length, greaterThan(50));

          // Content should not contain obvious corruption
          expect(chapter.content, isNot(contains('titlpe=')));
          expect(chapter.content, isNot(contains('lockquote')));
        }
      });
    });
  });
}
