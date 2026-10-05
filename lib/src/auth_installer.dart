/// Adds Firebase authentication (email + Google) to an initialized
/// project: the `auth` feature, its tests, and the changes it needs in the
/// base files. Shared by `init --auth` and `auth`.
library;

import 'dart:convert';
import 'dart:io';

import 'package:flutter_clean_arch/src/dependencies.dart';
import 'package:flutter_clean_arch/src/generator.dart';
import 'package:flutter_clean_arch/src/journal.dart';
import 'package:flutter_clean_arch/src/naming.dart';
import 'package:flutter_clean_arch/src/process_runner.dart';
import 'package:flutter_clean_arch/src/project.dart';
import 'package:flutter_clean_arch/src/registry.dart';

/// Runtime dependencies the auth feature needs, with the version ranges
/// its templates are tested with.
const authDependencies = [
  'firebase_core:^4.15.0',
  'firebase_auth:^6.7.0',
  'google_sign_in:^7.2.0',
];

/// Flavors created by `init`, each with its own Firebase project/app.
const authFlavors = ['development', 'staging', 'production'];

/// Installs auth in [project]. With [runPub], adds the dependencies and
/// regenerates l10n. Returns the exit code of the first failing step, or 0.
Future<int> installAuth(FlutterProject project, {required bool runPub}) async {
  applyAuthChanges(project, await TemplateGenerator.locate());

  if (runPub) {
    addDependencies(project, authDependencies);
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

  _printNextSteps(project);
  return 0;
}

/// File changes of [installAuth], without running any external command:
/// writes the auth feature and its tests, the Firebase placeholders and
/// the ARB keys, and patches the base files. Idempotent.
void applyAuthChanges(FlutterProject project, TemplateGenerator generator) {
  final vars = {
    'package': project.package,
    'todoTag': todoTagFromPackage(project.package),
    'appTitle': appTitleFromPackage(project.package),
  };
  final files = generator.render('auth', vars);
  writeAll(project.root, files);
  stdout.writeln('✓ ${files.length} archivos de auth creados.');

  _writeFirebaseStubs(project);
  _mergeArb(project, generator.render('auth_l10n', vars));
  for (final patch in _patches(project)) {
    patch.apply(project);
  }
}

/// `firebase_options_<flavor>.dart` placeholders, so the project compiles
/// before `flutterfire configure`. Existing files (real options) are kept.
void _writeFirebaseStubs(FlutterProject project) {
  for (final flavor in authFlavors) {
    final relative = 'lib/core/firebase/firebase_options_$flavor.dart';
    if (fileExists(project.path(relative))) {
      stdout.writeln('• $relative ya existe: se conserva.');
      continue;
    }
    writeText(project.path(relative), '''
// Placeholder created by `flutter_clean_arch auth`. Replace it by running:
//   flutterfire configure --out=$relative ...
// (see the "Siguientes pasos" printed by the command).

import 'package:firebase_core/firebase_core.dart';

/// Firebase options of the $flavor flavor. Not configured yet.
abstract final class DefaultFirebaseOptions {
  /// Throws until `flutterfire configure` generates the real options.
  static FirebaseOptions get currentPlatform => throw UnsupportedError(
    'Firebase is not configured for the $flavor flavor. Run '
    '`flutterfire configure --out=$relative`.',
  );
}
''');
    stdout.writeln('✓ Creado $relative (provisional).');
  }
}

/// Adds the auth keys to `app_en.arb` / `app_es.arb`, keeping the existing
/// keys and their order.
void _mergeArb(FlutterProject project, List<RenderedFile> authArbs) {
  for (final arb in authArbs) {
    final relative = 'lib/core/l10n/arb/${arb.relativePath}';
    final source = readText(project.path(relative));
    if (source == null) {
      stderr.writeln(
        '! No existe $relative: agrega a mano las claves de auth.',
      );
      continue;
    }
    final existing = jsonDecode(source) as Map<String, dynamic>;
    final additions = jsonDecode(arb.content) as Map<String, dynamic>;
    var added = 0;
    additions.forEach((key, value) {
      if (existing.containsKey(key)) return;
      existing[key] = value;
      if (!key.startsWith('@')) added++;
    });
    if (added == 0) {
      stdout.writeln('• $relative ya tenía las claves de auth.');
      continue;
    }
    writeText(
      project.path(relative),
      '${const JsonEncoder.withIndent('    ').convert(existing)}\n',
    );
    stdout.writeln('✓ $relative: $added claves de auth.');
  }
}

/// An idempotent edit of a base file.
class _Patch {
  const _Patch(
    this.relative,
    this.description, {
    required this.done,
    required this.edit,
    required this.manual,
  });

  final String relative;
  final String description;

  /// Whether the file already has the change.
  final bool Function(String source) done;

  /// The edited source, or `null` if the expected code was not found.
  final String? Function(String source) edit;

  /// What to change by hand when [edit] cannot.
  final String manual;

  void apply(FlutterProject project) {
    final path = project.path(relative);
    final source = readText(path);
    if (source == null) {
      stderr.writeln('! No existe $relative. Cambio a mano: $manual');
      return;
    }
    if (done(source)) {
      stdout.writeln('• $relative ya tenía: $description.');
      return;
    }
    final eol = source.contains('\r\n') ? '\r\n' : '\n';
    final result = edit(source.replaceAll('\r\n', '\n'));
    if (result == null) {
      stderr
        ..writeln('! No se pudo editar $relative automáticamente.')
        ..writeln('  Cambio a mano: $manual');
      return;
    }
    writeText(path, result.replaceAll('\n', eol));
    stdout.writeln('✓ $relative: $description.');
  }
}

/// Adds [imports] after the last import of [source] (sorted later by
/// `dart fix`). Skips the ones already present.
String _addImports(String source, List<String> imports) {
  final missing = imports.where((i) => !source.contains(i)).toList();
  if (missing.isEmpty) return source;
  final lines = source.split('\n');
  final last = lines.lastIndexWhere((l) => l.startsWith('import '));
  lines.insertAll(last + 1, missing);
  return lines.join('\n');
}

/// Index of the `)` that closes the `(` at [open].
int _closingParen(String source, int open) {
  var depth = 0;
  for (var i = open; i < source.length; i++) {
    if (source[i] == '(') depth++;
    if (source[i] == ')') {
      depth--;
      if (depth == 0) return i;
    }
  }
  return -1;
}

List<_Patch> _patches(FlutterProject project) {
  final pkg = project.package;
  final authImport = "import 'package:$pkg/features/auth/auth.dart';";
  final diImport = "import 'package:$pkg/core/di/di.dart';";
  const firebaseImport = "import 'package:firebase_core/firebase_core.dart';";
  const blocImport = "import 'package:flutter_bloc/flutter_bloc.dart';";

  return [
    _Patch(
      'lib/bootstrap.dart',
      'Firebase.initializeApp con las opciones del flavor',
      done: (s) => s.contains('Firebase.initializeApp'),
      edit: (s) {
        final signature = RegExp(
          r'Future<void> bootstrap\(\s*FutureOr<Widget> Function\(\) builder,?\s*\)',
        );
        if (!signature.hasMatch(s) ||
            !s.contains('await initDependencies();')) {
          return null;
        }
        return _addImports(
          s
              .replaceFirst(
                signature,
                'Future<void> bootstrap(\n'
                '  FutureOr<Widget> Function() builder, {\n'
                '  required FirebaseOptions firebaseOptions,\n'
                '})',
              )
              .replaceFirst(
                'await initDependencies();',
                _bootstrapInit,
              ),
          [firebaseImport],
        );
      },
      manual:
          'agrega el parámetro `required FirebaseOptions firebaseOptions` a '
          'bootstrap y llama a `Firebase.initializeApp(options: '
          'firebaseOptions)` antes de `initDependencies(firebaseOptions: '
          'firebaseOptions)`.',
    ),
    for (final flavor in authFlavors)
      _Patch(
        'lib/main_$flavor.dart',
        'opciones de Firebase del flavor $flavor',
        done: (s) => s.contains('firebaseOptionsFor('),
        edit: (s) {
          final call = RegExp(r'bootstrap\(\s*\(\) => const App\(\),?\s*\)');
          if (!call.hasMatch(s)) return null;
          return _addImports(
            s.replaceFirst(
              call,
              'bootstrap(\n'
              '    () => const App(),\n'
              '    firebaseOptions: firebaseOptionsFor(AppFlavor.$flavor),\n'
              '  )',
            ),
            ["import 'package:$pkg/core/firebase/firebase.dart';"],
          );
        },
        manual:
            'pasa `firebaseOptions: firebaseOptionsFor(AppFlavor.$flavor)` '
            'a bootstrap.',
      ),
    _Patch(
      'lib/core/di/injection_container.dart',
      'initAuthDependencies con las opciones de Firebase',
      done: (s) => s.contains('initAuthDependencies('),
      edit: (s) {
        const signature = 'Future<void> initDependencies() async {';
        if (!s.contains(signature) || !s.contains(Markers.featureInit)) {
          return null;
        }
        final edited = s.replaceFirst(
          signature,
          'Future<void> initDependencies({\n'
          '  required FirebaseOptions firebaseOptions,\n'
          '}) async {',
        );
        final lines = edited.split('\n');
        final marker = lines.indexWhere((l) => l.trim() == Markers.featureInit);
        lines.insert(
          marker,
          '  await initAuthDependencies(firebaseOptions: firebaseOptions);',
        );
        return _addImports(lines.join('\n'), [firebaseImport, authImport]);
      },
      manual:
          'agrega `{required FirebaseOptions firebaseOptions}` a '
          'initDependencies y llama a `await initAuthDependencies( '
          'firebaseOptions: firebaseOptions);`.',
    ),
    _Patch(
      'lib/core/router/app_routes.dart',
      'rutas de auth',
      done: (s) => s.contains('isAuthRoute('),
      edit: (s) {
        if (!s.contains(Markers.routes)) return null;
        final lines = s.split('\n');
        final marker = lines.indexWhere((l) => l.trim() == Markers.routes);
        lines.insertAll(marker, _authRouteConstants.split('\n'));
        return lines.join('\n');
      },
      manual:
          'agrega las constantes login/register/forgotPassword e '
          'isAuthRoute a AppRoutes.',
    ),
    _Patch(
      'lib/core/router/app_router.dart',
      'redirección según la sesión y rutas de auth',
      done: (s) => s.contains('_create(getIt<AuthBloc>())'),
      edit: (s) {
        final start = RegExp(
          r'static final GoRouter instance = GoRouter\(\n',
        );
        if (!start.hasMatch(s) || !s.contains(Markers.routes)) return null;
        var out = s.replaceFirst(
          start,
          '///\n'
          '  /// Created on first access, after `initDependencies()` '
          'registered the\n'
          '  /// [AuthBloc] it listens to.\n'
          '  static final GoRouter instance = _create(getIt<AuthBloc>());\n'
          '\n'
          '  static GoRouter _create(AuthBloc authBloc) => GoRouter(\n'
          '$_redirect',
        );
        final lines = out.split('\n');
        final marker = lines.indexWhere((l) => l.trim() == Markers.routes);
        lines.insertAll(marker, _authGoRoute.split('\n'));
        out = lines.join('\n');
        return _addImports(out, [diImport, authImport]);
      },
      manual:
          'crea el GoRouter con `refreshListenable: GoRouterRefreshStream( '
          'authBloc.stream)` y un `redirect` que lleve a AppRoutes.login sin '
          'sesión, y agrega la ruta de LoginPage con register y '
          'forgot-password anidadas.',
    ),
    _Patch(
      'lib/app/pages/app.dart',
      'AuthBloc disponible para toda la app',
      done: (s) => s.contains('getIt<AuthBloc>()'),
      edit: (s) {
        const call = 'MaterialApp.router(';
        final at = s.indexOf(call);
        if (at == -1) return null;
        final close = _closingParen(s, at + call.length - 1);
        if (close == -1) return null;
        final wrapped =
            '${s.substring(0, at)}'
            'BlocProvider.value(\n'
            '      // Lazy singleton owned by get_it, so BlocProvider must not '
            'close it.\n'
            '      value: getIt<AuthBloc>(),\n'
            '      child: ${s.substring(at, close + 1)},\n'
            '    )'
            '${s.substring(close + 1)}';
        return _addImports(wrapped, [diImport, authImport, blocImport]);
      },
      manual:
          'envuelve MaterialApp.router en `BlocProvider.value(value: '
          'getIt<AuthBloc>(), child: ...)`.',
    ),
    _Patch(
      'lib/features/home/presentation/pages/home/home_page.dart',
      'botón de cerrar sesión',
      done: (s) => s.contains('AuthSignOutRequested'),
      edit: (s) {
        final appBar = RegExp(
          r'AppBar\(\s*title: Text\(context\.l10n\.homeTitle\),?\s*\)',
        );
        if (!appBar.hasMatch(s)) return null;
        return _addImports(
          s.replaceFirst(appBar, _homeAppBar),
          [authImport, blocImport],
        );
      },
      manual:
          'agrega a la AppBar de HomePage un IconButton que envíe '
          '`AuthSignOutRequested` al AuthBloc.',
    ),
  ];
}

const _bootstrapInit = '''
await Firebase.initializeApp(options: firebaseOptions);
  await initDependencies(firebaseOptions: firebaseOptions);''';

const _authRouteConstants = r'''
  // ── Auth ──────────────────────────────────────────────────
  // Every auth route lives under /login: they are the only routes
  // reachable without a session (see isAuthRoute).

  /// Path of the login page.
  static const String login = '/login';

  /// Name of the login route.
  static const String loginName = 'login';

  /// Path of the sign-up page, relative to [login].
  static const String register = 'register';

  /// Name of the sign-up route.
  static const String registerName = 'register';

  /// Path of the forgot password page, relative to [login].
  static const String forgotPassword = 'forgot-password';

  /// Name of the forgot password route.
  static const String forgotPasswordName = 'forgotPassword';

  /// Whether [location] is one of the auth routes.
  static bool isAuthRoute(String location) =>
      location == login || location.startsWith('$login/');
''';

const _redirect = '''
    // Re-run redirect every time the session changes.
    refreshListenable: GoRouterRefreshStream(authBloc.stream),
    redirect: (context, state) {
      final signedIn = authBloc.state is AuthAuthenticated;
      final onAuthRoute = AppRoutes.isAuthRoute(state.matchedLocation);

      // Without a session only the auth routes are reachable.
      if (!signedIn && !onAuthRoute) return AppRoutes.login;
      // With a session the auth routes make no sense.
      if (signedIn && onAuthRoute) return AppRoutes.home;
      return null;
    },
''';

const _authGoRoute = '''
      GoRoute(
        path: AppRoutes.login,
        name: AppRoutes.loginName,
        pageBuilder: (context, state) => routerAnimation(
          page: const LoginPage(),
          animationType: RouterAnimationType.fade,
        ),
        routes: [
          GoRoute(
            path: AppRoutes.register,
            name: AppRoutes.registerName,
            pageBuilder: (context, state) => routerAnimation(
              page: const RegisterPage(),
              animationType: RouterAnimationType.slide,
            ),
          ),
          GoRoute(
            path: AppRoutes.forgotPassword,
            name: AppRoutes.forgotPasswordName,
            pageBuilder: (context, state) => routerAnimation(
              page: const ForgotPasswordPage(),
              animationType: RouterAnimationType.slide,
            ),
          ),
        ],
      ),''';

const _homeAppBar = '''
AppBar(
        title: Text(context.l10n.homeTitle),
        actions: [
          IconButton(
            tooltip: context.l10n.logoutTooltip,
            icon: const Icon(Icons.logout),
            // AppRouter redirects to login once the session ends.
            onPressed: () =>
                context.read<AuthBloc>().add(const AuthSignOutRequested()),
          ),
        ],
      )''';

/// Reads `applicationId` from `android/app/build.gradle.kts`.
String? _applicationId(FlutterProject project) {
  final gradle = File(project.path('android/app/build.gradle.kts'));
  if (!gradle.existsSync()) return null;
  return RegExp(
    r'applicationId\s*=\s*"([^"]+)"',
  ).firstMatch(gradle.readAsStringSync())?[1];
}

void _printNextSteps(FlutterProject project) {
  final id = _applicationId(project) ?? 'com.example.${project.package}';
  const suffixes = {'development': '.dev', 'staging': '.stg', 'production': ''};
  stdout
    ..writeln('\n✓ Auth instalado (email + Google).')
    ..writeln('\nSiguientes pasos:')
    ..writeln(
      '  1. Crea (o elige) un proyecto de Firebase por flavor y habilita '
      'Email/Password y Google en Authentication.',
    )
    ..writeln('  2. Genera las opciones de cada flavor con FlutterFire:');
  for (final flavor in authFlavors) {
    final appId = '$id${suffixes[flavor]}';
    stdout.writeln(
      '     flutterfire configure --yes --project=<proyecto-$flavor> '
      '--platforms=android,ios '
      '--out=lib/core/firebase/firebase_options_$flavor.dart '
      '--android-package-name=$appId --ios-bundle-id=$appId '
      '--android-out=android/app/src/$flavor/google-services.json '
      '--ios-out=ios/config/$flavor/GoogleService-Info.plist',
    );
  }
  stdout
    ..writeln(
      '  3. Android (Google Sign-In): registra los SHA-1 y SHA-256 de tu '
      'keystore en cada app de Firebase (`cd android && ./gradlew '
      'signingReport`).',
    )
    ..writeln(
      '  4. iOS (Google Sign-In): agrega `REVERSED_CLIENT_ID` de cada '
      'GoogleService-Info.plist a CFBundleURLTypes en ios/Runner/Info.plist.',
    )
    ..writeln(
      '  Hasta completar el paso 2, la app lanza un error claro al arrancar.',
    );
}
