import 'dart:convert';
import 'dart:typed_data';

enum MCPContentType {
  text,
  audio,
  image;

  String get valueKey {
    switch (this) {
      case MCPContentType.text:
        return "text";
      case MCPContentType.audio:
      case MCPContentType.image:
        return "data";
    }
  }
}

class MCPImageContent extends MCPContent {
  @override
  final Uint8List data;
  final String mimeType;

  MCPImageContent(this.data, this.mimeType) : super(data, MCPContentType.image);

  @override
  Map<String, dynamic> toJson() => {
    'type': type.name,
    type.valueKey: base64Encode(data),
    'mimeType': mimeType,
    'annotations': {
      'audience': ["assistant", "user"],
    },
  };
}

class MCPTextContent extends MCPContent {
  @override
  final String data;

  MCPTextContent(this.data) : super(data, MCPContentType.text);
}

abstract class MCPContent {
  final MCPContentType type;
  final dynamic data;

  MCPContent(this.data, this.type);

  @override
  Map<String, dynamic> toJson() => {'type': type.name, type.valueKey: data};
}
