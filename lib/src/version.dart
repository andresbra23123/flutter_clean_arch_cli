/// Version of the installed CLI.
library;

import 'dart:io';
import 'dart:isolate';

import 'package:path/path.dart' as p;
import 'package:yaml/yaml.dart';

/// Version from the `pubspec.yaml` of this package, wherever it is
/// installed (path, git or pub cache). `null` if it cannot be read.
Future<String?> cliVersion() async {
  final lib = await Isolate.resolvePackageUri(
    Uri.parse('package:flutter_clean_arch/'),
  );
  if (lib == null) return null;
  final pubspec = File(p.join(p.dirname(p.fromUri(lib)), 'pubspec.yaml'));
  if (!pubspec.existsSync()) return null;
  final yaml = loadYaml(pubspec.readAsStringSync());
  return yaml is YamlMap ? yaml['version']?.toString() : null;
}

/// Where the changes of every version are described.
const changelogUrl =
    'https://github.com/andresbra23123/flutter_clean_arch_cli'
    '/blob/main/CHANGELOG.md';
