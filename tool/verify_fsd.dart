import 'dart:io';

import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:path/path.dart' as p;
import 'package:yaml/yaml.dart';

/// Feature-Sliced Design (FSD v2.1) Architecture Validator for Agentic Template.
///
/// Parses the `import` and `export` directives of every Dart file in `lib/`,
/// including every conditional URI, and reports:
/// - upward layer imports (e.g. `shared` importing `features`),
/// - cross-slice imports inside `pages`, `widgets`, `features` and `entities`,
/// - deep imports that bypass a slice's public barrel (`<slice>/<slice>.dart`).
///
/// Usage:
///   dart run tool/verify_fsd.dart [--strict]
///
/// Violations are always printed; with `--strict` they also exit with code 1.

const Map<String, int> layerHierarchy = {
  'app': 1,
  'pages': 2,
  'widgets': 3,
  'features': 4,
  'entities': 5,
  'shared': 6,
};

/// Layers organized into segments (`ui`, `lib`, `theme`, ...) instead of
/// slices, so imports between their sub-folders are not cross-slice couplings.
/// Their public API is the layer barrel (`lib/<layer>/<layer>.dart`).
const Set<String> segmentedLayers = {'app', 'shared'};

class FsdViolation {
  final String file;
  final int line;
  final String importUri;
  final String sourceLayer;
  final String? sourceSlice;
  final String targetLayer;
  final String? targetSlice;
  final String violationType;
  final String description;

  const FsdViolation({
    required this.file,
    required this.line,
    required this.importUri,
    required this.sourceLayer,
    required this.sourceSlice,
    required this.targetLayer,
    required this.targetSlice,
    required this.violationType,
    required this.description,
  });

  @override
  String toString() {
    return '[$violationType] $file:$line\n'
        '  Source: $sourceLayer${sourceSlice != null ? '/$sourceSlice' : ''}\n'
        '  Target: $targetLayer${targetSlice != null ? '/$targetSlice' : ''} ($importUri)\n'
        '  Reason: $description';
  }
}

class FsdAuditResult {
  final List<FsdViolation> upwardViolations;
  final List<FsdViolation> crossSliceViolations;
  final List<FsdViolation> barrelViolations;
  final int totalScannedFiles;
  final int totalScannedImports;

  const FsdAuditResult({
    required this.upwardViolations,
    required this.crossSliceViolations,
    required this.barrelViolations,
    required this.totalScannedFiles,
    required this.totalScannedImports,
  });

  int get totalViolations =>
      upwardViolations.length +
      crossSliceViolations.length +
      barrelViolations.length;
}

FsdAuditResult auditDirectory(Directory libDir) {
  final libRoot = p.normalize(p.absolute(libDir.path));
  final packageName = _readPackageName(libRoot);
  final upwardViolations = <FsdViolation>[];
  final crossSliceViolations = <FsdViolation>[];
  final barrelViolations = <FsdViolation>[];

  final dartFiles = Directory(libRoot)
      .listSync(recursive: true)
      .whereType<File>()
      .where((f) => f.path.endsWith('.dart'))
      .toList();

  int totalImports = 0;

  for (final file in dartFiles) {
    final sourcePath = p
        .relative(file.path, from: libRoot)
        .replaceAll(r'\', '/');
    final relSourcePath = 'lib/$sourcePath';
    final (sourceLayer, sourceSlice) = _parseLayerAndSlice(sourcePath);
    if (sourceLayer == null || !layerHierarchy.containsKey(sourceLayer)) {
      continue;
    }

    final parsed = parseString(
      content: file.readAsStringSync(),
      path: file.path,
    );
    final directives = parsed.unit.directives
        .whereType<NamespaceDirective>()
        .toList();
    totalImports += directives.length;
    final uris = [
      for (final directive in directives) ...[
        directive.uri,
        ...directive.configurations.map((configuration) => configuration.uri),
      ],
    ];
    for (final uri in uris) {
      final importUri = uri.stringValue;
      if (importUri == null) continue;
      final targetResolvedPath = _resolveImport(
        file,
        importUri,
        libRoot,
        packageName,
      );
      if (targetResolvedPath == null) continue;

      final (targetLayer, targetSlice) = _parseLayerAndSlice(
        targetResolvedPath,
      );
      if (targetLayer == null || !layerHierarchy.containsKey(targetLayer)) {
        continue;
      }

      FsdViolation violation(String type, String description) => FsdViolation(
        file: relSourcePath,
        line: parsed.lineInfo.getLocation(uri.offset).lineNumber,
        importUri: importUri,
        sourceLayer: sourceLayer,
        sourceSlice: sourceSlice,
        targetLayer: targetLayer,
        targetSlice: targetSlice,
        violationType: type,
        description: description,
      );

      final sourceRank = layerHierarchy[sourceLayer]!;
      final targetRank = layerHierarchy[targetLayer]!;
      final isSegmented = segmentedLayers.contains(targetLayer);
      final isSameUnit =
          sourceLayer == targetLayer &&
          (isSegmented || (sourceSlice != null && sourceSlice == targetSlice));

      // 1. Upward Layer Violation (Lower layer importing higher layer)
      // Note: lower in hierarchy has higher rank number (shared=6, app=1).
      if (sourceRank > targetRank) {
        upwardViolations.add(
          violation(
            'UPWARD_LAYER_INVERSION',
            'Layer "$sourceLayer" cannot import from higher layer "$targetLayer".',
          ),
        );
      }
      // 2. Cross-Slice Isolation Violation (Same layer, different slices)
      else if (sourceLayer == targetLayer &&
          !isSegmented &&
          sourceSlice != null &&
          targetSlice != null &&
          sourceSlice != targetSlice) {
        crossSliceViolations.add(
          violation(
            'CROSS_SLICE_COUPLING',
            'Slice "$sourceSlice" cannot import from sibling slice "$targetSlice" within the same layer "$sourceLayer".',
          ),
        );
      }
      // 3. Public API Violation (deep import from outside the slice/segment)
      else if (!isSameUnit &&
          !_isPublicApi(targetResolvedPath, targetLayer, targetSlice)) {
        final barrel = isSegmented
            ? '$targetLayer/$targetLayer.dart'
            : '$targetLayer/$targetSlice/$targetSlice.dart';
        barrelViolations.add(
          violation(
            'DEEP_IMPORT',
            'Import through the public barrel "$barrel" instead.',
          ),
        );
      }
    }
  }

  return FsdAuditResult(
    upwardViolations: upwardViolations,
    crossSliceViolations: crossSliceViolations,
    barrelViolations: barrelViolations,
    totalScannedFiles: dartFiles.length,
    totalScannedImports: totalImports,
  );
}

(String?, String?) _parseLayerAndSlice(String path) {
  final parts = path.split('/');
  if (parts.length < 2) {
    return (null, null);
  }

  final layer = parts[0];
  String? slice;
  if (parts.length > 2) {
    slice = parts[1];
  }
  return (layer, slice);
}

bool _isPublicApi(String path, String layer, String? slice) {
  final barrel = segmentedLayers.contains(layer)
      ? '$layer/$layer.dart'
      : '$layer/$slice/$slice.dart';
  return path == barrel;
}

String _readPackageName(String libRoot) {
  final pubspecFile = File(p.join(p.dirname(libRoot), 'pubspec.yaml'));
  final pubspec = loadYaml(
    pubspecFile.readAsStringSync(),
    sourceUrl: pubspecFile.uri,
  );
  final name = pubspec is YamlMap ? pubspec['name'] : null;
  if (name is! String || name.trim().isEmpty) {
    throw FormatException('Missing package name in ${pubspecFile.path}');
  }
  return name;
}

String? _resolveImport(
  File sourceFile,
  String uri,
  String libRoot,
  String packageName,
) {
  final importUri = Uri.parse(uri);
  final Uri targetUri;
  if (importUri.scheme == 'package') {
    final segments = importUri.pathSegments;
    if (segments.length < 2 || segments.first != packageName) return null;
    targetUri = Directory(libRoot).uri
        .resolveUri(Uri(pathSegments: segments.skip(1)));
  } else if (!importUri.hasScheme || importUri.scheme == 'file') {
    targetUri = sourceFile.uri.resolveUri(importUri);
  } else {
    return null;
  }

  final targetPath = p.normalize(File.fromUri(targetUri).path);
  if (!p.isWithin(libRoot, targetPath)) return null;
  return p.relative(targetPath, from: libRoot).replaceAll(r'\', '/');
}

void main(List<String> args) {
  final strict = args.contains('--strict');
  final libDir = Directory('lib');

  if (!libDir.existsSync()) {
    stderr.writeln(
      'Error: lib/ directory not found in ${Directory.current.path}',
    );
    exit(1);
  }

  stdout.writeln(
    '🔍 Running Feature-Sliced Design (FSD v2.1) Architectural Audit...',
  );
  final result = auditDirectory(libDir);

  stdout.writeln(
    '━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━',
  );
  stdout.writeln('Total Dart files scanned:   ${result.totalScannedFiles}');
  stdout.writeln('Total directives inspected: ${result.totalScannedImports}');
  stdout.writeln(
    'Upward Layer Inversions:    ${result.upwardViolations.length}',
  );
  stdout.writeln(
    'Cross-Slice Couplings:      ${result.crossSliceViolations.length}',
  );
  stdout.writeln(
    'Deep (non-barrel) Imports:  ${result.barrelViolations.length}',
  );
  stdout.writeln('Total Architectural Breaches: ${result.totalViolations}');
  stdout.writeln(
    '━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n',
  );

  void printSection(String title, List<FsdViolation> violations) {
    if (violations.isEmpty) return;
    stdout.writeln(title);
    for (final v in violations) {
      stdout.writeln(v);
      stdout.writeln();
    }
  }

  printSection(
    '🚨 UPWARD LAYER INVERSIONS (Critical Severity):',
    result.upwardViolations,
  );
  printSection(
    '⚠️ CROSS-SLICE COUPLINGS (High Severity):',
    result.crossSliceViolations,
  );
  printSection(
    '⚠️ DEEP IMPORTS BYPASSING PUBLIC BARRELS (High Severity):',
    result.barrelViolations,
  );

  if (result.totalViolations > 0) {
    if (strict) {
      stderr.writeln(
        '❌ Strict Mode Failed: Found ${result.totalViolations} architectural violations.',
      );
      exit(1);
    }
    stdout.writeln(
      '⚠️ Found ${result.totalViolations} architectural violations. Run with --strict to fail the build.',
    );
    return;
  }
  stdout.writeln('✅ Zero architectural violations detected.');
}
