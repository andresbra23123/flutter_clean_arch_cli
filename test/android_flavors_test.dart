import 'dart:io';

import 'package:flutter_clean_arch/flutter_clean_arch.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

const _gradle = '''
android {
    defaultConfig {
        applicationId = "com.example.demo_app"
    }

    buildTypes {
        release {
            signingConfig = signingConfigs.getByName("debug")
        }
    }
}
''';

const _manifest = r'''
<manifest xmlns:android="http://schemas.android.com/apk/res/android">
    <application
        android:label="demo_app"
        android:name="${applicationName}">
    </application>
</manifest>
''';

void main() {
  late Directory dir;

  setUp(() => dir = Directory.systemTemp.createTempSync('fca_flv_'));
  tearDown(() => dir.deleteSync(recursive: true));

  File write(String name, String content) =>
      File(p.join(dir.path, name))..writeAsStringSync(content);

  group('addProductFlavors', () {
    test('inserts the three flavors before buildTypes', () {
      final file = write('build.gradle.kts', _gradle);

      expect(addProductFlavors(file, 'Demo App'), FlavorResult.updated);

      final out = file.readAsStringSync();
      expect(out, contains('create("development")'));
      expect(out, contains('applicationIdSuffix = ".stg"'));
      expect(out, contains('"[DEV] Demo App"'));
      expect(
        out.indexOf('productFlavors'),
        lessThan(out.indexOf('buildTypes')),
      );
    });

    test('is idempotent', () {
      final file = write('build.gradle.kts', _gradle);
      addProductFlavors(file, 'Demo App');

      expect(
        addProductFlavors(file, 'Demo App'),
        FlavorResult.alreadyConfigured,
      );
      expect(
        'productFlavors'.allMatches(file.readAsStringSync()),
        hasLength(1),
      );
    });

    test('does nothing without buildTypes or file', () {
      final file = write('build.gradle.kts', 'android {}\n');

      expect(addProductFlavors(file, 'X'), FlavorResult.notApplied);
      expect(file.readAsStringSync(), 'android {}\n');
      expect(
        addProductFlavors(File(p.join(dir.path, 'none.kts')), 'X'),
        FlavorResult.notApplied,
      );
    });
  });

  group('useFlavorAppName', () {
    test(r'sets android:label to ${appName}', () {
      final file = write('AndroidManifest.xml', _manifest);

      expect(useFlavorAppName(file), FlavorResult.updated);
      expect(file.readAsStringSync(), contains(r'android:label="${appName}"'));
      expect(
        file.readAsStringSync(),
        contains(r'android:name="${applicationName}"'),
      );
      expect(useFlavorAppName(file), FlavorResult.alreadyConfigured);
    });
  });
}
