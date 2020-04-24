import 'package:args/args.dart';

ArgResults handleParseArguments(ArgParser parser, List<String> arguments) {
  parser.addFlag(
    'pro',
    abbr: 'p',
    defaultsTo: false,
    help:
        'Activate pro mode. The output json will not include interpolated value.\nThis means the input file is treated as just each frame pose.',
  );
  parser.addFlag(
    'help',
    abbr: 'h',
    defaultsTo: false,
    negatable: false,
    help: 'Show this text.',
  );

  return parser.parse(arguments);
}
