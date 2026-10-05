/// Checks that a project follows the structure the CLI generates: a
/// barrel file per folder, the marker comments and the feature
/// registrations.
library;

import 'dart:io';

import 'package:flutter_clean_arch/src/injector.dart';
import 'package:flutter_clean_arch/src/naming.dart';
import 'package:flutter_clean_arch/src/project.dart';
import 'package:flutter_clean_arch/src/project_config.dart';
import 'package:flutter_clean_arch/src/registry.dart';
import 'package:path/path.dart' as p;

/// Kind of [DoctorIssue].
enum DoctorIssueKind {
  /// A folder with Dart files has no `<folder>/<folder>.dart`.
  missingBarrel,

  /// A barrel does not export one of the files or sub-barrels of its folder.
  missingExport,

  /// A marker comment used by the commands is missing.
  missingMarker,

  /// A feature's `init<Feature>Dependencies()` is not called.
  unregisteredFeature,

  /// The project has no `.flutter_clean_arch.yaml`.
  missingConfig,

  /// The project was last changed by a newer CLI than the installed one.
  newerProject;

  /// Whether `doctor --fix` can solve it.
  bool get fixable =>
      this == missingBarrel || this == missingExport || this == missingConfig;
}

/// A problem found by [diagnose].
class DoctorIssue {
  /// Creates an issue of [kind] about [file].
  const DoctorIssue(this.kind, this.file, this.detail);

  /// What kind of problem it is.
  final DoctorIssueKind kind;

  /// Project-relative path (with `/`) of the file the issue is about.
  final String file;

  /// What is missing: the export URI, the marker, the init call, or the
  /// list of exports for a missing barrel (comma separated).
  final String detail;

  @override
  String toString() => switch (kind) {
    DoctorIssueKind.missingBarrel => 'Falta el barril $file ($detail)',
    DoctorIssueKind.missingExport => "$file no exporta '$detail'",
    DoctorIssueKind.missingMarker => 'Falta "$detail" en $file',
    DoctorIssueKind.unregisteredFeature => 'No se llama a $detail en $file',
    DoctorIssueKind.missingConfig =>
      'Falta $file (versión de la CLI con la que se generó)',
    DoctorIssueKind.newerProject =>
      'El proyecto se modificó con la versión $detail de la CLI, más nueva '
          'que la instalada: actualízala',
  };
}

/// Folders under `lib/` that are generated and never get a barrel.
const _skippedDirs = {'lib', 'lib/core/l10n/gen'};

/// Marker comments each core file must keep.
const Map<String, List<String>> _requiredMarkers = {
  'lib/core/di/injection_container.dart': [
    Markers.featureImports,
    Markers.featureInit,
  ],
  'lib/core/router/app_router.dart': [Markers.featureImports, Markers.routes],
  'lib/core/router/app_routes.dart': [Markers.routes],
};

/// Every problem found in [project].
///
/// With [cliVersion] (the installed CLI), also checks
/// `.flutter_clean_arch.yaml`.
List<DoctorIssue> diagnose(FlutterProject project, {String? cliVersion}) {
  final lib = Directory(project.path('lib'));
  if (!lib.existsSync()) return const [];

  final dirs = [
    lib,
    ...lib.listSync(recursive: true).whereType<Directory>(),
  ].map((d) => _relative(project, d.path)).toList()..sort();

  // Every path some barrel exports, to require barrels that are referenced
  // even when their folder has no other Dart file.
  final exported = <String>{};
  for (final dir in dirs) {
    final barrel = File(project.path(_barrelOf(dir)));
    if (barrel.existsSync()) exported.addAll(_exportsOf(project, dir, barrel));
  }

  final issues = <DoctorIssue>[];
  for (final dir in dirs) {
    if (_skippedDirs.contains(dir)) continue;
    final barrelPath = _barrelOf(dir);
    final barrel = File(project.path(barrelPath));
    final expected = _expectedExports(project, dir, dirs, exported);
    final needsBarrel =
        barrel.existsSync() ||
        exported.contains(barrelPath) ||
        _hasOwnDartFiles(project, dir);
    if (!needsBarrel || expected.isEmpty) continue;

    if (!barrel.existsSync()) {
      issues.add(
        DoctorIssue(
          DoctorIssueKind.missingBarrel,
          barrelPath,
          expected.join(', '),
        ),
      );
      continue;
    }
    final actual = _exportsOf(project, dir, barrel);
    for (final uri in expected) {
      if (!actual.contains(p.posix.join(dir, uri))) {
        issues.add(DoctorIssue(DoctorIssueKind.missingExport, barrelPath, uri));
      }
    }
  }

  _requiredMarkers.forEach((file, markers) {
    final f = File(project.path(file));
    final source = f.existsSync() ? f.readAsStringSync() : '';
    for (final marker in markers) {
      if (!source.contains(marker)) {
        issues.add(DoctorIssue(DoctorIssueKind.missingMarker, file, marker));
      }
    }
  });

  const container = 'lib/core/di/injection_container.dart';
  final containerFile = File(project.path(container));
  final features = Directory(project.path('lib/features'));
  if (containerFile.existsSync() && features.existsSync()) {
    final source = containerFile.readAsStringSync();
    for (final dir in features.listSync().whereType<Directory>()) {
      final snake = p.basename(dir.path);
      if (!File(p.join(dir.path, '${snake}_injection.dart')).existsSync()) {
        continue;
      }
      final FeatureName feature;
      try {
        feature = FeatureName.parse(snake, allowTaken: true);
      } on FormatException {
        continue;
      }
      final call = 'init${feature.pascal}Dependencies(';
      if (!source.contains(call)) {
        issues.add(
          DoctorIssue(
            DoctorIssueKind.unregisteredFeature,
            container,
            '$call)',
          ),
        );
      }
    }
  }

  if (cliVersion != null) {
    final config = readProjectConfig(project.root);
    final last = config?.lastModifiedWith;
    if (config == null) {
      issues.add(
        const DoctorIssue(
          DoctorIssueKind.missingConfig,
          projectConfigFile,
          '',
        ),
      );
    } else if (last != null && compareVersions(last, cliVersion) > 0) {
      issues.add(
        DoctorIssue(DoctorIssueKind.newerProject, projectConfigFile, last),
      );
    }
  }
  return issues;
}

/// Fixes the [DoctorIssueKind.fixable] issues: creates the missing barrels
/// and adds the missing exports. Returns how many issues were fixed.
///
/// A missing `.flutter_clean_arch.yaml` is created with [cliVersion].
int fixIssues(
  FlutterProject project,
  List<DoctorIssue> issues, {
  String? cliVersion,
}) {
  var fixed = 0;
  for (final issue in issues) {
    final barrel = File(project.path(issue.file));
    switch (issue.kind) {
      case DoctorIssueKind.missingBarrel:
        for (final uri in issue.detail.split(', ')) {
          addExport(barrel, uri);
        }
        fixed++;
      case DoctorIssueKind.missingExport:
        addExport(barrel, issue.detail);
        fixed++;
      case DoctorIssueKind.missingConfig:
        writeProjectConfig(
          project.root,
          ProjectConfig(lastModifiedWith: cliVersion),
        );
        fixed++;
      case DoctorIssueKind.missingMarker:
      case DoctorIssueKind.unregisteredFeature:
      case DoctorIssueKind.newerProject:
        break;
    }
  }
  return fixed;
}

String _relative(FlutterProject project, String path) =>
    p.posix.joinAll(p.split(p.relative(path, from: project.root)));

/// `lib/a/b` → `lib/a/b/b.dart`.
String _barrelOf(String dir) => '$dir/${p.posix.basename(dir)}.dart';

List<File> _dartFiles(FlutterProject project, String dir) => Directory(
  project.path(dir),
).listSync().whereType<File>().where((f) => f.path.endsWith('.dart')).toList();

/// Whether [file] must not be exported by its barrel: `part of` files and
/// generated code (FlutterFire options, which all declare
/// `DefaultFirebaseOptions`; build_runner outputs; files whose header says
/// they are generated).
bool _isPart(File file) {
  final name = p.basename(file.path);
  if (name.startsWith('firebase_options') ||
      RegExp(r'\.(g|freezed|gr|config|mocks)\.dart$').hasMatch(name)) {
    return true;
  }
  final source = file.readAsStringSync();
  final header = source.length > 400 ? source.substring(0, 400) : source;
  return RegExp('^part of ', multiLine: true).hasMatch(source) ||
      RegExp(
        'GENERATED CODE|DO NOT EDIT|File generated by',
        caseSensitive: false,
      ).hasMatch(header);
}

bool _hasOwnDartFiles(FlutterProject project, String dir) => _dartFiles(
  project,
  dir,
).any((f) => _relative(project, f.path) != _barrelOf(dir) && !_isPart(f));

/// Exports the barrel of [dir] should have, relative to [dir]: its Dart
/// files (except parts and the barrel itself) and the barrels of its
/// sub-folders that need one.
List<String> _expectedExports(
  FlutterProject project,
  String dir,
  List<String> dirs,
  Set<String> exported,
) {
  final barrel = _barrelOf(dir);
  final files = [
    for (final f in _dartFiles(project, dir))
      if (_relative(project, f.path) != barrel && !_isPart(f))
        p.basename(f.path),
  ];
  final children = [
    for (final child in dirs)
      if (p.posix.dirname(child) == dir &&
          !_skippedDirs.contains(child) &&
          (File(project.path(_barrelOf(child))).existsSync() ||
              exported.contains(_barrelOf(child)) ||
              _hasOwnDartFiles(project, child)))
        '${p.posix.basename(child)}/${p.posix.basename(child)}.dart',
  ];
  return [...files, ...children]..sort();
}

/// Project-relative paths exported by [barrel] (in folder [dir]). Accepts
/// relative and `package:` URIs.
Set<String> _exportsOf(FlutterProject project, String dir, File barrel) {
  final uris = RegExp(
    r'''^export\s+['"]([^'"]+)['"]''',
    multiLine: true,
  ).allMatches(barrel.readAsStringSync()).map((m) => m[1]!);
  final prefix = 'package:${project.package}/';
  return {
    for (final uri in uris)
      if (uri.startsWith(prefix))
        'lib/${uri.substring(prefix.length)}'
      else if (!uri.contains(':'))
        p.posix.normalize(p.posix.join(dir, uri)),
  };
}
