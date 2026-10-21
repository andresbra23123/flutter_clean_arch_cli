/// Adds the processing queue (an offline outbox stored in SQLite) to an
/// initialized project: the local database, the queue core, the
/// `processing_queue` feature, two example features that send their
/// operations through it (`transactions` and `feedback`), their tests, and
/// the changes they need in the base files. Shared by `init --queue` and
/// `queue`.
library;

import 'dart:io';

import 'package:flutter_clean_arch/src/base_patch.dart';
import 'package:flutter_clean_arch/src/dependencies.dart';
import 'package:flutter_clean_arch/src/generator.dart';
import 'package:flutter_clean_arch/src/injector.dart';
import 'package:flutter_clean_arch/src/naming.dart';
import 'package:flutter_clean_arch/src/process_runner.dart';
import 'package:flutter_clean_arch/src/project.dart';
import 'package:flutter_clean_arch/src/registry.dart';

/// Runtime and dev dependencies the queue needs, with the version ranges
/// its templates are tested with.
const queueDependencies = [
  'sqflite:^2.4.4+2',
  'path:^1.9.1',
  'dev:sqflite_common_ffi:^2.4.4',
];

/// Features created by the queue, in registration order: the queue itself
/// and the two examples that enqueue operations.
const queueFeatures = ['processing_queue', 'transactions', 'feedback'];

/// Test helpers of the queue, exported by `test/helpers/helpers.dart`.
const _testHelpers = [
  'accepting_queue_handler.dart',
  'fake_api.dart',
  'test_database.dart',
];

/// Installs the queue in [project]. With [runPub], adds the dependencies
/// and regenerates l10n. Returns the exit code of the first failing step,
/// or 0.
Future<int> installQueue(
  FlutterProject project, {
  required bool runPub,
}) async {
  applyQueueChanges(project, await TemplateGenerator.locate());

  if (runPub) {
    addDependencies(project, queueDependencies);
    for (final step in [
      ['pub', 'get'],
      ['gen-l10n'],
    ]) {
      final code = await runCommand(
        'flutter',
        step,
        workingDirectory: project.root,
      );
      if (code != 0) return code;
    }
  }
  final code = await runPostSteps(project, ['lib', 'test']);
  if (code != 0) return code;

  _printNextSteps();
  return 0;
}

/// File changes of [installQueue], without running any external command:
/// writes the queue, its example features and their tests and the ARB
/// keys, registers the features and patches the base files. Idempotent.
void applyQueueChanges(FlutterProject project, TemplateGenerator generator) {
  final vars = {
    'package': project.package,
    'todoTag': todoTagFromPackage(project.package),
    'appTitle': appTitleFromPackage(project.package),
  };
  final files = generator.render('queue', vars);
  writeAll(project.root, files);
  stdout.writeln('✓ ${files.length} archivos de la cola creados.');

  mergeArb(project, generator.render('queue_l10n', vars), 'la cola');
  for (final helper in _testHelpers) {
    registerExport(project, 'test/helpers/helpers.dart', helper);
  }
  _registerFeatures(project);
  for (final patch in _patches(project)) {
    patch.apply(project);
  }
}

/// Registers each of [queueFeatures] like `feature` does: its
/// dependencies in the DI container and its page in the router.
void _registerFeatures(FlutterProject project) {
  for (final name in queueFeatures) {
    final feature = FeatureName.parse(name);
    final barrelImport = featureBarrelImport(project, feature);
    inject(
      project,
      'lib/core/di/injection_container.dart',
      Markers.featureImports,
      barrelImport,
    );
    inject(
      project,
      'lib/core/di/injection_container.dart',
      Markers.featureInit,
      '  init${feature.pascal}Dependencies();',
    );
    inject(
      project,
      'lib/core/router/app_routes.dart',
      Markers.routes,
      routeConstants(
        constName: feature.camel,
        path: '/${feature.snake}',
        routeName: feature.snake,
        title: feature.title,
        words: feature.lowerWords,
      ),
    );
    inject(
      project,
      'lib/core/router/app_router.dart',
      Markers.featureImports,
      barrelImport,
    );
    inject(
      project,
      'lib/core/router/app_router.dart',
      Markers.routes,
      goRoute(constName: feature.camel, pageClass: '${feature.pascal}Page'),
    );
  }
}

List<BasePatch> _patches(FlutterProject project) {
  final pkg = project.package;
  final queueImport =
      "import 'package:$pkg/features/processing_queue/processing_queue.dart';";

  return [
    BasePatch(
      'lib/core/api/api_client.dart',
      'método send para las operaciones de la cola',
      done: (s) => s.contains('idempotencyHeader'),
      edit: (s) {
        const anchor = '  /// [data] as sent: a multipart form';
        const dioField = '  final Dio dio = Dio(';
        if (!s.contains(anchor) || !s.contains(dioField)) return null;
        return addImports(
          s
              .replaceFirst(dioField, '$_idempotencyHeader$dioField')
              .replaceFirst(anchor, '$_send$anchor'),
          ["import 'dart:io';"],
        );
      },
      manual:
          'agrega a ApiClient la constante `idempotencyHeader` y el método '
          '`send(method, path, {data, files, idempotencyKey, timeout})` '
          '(ver la plantilla queue).',
    ),
    BasePatch(
      'lib/core/di/injection_container.dart',
      'base de datos local y registro de handlers de la cola',
      done: (s) => s.contains('AppDatabase.open('),
      edit: (s) {
        const apiClient = '    ..registerLazySingleton(() => ApiClient());';
        if (!s.contains(apiClient)) return null;
        return addImports(
          s.replaceFirst(apiClient, _coreRegistrations),
          [
            "import 'package:$pkg/core/database/database.dart';",
            "import 'package:$pkg/core/queue_sync/queue_sync.dart';",
          ],
        );
      },
      manual:
          'registra en initDependencies `AppDatabase.open(schemas: '
          '[processingQueueSchema, transactionsSchema, feedbackSchema])`, '
          'la misma instancia como `UnitOfWork` y un `QueueHandlerRegistry`.',
    ),
    BasePatch(
      'lib/bootstrap.dart',
      'arranque del servicio que libera la cola',
      done: (s) => s.contains('QueueSyncService'),
      edit: (s) {
        final init = RegExp(r'await initDependencies\([^;]*\);');
        final match = init.firstMatch(s);
        if (match == null) return null;
        return addImports(
          s.replaceRange(match.start, match.end, '${match[0]}$_startQueue'),
          [queueImport],
        );
      },
      manual:
          'después de `await initDependencies()` llama a '
          '`await getIt<QueueSyncService>().start();`.',
    ),
    BasePatch(
      'lib/features/home/presentation/pages/home/components/'
          'home_welcome.dart',
      'accesos a la cola, transacciones y reportes',
      done: (s) => s.contains('processingQueueName'),
      edit: (s) {
        if (!s.contains(_welcomeText)) return null;
        return addImports(
          s.replaceFirst(_welcomeText, _welcomeShortcuts),
          [
            "import 'package:go_router/go_router.dart';",
            "import 'package:$pkg/core/router/router.dart';",
          ],
        );
      },
      manual:
          'agrega en HomeWelcome botones que naveguen a '
          'AppRoutes.transactionsName, feedbackName y processingQueueName.',
    ),
  ];
}

const _idempotencyHeader = '''
  /// Header that lets the API detect a duplicated request, e.g. when the
  /// response was lost and the processing queue sends the same operation
  /// again.
  static const String idempotencyHeader = 'Idempotency-Key';

''';

const _send = '''
  /// Operation sent by the processing queue: a [method] request to [path]
  /// with the [idempotencyKey] of its queue item. It is a multipart form
  /// when it has [files] (the ones missing on the device are skipped; [data]
  /// must then be a `Map<String, dynamic>`), with its own send and receive
  /// [timeout] if any.
  Future<Response> send(
    String method,
    String path, {
    required String idempotencyKey,
    Object? data,
    List<ApiFile> files = const [],
    Duration? timeout,
  }) async => dio.request<dynamic>(
    path,
    data: await _bodyOf(
      data,
      [
        for (final file in files)
          if (File(file.path).existsSync()) file,
      ],
    ),
    options: Options(
      method: method,
      headers: {idempotencyHeader: idempotencyKey},
      sendTimeout: timeout,
      receiveTimeout: timeout,
    ),
  );

''';

const _coreRegistrations = '''
    ..registerLazySingleton(() => ApiClient())
    // Opened once here: every local data source shares this instance.
    // Each feature that stores data owns its schema; add it here.
    ..registerSingleton<AppDatabase>(
      await AppDatabase.open(
        schemas: [
          processingQueueSchema,
          transactionsSchema,
          feedbackSchema,
        ],
      ),
    )
    // The same instance, seen by the repositories only as a UnitOfWork.
    ..registerSingleton<UnitOfWork>(getIt<AppDatabase>())
    // Filled by the features with what delivers each operation they
    // send through the processing queue.
    ..registerSingleton(QueueHandlerRegistry());''';

const _startQueue = '''

  // Releases the processing queue on reconnect, on resume and on a timer.
  await getIt<QueueSyncService>().start();''';

const _welcomeText = '''
        child: Text(
          context.l10n.homeWelcome,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.titleMedium,
        ),''';

const _welcomeShortcuts = '''
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              context.l10n.homeWelcome,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: () => context.pushNamed(AppRoutes.transactionsName),
              icon: const Icon(Icons.receipt_long),
              label: Text(context.l10n.transactionsTitle),
            ),
            const SizedBox(height: 12),
            FilledButton.tonalIcon(
              onPressed: () => context.pushNamed(AppRoutes.feedbackName),
              icon: const Icon(Icons.feedback_outlined),
              label: Text(context.l10n.feedbackTitle),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: () =>
                  context.pushNamed(AppRoutes.processingQueueName),
              icon: const Icon(Icons.queue),
              label: Text(context.l10n.queueTitle),
            ),
          ],
        ),''';

void _printNextSteps() {
  stdout
    ..writeln(
      '\n✓ Cola de procesamiento instalada (con transactions y feedback '
      'como ejemplos).',
    )
    ..writeln('\nSiguientes pasos:')
    ..writeln(
      '  1. Pon la URL real de tu API en AppConstants.baseUrl y revisa los '
      'endpoints de cada feature (<Feature>Endpoints).',
    )
    ..writeln(
      '  2. Para enviar una operación nueva por la cola: crea su '
      'QueueHandler en data/queue_sync/ de la feature y regístralo en el '
      'QueueHandlerRegistry desde init<Feature>Dependencies() (mira '
      'CreateFeedbackQueueHandler).',
    )
    ..writeln(
      '  3. Si la feature guarda datos locales, agrega su FeatureSchema a '
      'AppDatabase.open(...) en core/di/injection_container.dart.',
    )
    ..writeln(
      '  Las features transactions y feedback son ejemplos: bórralas con '
      '`flutter_clean_arch remove feature <nombre>` cuando no las necesites '
      '(y quita su schema de AppDatabase.open).',
    );
}
