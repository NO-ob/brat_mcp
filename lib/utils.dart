import 'dart:io';

class Utils {
  Future<String?> whichPath(String command) async {
    if (Platform.isWindows) {
      return whichPathWindows(command);
    }

    try {
      ProcessResult result = await Process.run('which', [command]);
      if (result.exitCode == 0) {
        return (result.stdout as String).trim();
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  Future<String?> whichPathWindows(String command) async {
    try {
      return File(command).existsSync() ? command : null;
    } catch (_) {
      return null;
    }
  }

  bool getBool({required String key, required Map<String, dynamic> map, required bool def}) {
    var value = map[key];

    if (value is bool) {
      return value;
    }

    if (value is String) {
      value = bool.tryParse(value);
    }

    if (value == null) {
      return def;
    }

    return value;
  }

  int getInt({required String key, required Map<String, dynamic> map, required int def}) {
    var value = map[key];

    if (value is int) {
      return value;
    }

    if (value is String) {
      value = int.tryParse(value);
    }

    if (value == null) {
      return def;
    }

    return value;
  }

  List<T> getList<T>({required String key, required Map<String, dynamic> map, required List<T> def}) {
    var value = map[key];
    if (value is List) {
      return value.whereType<T>().toList();
    }
    return def;
  }
}
