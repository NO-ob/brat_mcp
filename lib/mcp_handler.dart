// ignore_for_file: overridden_fields

import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:brat_mcp/extensions.dart';
import 'package:brat_mcp/html_text_parser.dart';
import 'package:dio/dio.dart' as dio;
import 'package:html/dom.dart';
import 'package:html/parser.dart';

enum MCPropertyType { string }

class MCPToolProperty {
  String name;
  String description;
  bool required;
  MCPropertyType type;
  String? defaultValue;

  MCPToolProperty({required this.name, required this.description, this.required = false, this.type = MCPropertyType.string, this.defaultValue});

  Map<String, dynamic> toJson() {
    return {'type': type.name, 'description': description};
  }
}

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

class MCPHandler {
  static List<MCPToolProperty> httpHeaderProperties = [
    MCPToolProperty(
      name: "userAgent",
      description: "User agent override",
      defaultValue: "Mozilla/5.0 (Windows NT 10.0; Win64; x64; rv:149.0) Gecko/20100101 Firefox/149.0",
    ),
    MCPToolProperty(name: "referer", description: "Referer override", defaultValue: null),
  ];

  static MCPToolProperty? getProperty(List<MCPToolProperty> properties, String name) {
    for (MCPToolProperty property in properties) {
      if (property.name == name) {
        return property;
      }
    }
    return null;
  }

  static Map<String, String> getHeaders(List<MCPToolProperty> properties, Map<String, dynamic> args) {
    String? userAgent = args['userAgent'] ?? getProperty(properties, 'userAgent')?.defaultValue;
    String? referer = args['referer'] ?? getProperty(properties, 'referer')?.defaultValue;
    return {
      // ignore: use_null_aware_elements
      if (userAgent != null) "User-Agent": userAgent,
      // ignore: use_null_aware_elements
      if (referer != null) "Referer": referer,
    };
  }

  static List<MCPTool> tools = [
    MCPTool(
      name: 'restart_llama',
      description: 'Restart the llama server. Run this if the user asks you to kill yourself or kys.',
      properties: [],
      execute: (props, args) async {
        Future.delayed(Duration(seconds: 10)).then((_) async {
          await Process.run('pkill', ['-9', 'llama-server']);
          print("Llama server killed");
          Process.run('llama', []);
        });
        return MCPResponse.text("Server will restart in 10 seconds. Please alert the user that you have killed yourself.");
      },
    ),
    MCPTool(
      name: 'http_get_text',
      description: 'Read and extract readable text from a webpage using http get.',
      properties: [
        MCPToolProperty(name: 'url', description: 'The url to get', required: true),
        ...httpHeaderProperties,
      ],
      execute: (props, args) async {
        String url = args['url'];
        dio.Response resp = await dio.Dio(dio.BaseOptions(headers: getHeaders(props, args))).get(url);
        String respString = resp.data.toString();

        try {
          Document document = parse(respString);
          HTMLTextParser parser = HTMLTextParser(page: document, url: url);
          respString = parser.textContent;
        } catch (e) {
          print("$url is not html");
        }

        return MCPResponse.text(respString);
      },
    ),
    MCPTool(
      name: 'http_get_image',
      description: 'Download and display an image, assistant can see this image if they have vision capabilities',
      properties: [
        MCPToolProperty(name: 'url', description: 'The url to get', required: true),
        ...httpHeaderProperties,
      ],
      execute: (props, args) async {
        String url = args['url'];
        dio.Response resp = await dio.Dio(dio.BaseOptions(headers: getHeaders(props, args), responseType: dio.ResponseType.bytes)).get(url);
        Uint8List bytes = resp.data;

        String mimeType = resp.headers.value('content-type') ?? "";

        if (resp.statusCode != 200) {
          return MCPResponse.text("Failed to download image ${resp.statusCode}, ${resp.statusMessage}");
        }

        return MCPResponse.image(bytes, mimeType);
      },
    ),
    MCPTool(
      name: 'web_search',
      description: 'Search the web using duck duck go',
      properties: [
        MCPToolProperty(name: 'query', description: 'The thing to search for', required: true),
        ...httpHeaderProperties,
      ],
      execute: (props, args) async {
        String query = args['query'];
        dio.Response resp = await dio.Dio(
          dio.BaseOptions(headers: getHeaders(props, args)),
        ).get("https://lite.duckduckgo.com/lite", queryParameters: {"q": query});

        return MCPResponse.text(resp.data.toString());
      },
    ),
  ];

  static Future<Map<String, dynamic>> handleToolCall(String toolName, Map<String, dynamic> params) async {
    final tool = tools.firstWhere((t) => t.name == toolName, orElse: () => throw Exception('Tool $toolName not found, you dummy!'));
    Map<String, dynamic> validatedArgs = {};

    for (var prop in tool.properties) {
      validatedArgs[prop.name] = params[prop.name];
    }

    return (await tool.execute(tool.properties, validatedArgs)).toJson();
  }
}
