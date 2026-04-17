import 'dart:math';

Random random = Random();

enum MathsOperation {
  add(['+'], [r'\+']),
  subtract(['-'], [r'\-']),
  multiply(['x', '*', '×'], ['x', r'\*', '×']),
  divide(['/', '÷'], ['/', '÷']);

  final List<String> symbols;

  final List<String> selectors;
  static String get instructions => values.map((op) => '${op.symbols} - ${op.name},').join("\n");

  static MathsOperation? fromString(String input) {
    for (MathsOperation operation in values) {
      if (operation.symbols.contains(input)) {
        return operation;
      }
    }
    return null;
  }

  int execute(int a, int b) {
    switch (this) {
      case MathsOperation.add:
        return a + b;
      case MathsOperation.subtract:
        return a - b;
      case MathsOperation.multiply:
        return a * b;
      case MathsOperation.divide:
        return (a / b).floor();
    }
  }

  const MathsOperation(this.symbols, this.selectors);

  @override
  String toString() {
    return name;
  }

  static String get orSelector {
    return values.map((op) => op.selectors.join("|")).join("|");
  }
}

enum DiceOperation {
  dropLowest('dl', "Drop lowest roll"),
  dropHighest('dh', "Drop highest roll"),
  keepHighest('kh', "Keep highest roll"),
  keepLowest('kl', "Keep lowest  roll"),
  explode('!', "Roll again if not below highest");

  final String symbol;
  final String description;

  static String get instructions => values.map((op) => '${op.symbol} - ${op.description}').join("\n");

  List<int> _execDropLowest(List<int> rolls, int? operand) {
    List<int> sorted = [...rolls]..sort();
    for (int i = 0; i < (operand ?? 1); i++) {
      sorted.removeAt(0);
    }
    return sorted;
  }

  List<int> _execDropHighest(List<int> rolls, int? operand) {
    List<int> sorted = [...rolls]..sort();
    for (int i = 0; i < (operand ?? 1); i++) {
      sorted.removeAt(sorted.length - 1);
    }
    return sorted;
  }

  List<int> _execKeepHighest(List<int> rolls, int? operand) {
    List<int> sorted = [...rolls]..sort();
    int count = (operand ?? 1).clamp(0, sorted.length);
    return sorted.sublist(sorted.length - count);
  }

  List<int> _execKeepLowest(List<int> rolls, int? operand) {
    List<int> sorted = [...rolls]..sort();
    int count = (operand ?? 1).clamp(0, sorted.length);
    return sorted.sublist(0, count);
  }

  List<int> execute(List<int> rolls, int? operand) {
    switch (this) {
      case DiceOperation.dropLowest:
        return _execDropLowest(rolls, operand);
      case DiceOperation.dropHighest:
        return _execDropHighest(rolls, operand);
      case DiceOperation.keepHighest:
        return _execKeepHighest(rolls, operand);
      case DiceOperation.keepLowest:
        return _execKeepLowest(rolls, operand);
      case DiceOperation.explode:
        return rolls;
    }
  }

  static DiceOperation? fromString(String input) {
    for (DiceOperation operation in values) {
      if (operation.symbol == input) {
        return operation;
      }
    }
    return null;
  }

  static String get orSelector {
    return values.map((op) => op.symbol).join("|");
  }

  const DiceOperation(this.symbol, this.description);

  @override
  String toString() {
    return name;
  }
}

class DiceRoll {
  int rolls;
  int dieSides;
  DiceOperation? operation;
  int? operand;
  List<int>? _results;

  DiceRoll({required this.rolls, required this.dieSides, this.operation, this.operand});

  int get sum => execute().fold(0, (a, b) => a + b);

  List<int> execute() {
    if (_results != null) {
      return _results!;
    }

    List<int> results = [];

    for (int i = 0; i < rolls; i++) {
      int result = random.nextInt(dieSides) + 1;
      results.add(result);
      if (operation == DiceOperation.explode && (operand == null ? dieSides == result : result == operand)) {
        i--;
      }
    }

    if (operation != null) {
      results = operation!.execute(results, operand);
    }

    _results = results;

    return results;
  }

  static DiceRoll? fromString(String input) {
    RegExp diceRegex = RegExp(r'(\d*)d(\d+)((' + DiceOperation.orSelector + r')(\d*))*');

    int? rolls = 1;
    int? dieSides;
    DiceOperation? operation;
    int? operand;

    RegExpMatch? match = diceRegex.firstMatch(input);

    if (match == null) {
      print("$input did not match");
      return null;
    }

    if (match.group(1) != null) {
      rolls = int.tryParse(match.group(1)!);
    }
    if (match.group(2) != null) {
      dieSides = int.tryParse(match.group(2)!);
    }
    if (match.group(4) != null) {
      operation = DiceOperation.fromString(match.group(4)!);
    }
    if (match.group(5) != null) {
      operand = int.tryParse(match.group(5)!);
    }

    if (rolls == null || dieSides == null) {
      print("failed to parse dice roll $input");
      return null;
    }
    return DiceRoll(rolls: rolls, dieSides: dieSides, operation: operation, operand: operand);
  }

  @override
  String toString() {
    return "DiceRoll(rolls:$rolls, sides:$dieSides, op:$operation, operand:$operand, results: ${execute()})";
  }
}

List<List<int>> parseDice(String input) {
  RegExp matchers = RegExp(
    r'(\d*d\d+[' +
        // ignore: prefer_interpolation_to_compose_strings
        DiceOperation.orSelector +
        r'\d*]*)' // dice with keep/drop
            r'|([' +
        // ignore: prefer_interpolation_to_compose_strings
        MathsOperation.orSelector +
        r'])'
            r'|(\d+)'
            r'|(\()'
            r'|(\))',
  );
  List<dynamic> diceOps = [];
  for (Match match in matchers.allMatches(input)) {
    if (match.group(1) != null) {
      //   print('dice: ${match.group(1)}');
      diceOps.add(DiceRoll.fromString(match.group(1)!));
    }

    if (match.group(2) != null) {
      MathsOperation? operation = MathsOperation.fromString(match.group(2)!);
      // print('operation: ${match.group(2)}');
      if (operation == null) {
        //   print("Failed to parse operation ${match.group(2)}");
      } else {
        diceOps.add(operation);
      }
    }
    if (match.group(3) != null) {
      //    print('number: ${match.group(3)}');
      diceOps.add(int.parse(match.group(3)!));
    }
    if (match.group(4) != null) {
      diceOps.add('(');
    }
    if (match.group(5) != null) {
      diceOps.add(')');
    }
  }

  if (diceOps.isEmpty) {
    return [];
  }

  return doExpression(diceOps);
}

List<List<int>> doExpression(List<dynamic> parts) {
  int? bracketStart;
  int? bracketEnd;

  for (int i = 0; i < parts.length; i++) {
    dynamic operation = parts[i];
    if (operation is String && operation == "(") {
      bracketStart = i;
    }
    if (operation is String && operation == ")") {
      bracketEnd = i;
      break;
    }
  }

  if (bracketEnd != null && bracketStart != null) {
    List<dynamic> slop = [...parts.sublist(0, bracketStart), ...doExpression(parts.sublist(bracketStart, bracketEnd)), ...parts.sublist(bracketEnd + 1)];
    return doExpression(slop);
  }

  List<List<int>> values = [];
  List<MathsOperation> operations = [];

  for (int i = 0; i < parts.length; i++) {
    dynamic operation = parts[i];

    if (operation is DiceRoll) {
      values.add((operation).execute());
    }

    if (operation is int) {
      values.add([operation]);
    }

    if (operation is List<int>) {
      values.add(operation);
    }

    if (operation is MathsOperation) {
      operations.add(operation);
    }
  }

  for (MathsOperation maths in operations) {
    if (values.length < 2) {
      break;
    }
    int a = values.removeAt(0).fold(0, (a, b) => a + b);
    int b = values.removeAt(0).fold(0, (a, b) => a + b);

    values = [
      [maths.execute(a, b)],
      ...values,
    ];
  }

  return values;
}
