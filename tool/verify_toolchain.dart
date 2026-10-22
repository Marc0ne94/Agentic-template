import 'dart:convert';
import 'dart:io';

/// Toolchain Baseline Validator for Agentic Template and the apps built on it.
///
/// Reads `toolchain.json` at the repository root (one shared set of versions)
/// and checks every project in the repository against it:
/// - `pubspec.yaml`: Dart SDK constraint and the baseline package constraints,
/// - `.github/workflows/*.yml`: Flutter version and action majors,
/// - `android/`: AGP, Kotlin, Gradle wrapper, compile/target/min SDK, Java,
///   `kotlin.incremental`,
/// - `ios/` and `macos/`: Xcode deployment targets,
/// - the running Dart SDK, which must satisfy the baseline constraint.
///
/// Bump the baseline in the template first, then copy `toolchain.json` and
/// this tool to each derived repository and fix what it reports.
///
/// Usage:
///   dart run tool/verify_toolchain.dart [--strict]
///
/// Mismatches are always printed; with `--strict` they also exit with code 1.

/// Directories that never hold project configuration.
const Set<String> skippedDirectories = {
  '.git',
  '.dart_tool',
  'build',
  'ephemeral',
  '.symlinks',
  'node_modules',
  'Pods',
  '.gradle',
};

class ToolchainMismatch {
  final String file;
  final String setting;
  final String expected;
  final String found;

  const ToolchainMismatch(this.file, this.setting, this.expected, this.found);

  @override
  String toString() =>
      '[$setting] $file\n  Expected: $expected\n  Found:    $found';
}

/// Collects mismatches for one repository against one baseline.
class ToolchainAudit {
  final Directory root;
  final Map<String, dynamic> baseline;
  final List<ToolchainMismatch> mismatches = [];
  int checks = 0;

  ToolchainAudit(this.root, this.baseline);

  Map<String, dynamic> get _android =>
      baseline['android'] as Map<String, dynamic>;
  Map<String, dynamic> get _apple => baseline['apple'] as Map<String, dynamic>;

  String _relative(File file) =>
      file.path.substring(root.path.length + 1).replaceAll('\\', '/');

  /// Records a check; [found] is `null` when the setting is missing.
  void _expect(File file, String setting, String expected, String? found) {
    checks++;
    if (found != expected) {
      mismatches.add(
        ToolchainMismatch(
          _relative(file),
          setting,
          expected,
          found ?? 'missing',
        ),
      );
    }
  }

  String? _match(String text, String pattern) =>
      RegExp(pattern, multiLine: true).firstMatch(text)?.group(1);

  Iterable<File> _files(bool Function(String path) accept) sync* {
    final pending = [root];
    while (pending.isNotEmpty) {
      for (final entity in pending.removeLast().listSync(followLinks: false)) {
        final name = entity.uri.pathSegments.lastWhere((s) => s.isNotEmpty);
        if (entity is Directory && !skippedDirectories.contains(name)) {
          pending.add(entity);
        } else if (entity is File &&
            accept(entity.path.replaceAll('\\', '/'))) {
          yield entity;
        }
      }
    }
  }

  void run() {
    _checkRunningSdk();
    for (final file in _files((p) => p.endsWith('/pubspec.yaml'))) {
      _checkPubspec(file);
    }
    for (final file in _files(
      (p) => p.contains('/.github/workflows/') && p.endsWith('.yml'),
    )) {
      _checkWorkflow(file);
    }
    for (final file in _files(
      (p) => p.endsWith('/android/settings.gradle.kts'),
    )) {
      _checkAndroid(file.parent);
    }
    for (final file in _files(
      (p) => p.endsWith('/Runner.xcodeproj/project.pbxproj'),
    )) {
      final platform = file.parent.parent.uri.pathSegments.lastWhere(
        (s) => s.isNotEmpty,
      );
      final key = platform == 'macos' ? 'MACOSX' : 'IPHONEOS';
      final expected =
          (platform == 'macos' ? _apple['macos'] : _apple['ios']) as String;
      final targets = RegExp('${key}_DEPLOYMENT_TARGET = ([0-9.]+);')
          .allMatches(file.readAsStringSync())
          .map((m) => m.group(1)!)
          .toSet();
      _expect(
        file,
        '$platform deployment target',
        expected,
        targets.isEmpty ? null : targets.join(', '),
      );
    }
  }

  void _checkRunningSdk() {
    final running = Platform.version.split(' ').first;
    final minimum = (baseline['dart'] as String).replaceFirst('^', '');
    checks++;
    if (_compareVersions(running, minimum) < 0) {
      mismatches.add(
        ToolchainMismatch(
          '(running SDK)',
          'Dart SDK',
          '>= $minimum (Flutter ${baseline['flutter']})',
          running,
        ),
      );
    }
  }

  void _checkPubspec(File file) {
    final text = file.readAsStringSync();
    _expect(
      file,
      'Dart SDK constraint',
      baseline['dart'] as String,
      _match(text, r'''^  sdk:\s*['"]?([^'"\s]+)'''),
    );
    final packages = baseline['packages'] as Map<String, dynamic>;
    for (final entry in packages.entries) {
      final found = _match(text, '^\\s+${entry.key}:\\s*(\\S+)');
      if (found != null) _expect(file, entry.key, entry.value as String, found);
    }
  }

  void _checkWorkflow(File file) {
    final text = file.readAsStringSync();
    final ci = baseline['ci'] as Map<String, dynamic>;
    if (!text.contains('subosito/flutter-action')) return;
    _expect(
      file,
      'Flutter version',
      baseline['flutter'] as String,
      _match(text, r'flutter-version:\s*(\S+)'),
    );
    _expect(
      file,
      'actions/checkout',
      ci['checkout'] as String,
      _match(text, r'actions/checkout@(v\d+)'),
    );
    _expect(
      file,
      'subosito/flutter-action',
      ci['flutterAction'] as String,
      _match(text, r'subosito/flutter-action@(v\d+)'),
    );
  }

  void _checkAndroid(Directory android) {
    final settings = File('${android.path}/settings.gradle.kts');
    final settingsText = settings.readAsStringSync();
    _expect(
      settings,
      'AGP',
      _android['agp'] as String,
      _match(
        settingsText,
        r'id\("com\.android\.application"\) version "([^"]+)"',
      ),
    );
    _expect(
      settings,
      'Kotlin',
      _android['kotlin'] as String,
      _match(
        settingsText,
        r'id\("org\.jetbrains\.kotlin\.android"\) version "([^"]+)"',
      ),
    );

    final wrapper = File(
      '${android.path}/gradle/wrapper/gradle-wrapper.properties',
    );
    if (wrapper.existsSync()) {
      _expect(
        wrapper,
        'Gradle',
        _android['gradle'] as String,
        _match(
          wrapper.readAsStringSync(),
          r'gradle-([0-9.]+)-(?:all|bin)\.zip',
        ),
      );
    }

    final build = File('${android.path}/app/build.gradle.kts');
    if (build.existsSync()) {
      final text = build.readAsStringSync();
      final compileSdk = '${_android['compileSdk']}';
      final compileLine = _match(text, r'^\s*compileSdk\s*=\s*(.+)$')?.trim();
      _expect(
        build,
        'compileSdk',
        compileSdk,
        compileLine == null
            ? null
            : (RegExp('\\b$compileSdk\\b').hasMatch(compileLine)
                  ? compileSdk
                  : compileLine),
      );
      final targetSdk = _match(text, r'^\s*targetSdk\s*=\s*(\S+)');
      _expect(
        build,
        'targetSdk',
        '${_android['targetSdk']}',
        targetSdk == 'flutter.targetSdkVersion'
            ? '${_android['targetSdk']}'
            : targetSdk,
      );
      final minSdk = _match(text, r'^\s*minSdk\s*=\s*(\S+)');
      final minimum = _android['minSdk'] as int;
      _expect(
        build,
        'minSdk',
        '>= $minimum',
        minSdk == 'flutter.minSdkVersion' ||
                (int.tryParse(minSdk ?? '') ?? 0) >= minimum
            ? '>= $minimum'
            : minSdk,
      );
      final java = '${_android['java']}';
      _expect(
        build,
        'Java source/target',
        java,
        _match(text, r'JavaVersion\.VERSION_(\d+)'),
      );
      _expect(
        build,
        'Kotlin JVM target',
        java,
        _match(text, r'JvmTarget\.JVM_(\d+)'),
      );
    }

    final properties = File('${android.path}/gradle.properties');
    if (_android['kotlinIncremental'] == false && properties.existsSync()) {
      _expect(
        properties,
        'kotlin.incremental',
        'false',
        _match(properties.readAsStringSync(), r'^kotlin\.incremental=(\S+)'),
      );
    }
  }
}

/// Compares dotted versions numerically (`3.13.10` > `3.13.5`).
int _compareVersions(String a, String b) {
  final left = a.split('.').map((p) => int.tryParse(p) ?? 0).toList();
  final right = b.split('.').map((p) => int.tryParse(p) ?? 0).toList();
  for (var i = 0; i < 3; i++) {
    final diff =
        (i < left.length ? left[i] : 0) - (i < right.length ? right[i] : 0);
    if (diff != 0) return diff;
  }
  return 0;
}

void main(List<String> args) {
  final strict = args.contains('--strict');
  final root = File.fromUri(Platform.script).parent.parent;
  final baselineFile = File('${root.path}/toolchain.json');

  if (!baselineFile.existsSync()) {
    stderr.writeln('Error: toolchain.json not found in ${root.path}');
    exit(1);
  }

  final baseline =
      jsonDecode(baselineFile.readAsStringSync()) as Map<String, dynamic>;
  stdout.writeln('🔍 Checking toolchain baseline ${baseline['baseline']}...');
  final audit = ToolchainAudit(root, baseline)..run();

  stdout.writeln(
    '━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━',
  );
  stdout.writeln('Settings checked: ${audit.checks}');
  stdout.writeln('Mismatches:       ${audit.mismatches.length}');
  stdout.writeln(
    '━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n',
  );
  for (final mismatch in audit.mismatches) {
    stdout.writeln(mismatch);
    stdout.writeln();
  }

  if (audit.mismatches.isNotEmpty) {
    if (strict) {
      stderr.writeln(
        '❌ Strict Mode Failed: ${audit.mismatches.length} settings differ from the toolchain baseline.',
      );
      exit(1);
    }
    stdout.writeln(
      '⚠️ ${audit.mismatches.length} settings differ from the baseline. Run with --strict to fail the build.',
    );
    return;
  }
  stdout.writeln(
    '✅ Repository matches toolchain baseline ${baseline['baseline']}.',
  );
}
