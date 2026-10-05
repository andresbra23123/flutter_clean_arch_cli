import 'dart:io';

import 'package:flutter_clean_arch/flutter_clean_arch.dart';
import 'package:test/test.dart';
import 'package:yaml/yaml.dart';

void main() {
  test('cliVersion reads the version of pubspec.yaml', () async {
    final pubspec = loadYaml(File('pubspec.yaml').readAsStringSync()) as Map;

    expect(await cliVersion(), pubspec['version']);
  });

  test('CliRunner registers every command and --version', () {
    final runner = CliRunner();

    expect(
      runner.commands.keys,
      containsAll([
        'init',
        'auth',
        'feature',
        'page',
        'bloc',
        'usecase',
        'component',
        'widget',
        'model',
        'test',
        'remove',
        'rename',
        'doctor',
      ]),
    );
    expect(runner.argParser.options['version']?.abbr, 'v');
  });

  test('commands that change files get --dry-run and --allow-dirty', () {
    final runner = CliRunner();

    for (final name in ['init', 'feature', 'usecase', 'model']) {
      expect(
        runner.commands[name]!.argParser.options.keys,
        containsAll(['dry-run', 'allow-dirty']),
        reason: name,
      );
    }
    final removePage = runner.commands['remove']!.subcommands['page']!;
    expect(removePage.argParser.options.keys, contains('allow-dirty'));
    // doctor only reads (or fixes barrels): no git check.
    expect(
      runner.commands['doctor']!.argParser.options.keys,
      isNot(contains('allow-dirty')),
    );
    expect(
      runner.commands['help']!.argParser.options.keys,
      isNot(contains('dry-run')),
    );
  });
}
