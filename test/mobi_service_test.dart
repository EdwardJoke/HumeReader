import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:hume/services/mobi_service.dart';

const _testFilePath = 'books/WhyBuddhismisTrue.mobi';

void main() {
  group('MobiService', () {
    late Uint8List bytes;

    setUpAll(() async {
      final mobiFile = File(_testFilePath);
      if (await mobiFile.exists()) {
        bytes = await mobiFile.readAsBytes();
      }
    });

    test(
      'can parse MOBI file without errors',
      () async {
        final mobiData = await MobiService.parse(bytes);

        expect(mobiData, isNotNull);
      },
      skip: !File(_testFilePath).existsSync(),
    );

    test(
      'extracts correct title from pdbHeader',
      () async {
        final mobiData = await MobiService.parse(bytes);

        expect(mobiData, isNotNull);
        expect(mobiData!.title, isNotEmpty);
        expect(mobiData.title.toLowerCase(), contains('buddhism'));
      },
      skip: !File(_testFilePath).existsSync(),
    );

    test(
      'title has underscores replaced with spaces',
      () async {
        final mobiData = await MobiService.parse(bytes);

        expect(mobiData, isNotNull);
        expect(mobiData!.title, isNot(contains('_')));
      },
      skip: !File(_testFilePath).existsSync(),
    );

    test('title is properly formatted', () async {
      final mobiData = await MobiService.parse(bytes);

      expect(mobiData, isNotNull);
      expect(mobiData!.title, equals('Why Buddhism is True'));
    }, skip: !File(_testFilePath).existsSync());

    test('title is trimmed', () async {
      final mobiData = await MobiService.parse(bytes);

      expect(mobiData, isNotNull);
      expect(mobiData!.title, equals(mobiData.title.trim()));
    }, skip: !File(_testFilePath).existsSync());

    test(
      'returns default author when not available',
      () async {
        final mobiData = await MobiService.parse(bytes);

        expect(mobiData, isNotNull);
        expect(mobiData!.author, isNotEmpty);
      },
      skip: !File(_testFilePath).existsSync(),
    );

    test(
      'textContent handles parseOpt errors gracefully',
      () async {
        final mobiData = await MobiService.parse(bytes);

        expect(mobiData, isNotNull);
        expect(() => mobiData!.textContent, returnsNormally);
      },
      skip: !File(_testFilePath).existsSync(),
    );

    test(
      'htmlContent handles parseOpt errors gracefully',
      () async {
        final mobiData = await MobiService.parse(bytes);

        expect(mobiData, isNotNull);
        expect(() => mobiData!.htmlContent, returnsNormally);
      },
      skip: !File(_testFilePath).existsSync(),
    );

    test(
      'chapters handles parseOpt errors gracefully',
      () async {
        final mobiData = await MobiService.parse(bytes);

        expect(mobiData, isNotNull);
        expect(() => mobiData!.chapters, returnsNormally);
      },
      skip: !File(_testFilePath).existsSync(),
    );

    test(
      'coverImage handles errors gracefully',
      () async {
        final mobiData = await MobiService.parse(bytes);

        expect(mobiData, isNotNull);
        expect(() => mobiData!.coverImage, returnsNormally);
      },
      skip: !File(_testFilePath).existsSync(),
    );

    test('extracts text content from MOBI', () async {
      final mobiData = await MobiService.parse(bytes);

      expect(mobiData, isNotNull);
      final content = mobiData!.textContent;
      expect(content, isNotEmpty);
      expect(content.length, greaterThan(10000));
    }, skip: !File(_testFilePath).existsSync());

    test('extracts HTML content from MOBI', () async {
      final mobiData = await MobiService.parse(bytes);

      expect(mobiData, isNotNull);
      final html = mobiData!.htmlContent;
      expect(html, isNotEmpty);
      expect(html.length, greaterThan(10000));
    }, skip: !File(_testFilePath).existsSync());

    test(
      'HTML content contains expected elements',
      () async {
        final mobiData = await MobiService.parse(bytes);

        expect(mobiData, isNotNull);
        final html = mobiData!.htmlContent.toLowerCase();
        final hasHtmlTag = html.contains('<html') || html.contains('<body');
        expect(hasHtmlTag, isTrue);
      },
      skip: !File(_testFilePath).existsSync(),
    );

    test('extracts chapters from MOBI', () async {
      final mobiData = await MobiService.parse(bytes);

      expect(mobiData, isNotNull);
      final chapters = mobiData!.chapters;
      expect(chapters, isNotEmpty);
    }, skip: !File(_testFilePath).existsSync());

    test('chapters have valid content', () async {
      final mobiData = await MobiService.parse(bytes);

      expect(mobiData, isNotNull);
      final chapters = mobiData!.chapters;

      for (final chapter in chapters) {
        expect(chapter.title, isNotEmpty);
        expect(chapter.content.length, greaterThan(100));
        expect(chapter.index, greaterThanOrEqualTo(0));
      }
    }, skip: !File(_testFilePath).existsSync());

    group('PalmDoc Decompression', () {
      test(
        'HTML content is properly decompressed',
        () async {
          final mobiData = await MobiService.parse(bytes);

          expect(mobiData, isNotNull);
          final html = mobiData!.htmlContent;

          expect(html, contains('<html'));
          expect(html, contains('<head'));
          expect(html, contains('</head>'));
          expect(html, contains('<body'));
          expect(html, contains('</body'));
          expect(html, contains('</html'));
        },
        skip: !File(_testFilePath).existsSync(),
      );

      test(
        'HTML attributes are not corrupted',
        () async {
          final mobiData = await MobiService.parse(bytes);

          expect(mobiData, isNotNull);
          final html = mobiData!.htmlContent.toLowerCase();

          expect(html, contains('title='));
          expect(html, contains('type='));
          expect(html, contains('width='));
          expect(html, contains('align='));
        },
        skip: !File(_testFilePath).existsSync(),
      );

      test('HTML tags are not corrupted', () async {
        final mobiData = await MobiService.parse(bytes);

        expect(mobiData, isNotNull);
        final html = mobiData!.htmlContent.toLowerCase();

        expect(html, contains('<blockquote'));
        expect(html, contains('</blockquote'));
        expect(html, contains('<font'));
        expect(html, contains('</font'));
      }, skip: !File(_testFilePath).existsSync());

      test(
        'Text content is readable English',
        () async {
          final mobiData = await MobiService.parse(bytes);

          expect(mobiData, isNotNull);
          final content = mobiData!.textContent;

          expect(content.toLowerCase(), contains('buddhism'));
          expect(content.toLowerCase(), contains('thank you for downloading'));

          expect(content, isNot(contains('titlpe=')));
          expect(content, isNot(contains('lockquote')));
          expect(content, isNot(contains('bodyad>')));
        },
        skip: !File(_testFilePath).existsSync(),
      );

      test(
        'Decompression produces expected content length',
        () async {
          final mobiData = await MobiService.parse(bytes);

          expect(mobiData, isNotNull);
          final html = mobiData!.htmlContent;
          final text = mobiData!.textContent;

          expect(html.length, greaterThan(500000));
          expect(text.length, greaterThan(300000));

          expect(html.length, greaterThan(text.length));
        },
        skip: !File(_testFilePath).existsSync(),
      );

      test('HTML has balanced tag structure', () async {
        final mobiData = await MobiService.parse(bytes);

        expect(mobiData, isNotNull);
        final html = mobiData!.htmlContent;

        final openBlockquote = '<blockquote'
            .allMatches(html.toLowerCase())
            .length;
        final closeBlockquote = '</blockquote'
            .allMatches(html.toLowerCase())
            .length;

        expect((openBlockquote - closeBlockquote).abs(), lessThan(10));
      }, skip: !File(_testFilePath).existsSync());

      test(
        'Special characters are preserved',
        () async {
          final mobiData = await MobiService.parse(bytes);

          expect(mobiData, isNotNull);
          final html = mobiData!.htmlContent;

          expect(html, contains('&amp;'));
          final hasQuotes =
              html.contains('&quot;') ||
              html.contains('"') ||
              html.contains('&#34;');
          expect(hasQuotes, isTrue);
        },
        skip: !File(_testFilePath).existsSync(),
      );

      test('No null characters in output', () async {
        final mobiData = await MobiService.parse(bytes);

        expect(mobiData, isNotNull);
        final text = mobiData!.textContent;
        final html = mobiData!.htmlContent;

        expect(text.codeUnits.where((c) => c == 0), isEmpty);
        expect(html.codeUnits.where((c) => c == 0), isEmpty);
      }, skip: !File(_testFilePath).existsSync());

      test(
        'No excessive control characters in output',
        () async {
          final mobiData = await MobiService.parse(bytes);

          expect(mobiData, isNotNull);
          final text = mobiData!.textContent;

          final controlChars = text.codeUnits
              .where((c) => c > 0 && c < 32 && c != 10 && c != 13)
              .length;

          expect(controlChars, lessThan(text.length ~/ 1000));
        },
        skip: !File(_testFilePath).existsSync(),
      );
    });

    group('Chapter Extraction', () {
      test('Extracts multiple chapters', () async {
        final mobiData = await MobiService.parse(bytes);

        expect(mobiData, isNotNull);
        final chapters = mobiData!.chapters;

        expect(chapters.length, greaterThanOrEqualTo(1));
      }, skip: !File(_testFilePath).existsSync());

      test('Chapter content is readable', () async {
        final mobiData = await MobiService.parse(bytes);

        expect(mobiData, isNotNull);
        final chapters = mobiData!.chapters;

        for (final chapter in chapters) {
          expect(chapter.content.length, greaterThan(50));

          expect(chapter.content, isNot(contains('titlpe=')));
          expect(chapter.content, isNot(contains('lockquote')));
        }
      }, skip: !File(_testFilePath).existsSync());
    });
  });
}
