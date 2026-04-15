import 'dart:convert';
import 'dart:io';
import 'package:args/args.dart';
import 'package:brat_mcp/mcp/mcp_handler.dart';
import 'package:brat_mcp/utils.dart';
import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as shelf_io;
import 'package:shelf_router/shelf_router.dart';

void main(List<String> arguments) async {
  final parser = ArgParser()
    ..addOption('port', abbr: 'p', defaultsTo: '6969', help: 'The port to listen on')
    ..addOption('ip', abbr: 'i', defaultsTo: '0.0.0.0', help: 'The ip to bind to')
    ..addOption('name', abbr: 'n', defaultsTo: '💢 Brat MCP', help: 'The server name')
    ..addOption('chrome', abbr: 'c', help: 'Chrome path override for pupeteer if yours isnt detected')
    ..addFlag('help', abbr: 'h', negatable: false, help: 'Show usage information');

  ArgResults argResults;
  try {
    argResults = parser.parse(arguments);
  } catch (e) {
    print(e);
    return;
  }

  if (argResults['help']) {
    print("MCP Server Usage:");
    print(parser.usage);
    return;
  }

  final int port = int.parse(argResults['port']);
  final String host = argResults['ip'];
  final String name = argResults['name'];
  final String? chromePath = argResults['chrome'];

  final router = Router();
  final MCPHandler mcpHandler = MCPHandler();
  await mcpHandler.initTools(pathOverrides: {'chrome': chromePath});

  router.get('/mcp', (Request request) {
    HttpConnectionInfo? connectionInfo = request.context['shelf.io.connection_info'] as HttpConnectionInfo?;
    String ip = connectionInfo?.remoteAddress.address ?? 'Unknown Ip';

    print('Stream connected: $ip is initiating stream...');
    final endpointMsg = 'event: endpoint\ndata: /mcp\n\n';

    return Response.ok(
      endpointMsg,
      headers: {'Content-Type': 'text/event-stream', 'Cache-Control': 'no-cache', 'Connection': 'keep-alive', 'Access-Control-Allow-Origin': '*'},
    );
  });

  router.post('/mcp', (Request request) async {
    final body = await request.readAsString();
    final payload = jsonDecode(body) as Map<String, dynamic>;

    print('/mcp Called, Method: ${payload['method']} | ID: ${payload['id']}');

    final method = payload['method'];
    final Map<String, dynamic> params = (payload['params'] ?? {}).cast<String, dynamic>();
    final id = payload['id'];

    if (method == 'initialize') {
      return _jsonResponse({
        'jsonrpc': '2.0',
        'id': id,
        'result': {
          'protocolVersion': '2024-11-05',
          'capabilities': {'tools': {}},
          'serverInfo': {'name': name, 'version': '1.0.0'},
        },
      });
    }

    if (method == 'tools/list') {
      print('tools/list called');
      return _jsonResponse({
        'jsonrpc': '2.0',
        'id': id,
        'result': {'tools': mcpHandler.tools},
      });
    }

    if (method == 'tools/call') {
      final toolName = params['name'];
      final toolArgs = (params['arguments'] ?? {}) as Map<String, dynamic>;
      print('called tool: $toolName, $params');
      try {
        final result = await mcpHandler.handleToolCall(toolName, toolArgs);
        return _jsonResponse({'jsonrpc': '2.0', 'id': id, 'result': result});
      } catch (e) {
        return _jsonResponse({
          'jsonrpc': '2.0',
          'id': id,
          'error': {'code': -32603, 'message': e.toString()},
        });
      }
    }

    return _jsonResponse({'jsonrpc': '2.0', 'id': id, 'result': {}});
  });

  final handler = const Pipeline().addMiddleware(logRequests()).addMiddleware(_corsMiddleware()).addHandler(router.call);

  final server = await shelf_io.serve(handler, host, port);
  print(
    '=====================================================\n$name is Listening on Endpoint: http://$host:$port/mcp \n=====================================================\n',
  );
}

Response _jsonResponse(Map<String, dynamic> body) {
  return Response.ok(jsonEncode(body), headers: {'Content-Type': 'application/json'});
}

Middleware _corsMiddleware() {
  return (Handler inner) {
    return (Request request) async {
      if (request.method == 'OPTIONS') {
        return Response.ok(
          '',
          headers: {
            'Access-Control-Allow-Origin': '*',
            'Access-Control-Allow-Methods': 'POST, GET, OPTIONS',
            'Access-Control-Allow-Headers': 'Content-Type, Accept',
          },
        );
      }
      final response = await inner(request);
      return response.change(headers: {'Access-Control-Allow-Origin': '*'});
    };
  };
}
