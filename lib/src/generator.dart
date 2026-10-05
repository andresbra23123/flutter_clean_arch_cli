/// Renders the template folders into a project.
library;

import 'dart:io';
import 'dart:isolate';

import 'package:flutter_clean_arch/src/journal.dart';
import 'package:path/path.dart' as p;

/// Placeholder used in template file and folder names for the feature name.
const pathNamePlaceholder = '__name__';

/// A file ready to be written: its path relative to the project and its
/// rendered content.
class RenderedFile {
  /// Creates a file to write at [relativePath] with [content].
  const RenderedFile(this.relativePath, this.content);

  /// Path relative to the project root, always with `/`.
  final String relativePath;

  /// Rendered content of the file.
  final String content;
}

/// Reads `.tmpl` files and replaces their `{{variables}}`.
class TemplateGenerator {
  /// Creates a generator that reads the templates under [templatesRoot].
  const TemplateGenerator(this.templatesRoot);

  /// Folder that contains the `init/` and `feature/` templates.
  final String templatesRoot;

  /// Finds the templates shipped inside this package.
  static Future<TemplateGenerator> locate() async {
    final uri = await Isolate.resolvePackageUri(
      Uri.parse('package:flutter_clean_arch/templates/'),
    );
    if (uri == null) {
      throw StateError('No se encontraron las plantillas del paquete.');
    }
    return TemplateGenerator(p.fromUri(uri));
  }

  /// Renders every template under [templateDir] (e.g. `init` or `feature`).
  ///
  /// [vars] replaces `{{key}}` in the content; `vars['name']` also replaces
  /// [pathNamePlaceholder] in file and folder names. The `.tmpl` extension
  /// is removed and the output paths are prefixed with [outputPrefix].
  List<RenderedFile> render(
    String templateDir,
    Map<String, String> vars, {
    String outputPrefix = '',
  }) {
    final dir = Directory(p.join(templatesRoot, templateDir));
    if (!dir.existsSync()) {
      throw StateError('No existe la carpeta de plantillas ${dir.path}.');
    }
    final files =
        dir
            .listSync(recursive: true)
            .whereType<File>()
            .where((f) => f.path.endsWith('.tmpl'))
            .toList()
          ..sort((a, b) => a.path.compareTo(b.path));

    return [
      for (final file in files)
        RenderedFile(
          _renderPath(
            p.join(outputPrefix, p.relative(file.path, from: dir.path)),
            vars,
          ),
          renderString(file.readAsStringSync(), vars),
        ),
    ];
  }

  String _renderPath(String relative, Map<String, String> vars) {
    var out = relative.substring(0, relative.length - '.tmpl'.length);
    final name = vars['name'];
    if (name != null) out = out.replaceAll(pathNamePlaceholder, name);
    // Always use forward slashes so paths are stable on every OS.
    return p.posix.joinAll(p.split(out));
  }
}

/// Replaces every `{{key}}` in [source] with `vars[key]`.
String renderString(String source, Map<String, String> vars) {
  var out = source;
  vars.forEach((key, value) => out = out.replaceAll('{{$key}}', value));
  return out;
}

/// Writes [files] under [root], creating the folders they need.
void writeAll(String root, List<RenderedFile> files) {
  for (final f in files) {
    writeText(p.join(root, f.relativePath), f.content);
  }
}
