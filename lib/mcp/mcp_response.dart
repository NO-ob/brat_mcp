import 'dart:typed_data';

import 'package:brat_mcp/mcp/mcp_content.dart';

class MCPResponse {
  final List<MCPContent> content;

  MCPResponse({required this.content});

  factory MCPResponse.text(String text) {
    return MCPResponse(content: [MCPTextContent(text)]);
  }

  factory MCPResponse.image(Uint8List bytes, String mimeType) {
    return MCPResponse(content: [MCPImageContent(bytes, mimeType)]);
  }

  Map<String, dynamic> toJson() {
    return {'content': content.map((MCPContent content) => content.toJson()).toList()};
  }
}
