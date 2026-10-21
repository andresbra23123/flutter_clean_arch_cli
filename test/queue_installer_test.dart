import 'dart:convert';
import 'dart:io';

import 'package:flutter_clean_arch/flutter_clean_arch.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

void main() {
  late TemplateGenerator generator;
  late Directory dir;
  late FlutterProject project;

  setUpAll(() async => generator = await TemplateGenerator.locate());

  const homeWelcome =
      'lib/features/home/presentation/pages/home/components/'
      'home_welcome.dart';

  String read(String relative) =>
      File(p.join(dir.path, relative)).readAsStringSync();

  setUp(() {
    dir = Directory.systemTemp.createTempSync('fca_queue_');
    writeAll(dir.path, [
      const RenderedFile(
        'pubspec.yaml',
        'name: demo_app\ndependencies:\n  flutter:\n    sdk: flutter\n',
      ),
      ...generator.render('init', {
        'package': 'demo_app',
        'todoTag': 'demo-app',
        'appTitle': 'Demo App',
      }),
    ]);
    project = FlutterProject.load(dir.path);
  });
  tearDown(() => dir.deleteSync(recursive: true));

  test('patches every base file and registers the features', () {
    applyQueueChanges(project, generator);

    expect(
      read('lib/features/processing_queue/processing_queue.dart'),
      contains('library;'),
    );
    expect(
      read('lib/core/api/api_client.dart'),
      allOf(
        contains("static const String idempotencyHeader = 'Idempotency-Key';"),
        contains('Future<Response> send('),
        contains("import 'dart:io';"),
        // The online helpers stay.
        contains('Future<Response> post('),
      ),
    );
    expect(
      read('lib/core/di/injection_container.dart'),
      allOf(
        contains('await AppDatabase.open('),
        contains('registerSingleton<UnitOfWork>(getIt<AppDatabase>())'),
        contains('registerSingleton(QueueHandlerRegistry())'),
        contains('initProcessingQueueDependencies();'),
        contains('initTransactionsDependencies();'),
        contains('initFeedbackDependencies();'),
        contains(Markers.featureInit),
      ),
    );
    expect(
      read('lib/bootstrap.dart'),
      allOf(
        contains('await getIt<QueueSyncService>().start();'),
        contains('features/processing_queue/processing_queue.dart'),
      ),
    );
    expect(
      read('lib/core/router/app_routes.dart'),
      allOf(
        contains("processingQueue = '/processing_queue'"),
        contains("transactions = '/transactions'"),
        contains("feedback = '/feedback'"),
      ),
    );
    expect(
      read('lib/core/router/app_router.dart'),
      allOf(
        contains('page: const ProcessingQueuePage()'),
        contains('page: const TransactionsPage()'),
        contains('page: const FeedbackPage()'),
      ),
    );
    expect(
      read(homeWelcome),
      contains('AppRoutes.processingQueueName'),
    );
    expect(
      read('test/helpers/helpers.dart'),
      allOf(
        contains("export 'fake_api.dart';"),
        contains("export 'test_database.dart';"),
        contains("export 'accepting_queue_handler.dart';"),
        contains("export 'pump_app.dart';"),
      ),
    );

    final es = jsonDecode(read('lib/core/l10n/arb/app_es.arb')) as Map;
    expect(es['homeTitle'], isNotNull);
    expect(es['queueTitle'], 'Cola de procesamiento');
  });

  test('works after auth (bootstrap with Firebase options)', () {
    applyAuthChanges(project, generator);
    applyQueueChanges(project, generator);

    final bootstrap = read('lib/bootstrap.dart');
    expect(
      bootstrap.indexOf('await getIt<QueueSyncService>().start();'),
      greaterThan(
        bootstrap.indexOf(
          'await initDependencies(firebaseOptions: firebaseOptions);',
        ),
      ),
    );
    expect(bootstrap, contains('await Firebase.initializeApp('));
    expect(
      read('lib/core/di/injection_container.dart'),
      allOf(
        contains('await initAuthDependencies('),
        contains('await AppDatabase.open('),
      ),
    );
  });

  test('is idempotent', () {
    applyQueueChanges(project, generator);
    final once = {
      for (final f in [
        'lib/bootstrap.dart',
        'lib/core/api/api_client.dart',
        'lib/core/di/injection_container.dart',
        'lib/core/router/app_router.dart',
        'lib/core/router/app_routes.dart',
        homeWelcome,
        'lib/core/l10n/arb/app_en.arb',
        'test/helpers/helpers.dart',
      ])
        f: read(f),
    };
    applyQueueChanges(project, generator);

    once.forEach((file, content) => expect(read(file), content, reason: file));
  });
}
