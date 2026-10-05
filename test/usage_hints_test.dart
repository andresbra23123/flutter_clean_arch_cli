import 'package:args/command_runner.dart';
import 'package:flutter_clean_arch/flutter_clean_arch.dart';
import 'package:test/test.dart';

void main() {
  late CommandRunner<int> runner;

  setUp(() {
    runner = CommandRunner<int>('flutter_clean_arch', 'test')
      ..addCommand(InitCommand())
      ..addCommand(AuthCommand())
      ..addCommand(FeatureCommand())
      ..addCommand(UsecaseCommand())
      ..addCommand(ModelCommand())
      ..addCommand(RemoveCommand());
  });

  /// Runs [args] and returns the explanation of the usage error it throws.
  Future<String> explain(List<String> args) async {
    try {
      await runner.run(args);
    } on UsageException catch (e) {
      return explainUsageError(runner, args, e);
    }
    fail('`${args.join(' ')}` did not throw a UsageException');
  }

  group('options without a command', () {
    test('suggests the only command that accepts every option', () async {
      final hint = await explain(['--auth', '--force']);

      expect(hint, contains('`--auth` es una opción de `init`'));
      expect(hint, contains('flutter_clean_arch init --auth --force'));
    });

    test('lists the commands of a shared option without guessing', () async {
      final hint = await explain(['--force']);

      expect(hint, contains('`auth`, `feature`, `init`'));
      expect(hint, isNot(contains('Por ejemplo')));
    });

    test('finds options of subcommands', () async {
      expect(
        await explain(['--yes']),
        allOf(contains('`remove feature`'), contains('`remove usecase`')),
      );
    });

    test('suggests a similar option when none matches', () async {
      expect(await explain(['--auht']), contains('¿Quisiste decir `--auth`?'));
    });
  });

  test('unknown command suggests the closest one', () async {
    final hint = await explain(['usecas', 'songs', 'x']);

    expect(hint, contains('No existe el comando `usecas`.'));
    expect(hint, contains('¿Quisiste decir `usecase`?'));
  });

  test('unknown command after help suggests too', () async {
    expect(
      await explain(['help', 'usecas']),
      contains('¿Quisiste decir `usecase`?'),
    );
  });

  test('unknown subcommand suggests within its parent', () async {
    final hint = await explain(['remove', 'pag', 'songs', 'x']);

    expect(hint, contains('No existe el comando `pag` en `remove`.'));
    expect(hint, contains('`page`'));
    expect(hint, contains('help remove <subcomando>'));
  });

  test('missing subcommand lists them and keeps the options', () async {
    final hint = await explain(['remove', '--yes']);

    expect(hint, contains('Falta el subcomando de `remove`'));
    expect(hint, contains('`feature`, `page`, `bloc`, `usecase`'));
    expect(hint, contains('remove <feature|page|bloc|usecase> … --yes'));
  });

  test('misspelled option of a command suggests the right one', () async {
    final hint = await explain(['init', '--auht']);

    expect(hint, contains('La opción `--auht` no existe en `init`.'));
    expect(hint, contains('¿Quisiste decir `--auth`?'));
    expect(hint, contains('Uso: flutter_clean_arch init'));
  });

  test('option of another command says which one has it', () async {
    expect(
      await explain(['init', '--tests']),
      contains('`--tests` es una opción de `feature`'),
    );
  });

  test('help with an option explains that help takes commands', () async {
    final hint = await explain(['help', 'usecase', '--returns']);

    expect(hint, contains('`help` solo recibe nombres de comandos'));
    expect(hint, contains('flutter_clean_arch help usecase'));
  });

  test('a missing mandatory option is a usage error, not a crash', () async {
    final hint = await explain(['model', 'songs', 'song']);

    expect(hint, contains('Falta la opción obligatoria --from-json'));
    expect(hint, contains('Uso: flutter_clean_arch model'));
  });

  test('wrong arguments are reported before reading the project', () async {
    // The test runs outside a Flutter project: the usage error must win.
    final hint = await explain(['usecase', 'songs']);

    expect(hint, contains('Indica la feature y el nombre'));
    expect(hint, contains('Uso: flutter_clean_arch usecase'));
  });

  test('translateUsage and translateMessage turn args output into Spanish', () {
    expect(
      translateUsage(
        'Usage: x <command> [arguments]\n'
        '-h, --help    Print this usage information.\n'
        '(defaults to "Unit")\n'
        'Run "x help <command>" for more information about a command.',
      ),
      'Uso: x <comando> [argumentos]\n'
      '-h, --help    Muestra esta ayuda.\n'
      '(por defecto "Unit")\n'
      'Usa "x help <comando>" para ver la ayuda de un comando.',
    );
    expect(
      translateMessage('Option from-json is mandatory.'),
      'Falta la opción obligatoria --from-json.',
    );
    expect(
      translateMessage('Missing argument for "returns".'),
      'Falta el valor de --returns.',
    );
  });
}
