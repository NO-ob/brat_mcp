// ignore_for_file: overridden_fields

import 'package:brat_mcp/mcp/avatar/avatar_tools.dart';
import 'package:brat_mcp/mcp/mcp_response.dart';
import 'package:brat_mcp/mcp/mcp_tool_property.dart';
import 'package:brat_mcp/mcp/mcp_tools.dart';
import 'package:brat_mcp/mcp/mcp_tool.dart';

class MCPHandler {
  List<MCPTool> tools = [...defaultTools];

  Future<void> initTools({Map<String, String?> pathOverrides = const {}, required bool enableAvatar}) async {
    for (ConditionalMCPTool conditional in conditionalTools) {
      List<MCPTool> resolved = await conditional.resolve(pathOverride: pathOverrides[conditional.key]);

      if (resolved.isNotEmpty) {
        tools.addAll(resolved);
      }
    }

    if (enableAvatar) {
      tools.addAll(avatarTools);
    }
  }

  Future<Map<String, dynamic>> handleToolCall(String toolName, Map<String, dynamic> params) async {
    MCPTool tool = tools.firstWhere((t) => t.name == toolName, orElse: () => throw Exception('Tool $toolName not found, you dummy!'));
    Map<String, dynamic> validatedArgs = {};

    for (MCPToolProperty prop in tool.properties) {
      if (prop.required && !params.containsKey(prop.name)) {
        return MCPResponse.text("Property ${prop.name} is required").toJson();
      }
      validatedArgs[prop.name] = params[prop.name];
    }

    return (await tool.execute(tool.properties, validatedArgs)).toJson();
  }
}
