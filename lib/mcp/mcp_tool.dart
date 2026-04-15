import 'package:brat_mcp/mcp/mcp_response.dart';
import 'package:brat_mcp/mcp/mcp_tool_property.dart';
import 'package:brat_mcp/utils.dart';

class MCPTool {
  String name;
  String description;
  List<MCPToolProperty> properties;
  Future<MCPResponse> Function(List<MCPToolProperty> properties, Map<String, dynamic> args) execute;

  MCPTool({required this.name, required this.description, required this.properties, required this.execute});

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'description': description,
      'inputSchema': {
        'type': 'object',
        'properties': {for (MCPToolProperty prop in properties) prop.name: prop.toJson()},
        'required': properties.where((MCPToolProperty prop) => prop.required).map((MCPToolProperty prop) => prop.name).toList(),
      },
    };
  }
}

class ConditionalMCPTool {
  final List<String> binaries;
  final String key;
  final List<MCPTool> Function(String path) builder;

  ConditionalMCPTool({required this.binaries, required this.key, required this.builder});

  Future<List<MCPTool>> resolve({String? pathOverride}) async {
    for (String bin in pathOverride == null ? binaries : [pathOverride, ...binaries]) {
      final String? path = await Utils().whichPath(bin);

      if (path != null) {
        print("$key found at $path, loading tools");
        return builder(path);
      }
    }

    print("$key not found at $binaries, skipping");

    return [];
  }
}
