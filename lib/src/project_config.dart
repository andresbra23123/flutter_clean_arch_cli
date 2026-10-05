/// `.flutter_clean_arch.yaml`: which CLI versions created and last changed
/// a project, so `doctor` can tell when the CLI and the project differ.
library;

import 'package:flutter_clean_arch/src/journal.dart';
import 'package:path/path.dart' as p;
import 'package:yaml/yaml.dart';

/// Name of the file, at the project root.
const projectConfigFile = '.flutter_clean_arch.yaml';

/// Content of [projectConfigFile].
class ProjectConfig {
  /// Creates a configuration.
  const ProjectConfig({
    this.createdWith,
    this.lastModifiedWith,
    this.auth = false,
  });

  /// CLI version that ran `init`, if known.
  final String? createdWith;

  /// CLI version that last changed the project.
  final String? lastModifiedWith;

  /// Whether the auth feature is installed.
  final bool auth;

  /// A copy with the given fields replaced.
  ProjectConfig copyWith({String? lastModifiedWith, bool? auth}) =>
      ProjectConfig(
        createdWith: createdWith,
        lastModifiedWith: lastModifiedWith ?? this.lastModifiedWith,
        auth: auth ?? this.auth,
      );
}

/// Reads [projectConfigFile] from the project at [root], or `null` if it
/// does not exist or cannot be parsed.
ProjectConfig? readProjectConfig(String root) {
  final source = readText(p.join(root, projectConfigFile));
  if (source == null) return null;
  final Object? yaml;
  try {
    yaml = loadYaml(source);
  } on YamlException {
    return null;
  }
  if (yaml is! YamlMap) return const ProjectConfig();
  return ProjectConfig(
    createdWith: yaml['created_with']?.toString(),
    lastModifiedWith: yaml['last_modified_with']?.toString(),
    auth: yaml['auth'] == true,
  );
}

/// Writes [config] to [projectConfigFile] in the project at [root].
void writeProjectConfig(String root, ProjectConfig config) {
  writeText(p.join(root, projectConfigFile), '''
# Created by flutter_clean_arch. Keep it in version control: `doctor` uses
# it to warn when the installed CLI and this project differ.
${config.createdWith == null ? '' : 'created_with: ${config.createdWith}\n'}${config.lastModifiedWith == null ? '' : 'last_modified_with: ${config.lastModifiedWith}\n'}auth: ${config.auth}
''');
}

/// Compares two `major.minor.patch` versions: negative if [a] is older
/// than [b], 0 if equal, positive if newer. Unparseable parts count as 0.
int compareVersions(String a, String b) {
  List<int> parts(String v) => [
    for (final s in v.split('-').first.split('.')) int.tryParse(s) ?? 0,
    0,
    0,
    0,
  ].take(3).toList();
  final (x, y) = (parts(a), parts(b));
  for (var i = 0; i < 3; i++) {
    if (x[i] != y[i]) return x[i] - y[i];
  }
  return 0;
}
