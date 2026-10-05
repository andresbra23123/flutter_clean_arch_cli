import 'dart:io';

import 'package:flutter_clean_arch/flutter_clean_arch.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';
import 'package:yaml/yaml.dart';

void main() {
  late Directory dir;

  setUp(() => dir = Directory.systemTemp.createTempSync('fca_config_'));
  tearDown(() => dir.deleteSync(recursive: true));

  test('writes and reads the configuration', () {
    writeProjectConfig(
      dir.path,
      const ProjectConfig(
        createdWith: '0.3.1',
        lastModifiedWith: '0.4.0',
        auth: true,
      ),
    );

    final config = readProjectConfig(dir.path)!;
    expect(config.createdWith, '0.3.1');
    expect(config.lastModifiedWith, '0.4.0');
    expect(config.auth, isTrue);
  });

  test('a missing file reads as null', () {
    expect(readProjectConfig(dir.path), isNull);
  });

  test('compareVersions orders major.minor.patch', () {
    expect(compareVersions('0.3.1', '0.4.0'), isNegative);
    expect(compareVersions('1.0.0', '0.9.9'), isPositive);
    expect(compareVersions('0.4.0', '0.4.0'), 0);
    expect(compareVersions('0.10.0', '0.9.0'), isPositive);
  });

  test('CHANGELOG has an entry for the version of pubspec.yaml', () {
    final pubspec = loadYaml(File('pubspec.yaml').readAsStringSync()) as Map;
    final changelog = File(p.join('CHANGELOG.md')).readAsStringSync();

    expect(changelog, contains('## ${pubspec['version']}'));
  });
}
