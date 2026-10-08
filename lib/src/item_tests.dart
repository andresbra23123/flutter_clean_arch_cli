/// Tests for what `page`, `bloc` and `usecase` add to a feature (their
/// `--tests` option).
library;

import 'package:flutter_clean_arch/src/generator.dart';
import 'package:flutter_clean_arch/src/journal.dart';
import 'package:flutter_clean_arch/src/naming.dart';
import 'package:flutter_clean_arch/src/project.dart';
import 'package:flutter_clean_arch/src/registry.dart';

/// What the tests are for.
enum ItemTestKind {
  /// A page without BLoC (`page`).
  page,

  /// A page with its BLoC (`page --bloc`): tests the view with a mock BLoC.
  pageWithBloc,

  /// A BLoC (`bloc`).
  bloc,

  /// A Cubit (`bloc --cubit`).
  cubit,
}

/// Writes the test of [item] under `test/features/<feature>/…`, mirroring
/// its path in `lib/`. Returns the relative paths written.
Future<List<String>> writeItemTests(
  FlutterProject project,
  FeatureName feature,
  FeatureName item,
  ItemTestKind kind,
) async {
  final (template, folder) = switch (kind) {
    ItemTestKind.page => ('test_page', 'pages'),
    ItemTestKind.pageWithBloc => ('test_page_bloc', 'pages'),
    ItemTestKind.bloc => ('test_bloc', 'bloc'),
    ItemTestKind.cubit => ('test_cubit', 'bloc'),
  };
  final generator = await TemplateGenerator.locate();
  final files = generator.render(
    template,
    itemVars(project, feature, item),
    outputPrefix: 'test/features/${feature.snake}/presentation/$folder',
  );
  writeAll(project.root, files);
  return [for (final f in files) f.relativePath];
}

/// Writes the test of the use case [item] and returns its relative path.
String writeUsecaseTest(
  FlutterProject project,
  FeatureName feature,
  FeatureName item, {
  required String returns,
  required String params,
}) {
  final relative =
      'test/features/${feature.snake}/domain/usecases/${item.snake}_test.dart';
  writeText(
    project.path(relative),
    usecaseTest(
      package: project.package,
      todoTag: todoTagFromPackage(project.package),
      feature: feature,
      item: item,
      returns: returns,
      params: params,
    ),
  );
  return relative;
}

/// A constant value of the Dart type [type] (declared with `const`), or
/// `null` when the type is unknown (a class of the project).
String? sampleValue(String type) {
  final t = type.trim();
  if (t.endsWith('?')) return 'null';
  final generic = RegExp(r'^(List|Set|Map)<(.+)>$').firstMatch(t);
  if (generic != null) {
    return switch (generic[1]) {
      'List' => '<${generic[2]}>[]',
      'Set' => '<${generic[2]}>{}',
      _ => '<${generic[2]}>{}',
    };
  }
  return switch (t) {
    'Unit' => 'unit',
    'String' => "'value'",
    'int' => '1',
    'double' => '1.5',
    'num' => '1',
    'bool' => 'true',
    'NoParams' => 'NoParams()',
    _ => null,
  };
}

/// Test of a use case created by `usecase`.
///
/// Checks that the use case returns the repository's result and forwards
/// its failures. When [returns] or [params] is a project class, the test
/// that needs a value of it is skipped with a TODO explaining what to fill.
String usecaseTest({
  required String package,
  required String todoTag,
  required FeatureName feature,
  required FeatureName item,
  required String returns,
  required String params,
}) {
  final noParams = params == 'NoParams';
  final paramsValue = sampleValue(params);
  final resultValue = sampleValue(returns);
  final call = noParams ? '${item.camel}()' : '${item.camel}(params)';
  final repository = '${feature.pascal}RepositoryInter';
  final useCase = '${item.pascal}UseCaseImpl';

  String skip(String what) =>
      ", skip: 'TODO($todoTag): crea un valor de $what para este test'";
  final paramsSkip = paramsValue == null ? skip(params) : '';
  final successSkip = paramsValue == null
      ? paramsSkip
      : resultValue == null
      ? skip(returns)
      : '';

  String declare(String name, String type, String? value) {
    if (value == null) {
      return '// TODO($todoTag): Create a $type for the tests.\n'
          '  late $type $name;';
    }
    // Every sample value is a constant (NoParams has a const constructor).
    return 'const $name = $value;';
  }

  final right = resultValue == null ? 'Right' : 'const Right';

  return '''
import 'package:$package/core/errors/errors.dart';
import 'package:$package/core/usecases/usecases.dart';
import 'package:$package/features/${feature.snake}/${feature.snake}.dart';
import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockRepository extends Mock implements $repository {}

void main() {
  late _MockRepository repository;
  late $useCase useCase;

  ${declare('params', params, paramsValue)}

  setUp(() {
    repository = _MockRepository();
    useCase = $useCase(repository: repository);
  });

  test('returns the result of the repository', () async {
    ${declare('result', returns, resultValue).replaceAll('\n  ', '\n    ')}
    when(
      () => repository.$call,
    ).thenAnswer((_) async => $right(result));

    expect(await useCase(params), $right<Failure, $returns>(result));
    verify(() => repository.$call).called(1);
  }$successSkip);

  test('forwards the failure of the repository', () async {
    const failure = ServerFailure(message: 'error');
    when(
      () => repository.$call,
    ).thenAnswer((_) async => const Left(failure));

    expect(await useCase(params), const Left<Failure, $returns>(failure));
  }$paramsSkip);
}
''';
}
