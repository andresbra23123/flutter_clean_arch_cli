import 'dart:io';

import 'package:flutter_clean_arch/flutter_clean_arch.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

void main() {
  late Directory dir;
  late File file;

  setUp(() {
    dir = Directory.systemTemp.createTempSync('fca_inj_');
    file = File(p.join(dir.path, 'a.dart'));
  });
  tearDown(() => dir.deleteSync(recursive: true));

  const marker = '// flutter_clean_arch:routes';

  test('inserts before the marker', () {
    file.writeAsStringSync('start\n  $marker\nend\n');

    final result = insertBeforeMarker(file, marker, '  line');

    expect(result, InjectResult.inserted);
    expect(file.readAsStringSync(), 'start\n  line\n  $marker\nend\n');
  });

  test('does not duplicate when run twice', () {
    file.writeAsStringSync('start\n$marker\n');

    insertBeforeMarker(file, marker, 'line');
    final second = insertBeforeMarker(file, marker, 'line');

    expect(second, InjectResult.alreadyPresent);
    expect('line'.allMatches(file.readAsStringSync()), hasLength(1));
  });

  test('keeps CRLF line endings', () {
    file.writeAsStringSync('start\r\n$marker\r\n');

    insertBeforeMarker(file, marker, 'a\nb');

    expect(file.readAsStringSync(), 'start\r\na\r\nb\r\n$marker\r\n');
  });

  test('reports a missing marker or file without changes', () {
    file.writeAsStringSync('no marker here\n');

    expect(insertBeforeMarker(file, marker, 'x'), InjectResult.markerNotFound);
    expect(file.readAsStringSync(), 'no marker here\n');
    expect(
      insertBeforeMarker(File(p.join(dir.path, 'missing.dart')), marker, 'x'),
      InjectResult.markerNotFound,
    );
  });

  group('addExport', () {
    test('inserts the export keeping them sorted', () {
      file.writeAsStringSync(
        "/// Doc.\nlibrary;\n\nexport 'a.dart';\nexport 'c.dart';\n",
      );

      expect(addExport(file, 'b.dart'), InjectResult.inserted);
      addExport(file, 'd.dart');

      expect(
        file.readAsStringSync(),
        "/// Doc.\nlibrary;\n\nexport 'a.dart';\nexport 'b.dart';\n"
        "export 'c.dart';\nexport 'd.dart';\n",
      );
    });

    test('is idempotent', () {
      file.writeAsStringSync("library;\n\nexport 'a.dart';\n");

      expect(addExport(file, 'a.dart'), InjectResult.alreadyPresent);
      expect(file.readAsStringSync(), "library;\n\nexport 'a.dart';\n");
    });

    test('adds the first export to a barrel without exports', () {
      file.writeAsStringSync('/// Doc.\nlibrary;\n');

      addExport(file, 'a.dart');

      expect(
        file.readAsStringSync(),
        "/// Doc.\nlibrary;\n\nexport 'a.dart';\n",
      );
    });

    test('creates a missing barrel', () {
      final barrel = File(p.join(dir.path, 'x', 'x.dart'));

      expect(addExport(barrel, 'a.dart'), InjectResult.inserted);
      expect(
        barrel.readAsStringSync(),
        contains("library;\n\nexport 'a.dart';"),
      );
    });

    test('keeps CRLF line endings', () {
      file.writeAsStringSync("library;\r\n\r\nexport 'b.dart';\r\n");

      addExport(file, 'a.dart');

      expect(
        file.readAsStringSync(),
        "library;\r\n\r\nexport 'a.dart';\r\nexport 'b.dart';\r\n",
      );
    });
  });

  group('ensureImports', () {
    const typeDefs = "import 'package:demo_app/core/type_defs/type_defs.dart';";

    test('adds a missing import after the last one', () {
      file.writeAsStringSync("import 'a.dart';\r\n\r\nclass A {}\r\n");

      ensureImports(file, [typeDefs]);

      expect(
        file.readAsStringSync(),
        "import 'a.dart';\r\n$typeDefs\r\n\r\nclass A {}\r\n",
      );
    });

    test('does nothing when the import is already there', () {
      file.writeAsStringSync('$typeDefs\n\nclass A {}\n');

      ensureImports(file, [typeDefs]);

      expect(file.readAsStringSync(), '$typeDefs\n\nclass A {}\n');
    });
  });
}
