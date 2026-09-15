import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

// Reuse the CLI auditor so the test and `dart run tool/verify_fsd.dart` can
// never disagree about the rules.
import '../../tool/verify_fsd.dart'
    show FsdAuditResult, FsdViolation, auditDirectory;

String _describe(List<FsdViolation> violations) => violations.join('\n\n');

void main() {
  group('Feature-Sliced Design (FSD v2.1) Architecture Boundary Audit', () {
    late FsdAuditResult result;

    setUpAll(() {
      final libDir = Directory('lib');
      expect(libDir.existsSync(), isTrue, reason: 'lib/ directory must exist');
      result = auditDirectory(libDir);
    });

    test('scans the lib/ sources', () {
      expect(result.totalScannedFiles, greaterThan(0));
    });

    test('has no upward layer inversions', () {
      expect(
        result.upwardViolations,
        isEmpty,
        reason: _describe(result.upwardViolations),
      );
    });

    test('has no cross-slice couplings', () {
      expect(
        result.crossSliceViolations,
        isEmpty,
        reason: _describe(result.crossSliceViolations),
      );
    });

    test('imports slices only through their public barrels', () {
      expect(
        result.barrelViolations,
        isEmpty,
        reason: _describe(result.barrelViolations),
      );
    });
  });

  group('FSD auditor rules', () {
    late Directory root;

    void writeFile(String path, String contents) {
      File('${root.path}/$path')
        ..createSync(recursive: true)
        ..writeAsStringSync(contents);
    }

    setUp(() {
      root = Directory.systemTemp.createTempSync('fsd_audit_');
      writeFile('pubspec.yaml', 'name: agentic_template\n');
    });

    tearDown(() {
      root.deleteSync(recursive: true);
    });

    test('flags upward, cross-slice and deep imports', () {
      writeFile('lib/shared/shared.dart', "export 'ui/tokens.dart';\n");
      // Segments of a segmented layer may import each other.
      writeFile('lib/shared/ui/tokens.dart', "import '../lib/helpers.dart';\n");
      writeFile('lib/shared/lib/helpers.dart', '');
      writeFile(
        'lib/shared/lib/bad.dart',
        "import 'package:agentic_template/features/a/a.dart';\n",
      );
      writeFile('lib/features/a/a.dart', "export 'ui/a_widget.dart';\n");
      writeFile(
        'lib/features/a/ui/a_widget.dart',
        "import '../../../shared/shared.dart';\n"
            "import '../../b/b.dart';\n",
      );
      writeFile('lib/features/b/b.dart', '');
      writeFile(
        'lib/pages/home/home.dart',
        "import '../../features/a/ui/a_widget.dart';\n",
      );

      final result = auditDirectory(Directory('${root.path}/lib'));

      expect(result.upwardViolations.map((v) => v.importUri), [
        'package:agentic_template/features/a/a.dart',
      ]);
      expect(result.crossSliceViolations.map((v) => v.importUri), [
        '../../b/b.dart',
      ]);
      expect(result.barrelViolations.map((v) => v.importUri), [
        '../../features/a/ui/a_widget.dart',
      ]);
    });

    for (final directive in ['import', 'export']) {
      test('checks every conditional $directive URI', () {
        writeFile('lib/shared/stub.dart', '');
        writeFile('lib/features/a/a.dart', '');
        writeFile('lib/widgets/panel/panel.dart', '');
        writeFile(
          'lib/shared/shared.dart',
          "$directive 'stub.dart'\n"
              "    if (dart.library.io) '../features/a/a.dart'\n"
              "    if (dart.library.html) '../widgets/panel/panel.dart';\n",
        );

        final result = auditDirectory(Directory('${root.path}/lib'));

        expect(result.upwardViolations.map((v) => v.importUri), [
          '../features/a/a.dart',
          '../widgets/panel/panel.dart',
        ]);
        expect(result.upwardViolations.map((v) => v.line), [2, 3]);
        expect(result.totalScannedImports, 1);
      });
    }

    test('checks directives with the URI on another line', () {
      writeFile('lib/features/a/a.dart', '');
      writeFile(
        'lib/shared/shared.dart',
        "export\n    '../features/a/a.dart';\n",
      );

      final result = auditDirectory(Directory('${root.path}/lib'));

      expect(result.upwardViolations.map((v) => v.importUri), [
        '../features/a/a.dart',
      ]);
      expect(result.upwardViolations.map((v) => v.line), [2]);
    });

    test('ignores directive-like text in comments and strings', () {
      writeFile('lib/shared/shared.dart', '''/*
import '../features/a/a.dart';
*/
const example = """
export '../features/a/a.dart';
""";
''');

      final result = auditDirectory(Directory('${root.path}/lib'));

      expect(result.totalViolations, 0);
      expect(result.totalScannedImports, 0);
    });

    test('reads the local package name from pubspec YAML', () {
      writeFile('pubspec.yaml', 'name: "renamed_template" # Custom project\n');
      writeFile('lib/features/a/a.dart', '');
      writeFile(
        'lib/shared/shared.dart',
        "export 'package:renamed_template/features/a/a.dart';\n",
      );

      final result = auditDirectory(Directory('${root.path}/lib'));

      expect(result.upwardViolations.map((v) => v.importUri), [
        'package:renamed_template/features/a/a.dart',
      ]);
    });

    test('ignores external packages including the original template name', () {
      writeFile('pubspec.yaml', 'name: renamed_template\n');
      writeFile(
        'lib/shared/shared.dart',
        "export 'package:agentic_template/features/a/a.dart';\n"
            "export 'package:other_package/features/a/a.dart';\n",
      );

      final result = auditDirectory(Directory('${root.path}/lib'));

      expect(result.totalViolations, 0);
      expect(result.totalScannedImports, 2);
    });

    test('resolves layers from the audited lib even under a lib ancestor', () {
      writeFile('lib/project/pubspec.yaml', 'name: nested_project\n');
      writeFile('lib/project/lib/features/a/a.dart', '');
      writeFile(
        'lib/project/lib/shared/shared.dart',
        "export '../features/a/a.dart';\n",
      );

      final result = auditDirectory(Directory('${root.path}/lib/project/lib'));

      expect(result.upwardViolations.map((v) => v.importUri), [
        '../features/a/a.dart',
      ]);
    });

    test('rejects a pubspec without a package name', () {
      writeFile('pubspec.yaml', 'description: Missing package identity\n');
      writeFile('lib/shared/shared.dart', '');

      expect(
        () => auditDirectory(Directory('${root.path}/lib')),
        throwsFormatException,
      );
    });
  });
}
