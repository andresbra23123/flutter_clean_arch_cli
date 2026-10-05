import 'dart:async';
import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:flutter_clean_arch/flutter_clean_arch.dart';

Future<void> main(List<String> arguments) async {
  final runner = CliRunner();

  try {
    // `--help` and `help <comando>` print through `print`: translate them.
    exitCode =
        await runZoned(
          () => runner.run(arguments),
          zoneSpecification: ZoneSpecification(
            print: (self, parent, zone, line) =>
                parent.print(zone, translateUsage(line)),
          ),
        ) ??
        0;
  } on UsageException catch (e) {
    stderr.writeln(explainUsageError(runner, arguments, e));
    exitCode = 64;
  } on ProjectException catch (e) {
    stderr.writeln(e.message);
    exitCode = 1;
  }
}
