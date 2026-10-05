import 'dart:io';

import 'package:flutter_clean_arch/flutter_clean_arch.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

void main() {
  late Directory dir;
  late FlutterProject project;

  void write(String relative, String content) =>
      File(p.join(dir.path, relative))
        ..createSync(recursive: true)
        ..writeAsStringSync(content);

  setUp(() {
    dir = Directory.systemTemp.createTempSync('fca_doctor_');
    write(
      'pubspec.yaml',
      'name: demo_app\ndependencies:\n  flutter:\n    sdk: flutter\n',
    );
    write(
      'lib/core/di/injection_container.dart',
      '${Markers.featureImports}\n'
          'void initDependencies() {\n'
          '  initSongsDependencies();\n'
          '  ${Markers.featureInit}\n'
          '}\n',
    );
    write(
      'lib/core/di/di.dart',
      "library;\n\nexport 'injection_container.dart';\n",
    );
    write(
      'lib/core/router/app_router.dart',
      '${Markers.featureImports}\n${Markers.routes}\n',
    );
    write('lib/core/router/app_routes.dart', '${Markers.routes}\n');
    write(
      'lib/core/router/router.dart',
      "library;\n\nexport 'app_router.dart';\nexport 'app_routes.dart';\n",
    );
    write('lib/main.dart', 'void main() {}\n');
    // A feature with a BLoC whose event is a `part of` file.
    write(
      'lib/features/songs/songs.dart',
      "library;\n\nexport 'presentation/presentation.dart';\n"
          "export 'songs_injection.dart';\n",
    );
    write('lib/features/songs/songs_injection.dart', '');
    write(
      'lib/features/songs/presentation/presentation.dart',
      "library;\n\nexport 'bloc/bloc.dart';\n",
    );
    write(
      'lib/features/songs/presentation/bloc/bloc.dart',
      "library;\n\nexport 'songs_bloc.dart';\n",
    );
    write('lib/features/songs/presentation/bloc/songs_bloc.dart', '');
    write(
      'lib/features/songs/presentation/bloc/songs_event.dart',
      "part of 'songs_bloc.dart';\n",
    );
    project = FlutterProject.load(dir.path);
  });
  tearDown(() => dir.deleteSync(recursive: true));

  test('a project that follows the structure has no issues', () {
    expect(diagnose(project), isEmpty);
  });

  test('reports missing barrels, exports, markers and registrations', () {
    // Page folder without barrel.
    write('lib/features/songs/presentation/pages/songs_page.dart', '');
    // File not exported by its barrel.
    write('lib/core/router/not_found_page.dart', '');
    // Marker removed.
    write('lib/core/router/app_routes.dart', '');
    // Feature not called from initDependencies().
    write('lib/features/albums/albums_injection.dart', '');
    write(
      'lib/features/albums/albums.dart',
      "library;\n\nexport 'albums_injection.dart';\n",
    );

    final issues = diagnose(project).map((i) => (i.kind, i.file, i.detail));

    expect(
      issues,
      unorderedEquals([
        (
          DoctorIssueKind.missingBarrel,
          'lib/features/songs/presentation/pages/pages.dart',
          'songs_page.dart',
        ),
        (
          DoctorIssueKind.missingExport,
          'lib/features/songs/presentation/presentation.dart',
          'pages/pages.dart',
        ),
        (
          DoctorIssueKind.missingExport,
          'lib/core/router/router.dart',
          'not_found_page.dart',
        ),
        (
          DoctorIssueKind.missingMarker,
          'lib/core/router/app_routes.dart',
          Markers.routes,
        ),
        (
          DoctorIssueKind.unregisteredFeature,
          'lib/core/di/injection_container.dart',
          'initAlbumsDependencies()',
        ),
      ]),
    );
  });

  test('fixIssues creates barrels and exports, not markers', () {
    write('lib/features/songs/presentation/pages/songs_page.dart', '');
    write('lib/core/router/not_found_page.dart', '');
    write('lib/core/router/app_routes.dart', '');

    final fixed = fixIssues(project, diagnose(project));

    expect(fixed, 3);
    expect(
      diagnose(project).map((i) => i.kind),
      [DoctorIssueKind.missingMarker],
    );
    expect(
      File(
        p.join(dir.path, 'lib/features/songs/presentation/pages/pages.dart'),
      ).readAsStringSync(),
      contains("export 'songs_page.dart';"),
    );
  });

  group('.flutter_clean_arch.yaml', () {
    test('missing: reported only with a CLI version, and fixable', () {
      expect(diagnose(project), isEmpty);

      final issues = diagnose(project, cliVersion: '0.4.0');
      expect(issues.map((i) => i.kind), [DoctorIssueKind.missingConfig]);

      fixIssues(project, issues, cliVersion: '0.4.0');
      expect(readProjectConfig(dir.path)?.lastModifiedWith, '0.4.0');
      expect(diagnose(project, cliVersion: '0.4.0'), isEmpty);
    });

    test('changed by a newer CLI: asks to update the installed one', () {
      writeProjectConfig(
        dir.path,
        const ProjectConfig(lastModifiedWith: '9.0.0'),
      );

      final issues = diagnose(project, cliVersion: '0.4.0');

      expect(issues.single.kind, DoctorIssueKind.newerProject);
      expect(issues.single.kind.fixable, isFalse);
      expect(issues.single.toString(), contains('9.0.0'));
    });
  });
}
