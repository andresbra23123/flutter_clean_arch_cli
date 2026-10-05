/// Spanish, actionable messages for usage mistakes: unknown or misspelled
/// commands and options, options without their command, missing
/// subcommands. Also translates the help text that `package:args` prints.
library;

import 'dart:math';

import 'package:args/args.dart';
import 'package:args/command_runner.dart';

/// Explains the [error] thrown while running [arguments] with [runner].
String explainUsageError(
  CommandRunner<int> runner,
  List<String> arguments,
  UsageException error,
) {
  final resolved = _resolve(runner, arguments);
  final exe = runner.executableName;

  // 1. A command (or subcommand) that does not exist, also after `help`.
  if (resolved.unknown case final unknown?) {
    final names = resolved.siblings;
    final similar = _similar(unknown, names);
    final parent = resolved.path.join(' ');
    final where = parent.isEmpty ? '' : ' en `$parent`';
    final more = parent.isEmpty
        ? 'Usa `$exe --help` para ver qué hace cada uno.'
        : 'Usa `$exe help $parent <subcomando>` para ver sus opciones.';
    return [
      'No existe el comando `$unknown`$where.',
      if (similar.isNotEmpty) '¿Quisiste decir ${_list(similar)}?',
      '',
      'Comandos disponibles: ${_list(names)}.',
      more,
    ].join('\n');
  }

  final options = arguments.where((a) => a.startsWith('-')).toList();
  final leaves = _leaves(runner);

  // `help` only takes command names (`help usecase --returns`).
  if (arguments.first == 'help' && options.isNotEmpty) {
    final target = resolved.path.join(' ');
    final what =
        '`help` solo recibe nombres de comandos, no opciones como '
        '`${options.first}`.';
    if (target.isEmpty) return what;
    return '$what\nPara ver las opciones de `$target` y qué hace cada una, '
        'usa: $exe help $target';
  }

  // 2. Options but no command.
  final command = resolved.command;
  if (command == null) {
    return _missingCommand(exe, arguments, options, leaves);
  }

  final path = resolved.path.join(' ');

  // 3. A command with subcommands, but none given.
  if (command.subcommands.isNotEmpty) {
    final subs = command.subcommands.keys.toSet().toList();
    final accepting = [
      for (final s in subs)
        if (options.every((o) => _accepts(command.subcommands[s]!, o))) s,
    ];
    final which = accepting.length == 1
        ? accepting.single
        : '<${accepting.join('|')}>';
    return [
      'Falta el subcomando de `$path`: ${_list(subs)}.',
      if (options.isNotEmpty && accepting.isNotEmpty)
        'Por ejemplo: $exe $path $which … ${options.join(' ')}',
      '',
      'Usa `$exe help $path <subcomando>` para ver sus opciones.',
    ].join('\n');
  }

  // 4. An option the command does not have.
  final unknownOption = RegExp(
    'Could not find an option (?:named|or flag) "(-[^"]+)"',
  ).firstMatch(error.message)?[1];
  if (unknownOption != null) {
    final names = [
      for (final o in command.argParser.options.values) '--${o.name}',
    ];
    final similar = _similar(unknownOption, names);
    final elsewhere = [
      for (final (name, c) in leaves)
        if (name != path && _accepts(c, unknownOption)) name,
    ];
    return [
      'La opción `$unknownOption` no existe en `$path`.',
      if (similar.isNotEmpty) '¿Quisiste decir ${_list(similar)}?',
      if (similar.isEmpty && elsewhere.isNotEmpty)
        '`$unknownOption` es una opción de ${_list(elsewhere)}.',
      '',
      translateUsage(command.usage),
    ].join('\n');
  }

  // 5. Anything else: translated message plus the command's help.
  return '${translateMessage(error.message)}\n\n${translateUsage(error.usage)}';
}

String _missingCommand(
  String exe,
  List<String> arguments,
  List<String> options,
  List<(String, Command<int>)> leaves,
) {
  final first = arguments.first;
  List<String> accepting(Iterable<String> flags) => [
    for (final (name, c) in leaves)
      if (flags.every((f) => _accepts(c, f))) name,
  ];
  final forFirst = accepting([first]);
  final forAll = accepting(options);
  final allOptions = {
    for (final (_, c) in leaves)
      for (final o in c.argParser.options.values) '--${o.name}',
  }.toList();
  final similar = forFirst.isEmpty ? _similar(first, allOptions) : <String>[];

  return [
    'Falta el comando: ${forFirst.isEmpty ? '`$first` no es una opción de '
              'ningún comando.' : '`$first` es una opción de '
              '${_list(forFirst)}.'}',
    if (similar.isNotEmpty) '¿Quisiste decir ${_list(similar)}?',
    if (forAll.length == 1) ...[
      '',
      'Por ejemplo:',
      '  $exe ${forAll.single} ${arguments.join(' ')}',
    ],
    '',
    _helpLine(exe),
  ].join('\n');
}

String _helpLine(String exe) =>
    'Usa `$exe --help` para ver los comandos y `$exe help <comando>` para '
    'sus opciones.';

/// Where the command-line arguments lead in the command tree.
class _Resolved {
  _Resolved(this.path, this.command, this.unknown, this.siblings);

  /// Names of the commands found, e.g. `['remove', 'page']`.
  final List<String> path;

  /// Deepest command found, or `null` when there is none.
  final Command<int>? command;

  /// First token that should have been a command but is not one.
  final String? unknown;

  /// Valid names where [unknown] was found.
  final List<String> siblings;
}

_Resolved _resolve(CommandRunner<int> runner, List<String> arguments) {
  var tokens = arguments;
  if (tokens.isNotEmpty && tokens.first == 'help') tokens = tokens.sublist(1);
  final path = <String>[];
  Command<int>? command;
  for (var i = 0; i < tokens.length; i++) {
    final token = tokens[i];
    if (token.startsWith('-')) {
      // Skip the value of an option that takes one (`--returns Unit`).
      final option = command == null ? null : _option(command, token);
      if (option != null && !option.isFlag && !token.contains('=')) i++;
      continue;
    }
    final children = command == null ? runner.commands : command.subcommands;
    if (children.isEmpty) break; // Positional arguments of a leaf command.
    final child = children[token];
    if (child == null) {
      final names = children.values
          .where((c) => !c.hidden)
          .map((c) => c.name)
          .toSet()
          .toList();
      return _Resolved(path, command, token, names);
    }
    command = child;
    path.add(token);
  }
  return _Resolved(path, command, null, const []);
}

/// Every command without subcommands, with its full name (`remove page`).
List<(String, Command<int>)> _leaves(CommandRunner<int> runner) {
  final out = <(String, Command<int>)>[];
  void visit(String prefix, Command<int> command) {
    final name = prefix.isEmpty ? command.name : '$prefix ${command.name}';
    if (command.subcommands.isEmpty) {
      out.add((name, command));
    } else {
      for (final sub in command.subcommands.values.toSet()) {
        visit(name, sub);
      }
    }
  }

  for (final command in runner.commands.values.toSet()) {
    if (!command.hidden) visit('', command);
  }
  return out..sort((a, b) => a.$1.compareTo(b.$1));
}

Option? _option(Command<int> command, String flag) {
  final options = command.argParser.options;
  if (flag.startsWith('--')) {
    final name = flag.substring(2).split('=').first;
    return options[name] ??
        (name.startsWith('no-') ? options[name.substring(3)] : null);
  }
  final abbr = flag.substring(1);
  return options.values.where((o) => o.abbr == abbr).firstOrNull;
}

/// Whether [command] accepts the token [flag] (`--name`, `--no-name`,
/// `--name=value` or `-a`).
bool _accepts(Command<int> command, String flag) {
  final option = _option(command, flag);
  if (option == null) return false;
  final negated = flag.startsWith('--no-') && option.name != flag.substring(2);
  return !negated || (option.negatable ?? false);
}

/// Names in [candidates] that look like a typo of [input].
List<String> _similar(String input, List<String> candidates) {
  final clean = input.toLowerCase();
  final scored = [
    for (final c in candidates)
      if (_distance(clean, c.toLowerCase()) <= max(1, clean.length ~/ 3) ||
          (clean.length > 2 && c.toLowerCase().startsWith(clean)))
        c,
  ]..sort((a, b) => _distance(clean, a).compareTo(_distance(clean, b)));
  return scored.take(3).toList();
}

/// Levenshtein distance between [a] and [b].
int _distance(String a, String b) {
  var previous = List<int>.generate(b.length + 1, (i) => i);
  for (var i = 1; i <= a.length; i++) {
    final current = [i, ...List<int>.filled(b.length, 0)];
    for (var j = 1; j <= b.length; j++) {
      current[j] = [
        previous[j] + 1,
        current[j - 1] + 1,
        previous[j - 1] + (a[i - 1] == b[j - 1] ? 0 : 1),
      ].reduce(min);
    }
    previous = current;
  }
  return previous[b.length];
}

String _list(Iterable<String> names) => names.map((n) => '`$n`').join(', ');

/// Translates the help text generated by `package:args`.
String translateUsage(String text) => text
    .replaceAll('Usage: ', 'Uso: ')
    .replaceAll('Print this usage information.', 'Muestra esta ayuda.')
    .replaceAll('Global options:', 'Opciones globales:')
    .replaceAll('Available commands:', 'Comandos:')
    .replaceAll('Available subcommands:', 'Subcomandos:')
    .replaceAll('<command>', '<comando>')
    .replaceAll('<subcommand>', '<subcomando>')
    .replaceAll('[arguments]', '[argumentos]')
    .replaceAll('(defaults to on)', '(activado por defecto)')
    .replaceAll('(defaults to ', '(por defecto ')
    .replaceAll('(mandatory)', '(obligatoria)')
    .replaceAllMapped(
      RegExp(
        r'Run "(.+?) help <comando>" for more information about a command\.',
      ),
      (m) => 'Usa "${m[1]} help <comando>" para ver la ayuda de un comando.',
    )
    .replaceAllMapped(
      RegExp(r'Run "(.+?) help" to see global options\.'),
      (m) => 'Usa "${m[1]} help" para ver las opciones globales.',
    );

/// Translates the error messages of `package:args`. Messages written by
/// the commands (already in Spanish) are returned unchanged.
String translateMessage(String message) {
  final rules = <RegExp, String Function(Match)>{
    RegExp(r'Could not find an option (?:named|or flag) "(.+?)"\.'): (m) =>
        'No existe la opción ${m[1]}.',
    RegExp(r'Could not find a command named "(.+?)"\.'): (m) =>
        'No existe el comando "${m[1]}".',
    RegExp(r'Option (\S+) is mandatory\.'): (m) =>
        'Falta la opción obligatoria --${m[1]}.',
    RegExp(r'Missing argument for "(.+?)"\.'): (m) =>
        'Falta el valor de --${m[1]}.',
    RegExp(r'"(.+?)" is not an allowed value for option "(.+?)"\.'): (m) =>
        '"${m[1]}" no es un valor válido para --${m[2]}.',
    RegExp(r'Command "(.+?)" does not take any arguments\.'): (m) =>
        'El comando "${m[1]}" no recibe argumentos.',
  };
  var out = message;
  rules.forEach((pattern, replace) {
    out = out.replaceAllMapped(pattern, replace);
  });
  return out.replaceAll(
    'Did you mean one of these?',
    '¿Quisiste decir alguno de estos?',
  );
}
