/// Adds the development / staging / production flavors to the Android app,
/// so `flutter run --flavor <name>` (used by `.vscode/launch.json`) works.
library;

import 'dart:io';

import 'package:flutter_clean_arch/src/journal.dart';

/// Outcome of a flavor configuration step.
enum FlavorResult {
  /// The file was updated.
  updated,

  /// The file already had the configuration; nothing changed.
  alreadyConfigured,

  /// The file does not exist or has an unexpected shape; nothing changed.
  notApplied,
}

/// `productFlavors` block for `android/app/build.gradle.kts`.
///
/// Each flavor gets its own application id suffix, so the three can be
/// installed side by side, and its own visible name through the
/// `appName` manifest placeholder.
String productFlavorsBlock(String appTitle) =>
    '''
    flavorDimensions += "default"
    productFlavors {
        create("production") {
            dimension = "default"
            applicationIdSuffix = ""
            manifestPlaceholders["appName"] = "$appTitle"
        }
        create("staging") {
            dimension = "default"
            applicationIdSuffix = ".stg"
            manifestPlaceholders["appName"] = "[STG] $appTitle"
        }
        create("development") {
            dimension = "default"
            applicationIdSuffix = ".dev"
            manifestPlaceholders["appName"] = "[DEV] $appTitle"
        }
    }
''';

/// Inserts [productFlavorsBlock] right before the `buildTypes {` block of a
/// Kotlin DSL Gradle file.
FlavorResult addProductFlavors(File gradleKts, String appTitle) {
  final source = readText(gradleKts.path);
  if (source == null) return FlavorResult.notApplied;
  if (source.contains('productFlavors')) return FlavorResult.alreadyConfigured;

  final eol = source.contains('\r\n') ? '\r\n' : '\n';
  final lines = source.replaceAll('\r\n', '\n').split('\n');
  final index = lines.indexWhere(
    (l) => RegExp(r'^\s*buildTypes\s*\{').hasMatch(l),
  );
  if (index == -1) return FlavorResult.notApplied;

  lines.insertAll(index, productFlavorsBlock(appTitle).split('\n'));
  writeText(gradleKts.path, lines.join('\n').replaceAll('\n', eol));
  return FlavorResult.updated;
}

/// Makes the app label come from the flavor (`android:label="${appName}"`).
FlavorResult useFlavorAppName(File manifest) {
  final source = readText(manifest.path);
  if (source == null) return FlavorResult.notApplied;
  if (source.contains(r'android:label="${appName}"')) {
    return FlavorResult.alreadyConfigured;
  }
  final label = RegExp('android:label="[^"]*"');
  if (!label.hasMatch(source)) return FlavorResult.notApplied;

  writeText(
    manifest.path,
    source.replaceFirst(label, r'android:label="${appName}"'),
  );
  return FlavorResult.updated;
}
