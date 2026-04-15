import 'dart:io';

class Utils {
  Future<bool> isInstalled(String command) async {
    try {
      ProcessResult result = await Process.run('which', [command]);
      return result.exitCode == 0;
    } catch (_) {
      return false;
    }
  }

  Future<String?> whichPath(String command) async {
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
}
