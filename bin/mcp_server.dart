import 'dart:convert';
import 'dart:io';
import 'package:args/args.dart';
import 'package:brat_mcp/mcp/avatar/avatar_handler.dart';
import 'package:brat_mcp/mcp/mcp_handler.dart';
import 'package:brat_mcp/puppeteer.dart';
import 'package:path/path.dart' as Path;
import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as shelf_io;
import 'package:shelf_router/shelf_router.dart';
import 'package:shelf_web_socket/shelf_web_socket.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:web_socket_channel/status.dart' as status;

Future<void> onKill() async {
  await PuppeteerSessionHandler.instance.closeAll();
  exit(0);
}

void main(List<String> arguments) async {
  ProcessSignal.sigint.watch().listen((_) => onKill());
  if (!Platform.isWindows) {
    ProcessSignal.sigterm.watch().listen((_) => onKill());
  }

  final parser = ArgParser()
    ..addOption('port', abbr: 'p', defaultsTo: '6969', help: 'The port to listen on')
    ..addOption('ip', abbr: 'i', defaultsTo: '0.0.0.0', help: 'The ip to bind to')
    ..addOption('name', abbr: 'n', defaultsTo: '💢 Brat MCP', help: 'The server name')
    ..addOption('chrome', abbr: 'c', help: 'Chrome path override for pupeteer if yours isnt detected')
    ..addOption('avatar', abbr: 'a', help: 'Path to avatar html file')
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
  final String? avatarPath = argResults['avatar'] ?? Path.join(Directory.current.path, "gemma-chan.html");

  String? avatarPageContent;

  try {
    File avatarPage = File(avatarPath!);
    avatarPageContent = avatarPage.readAsStringSync();

    if (avatarPageContent.isNotEmpty) {
      print("Avatar page loaded.");
    }
  } catch (e) {
    print("Could not load avatar from $avatarPath page disabling.");
  }

  final router = Router();
  final MCPHandler mcpHandler = MCPHandler();
  await mcpHandler.initTools(pathOverrides: {'chrome': chromePath}, enableAvatar: (avatarPageContent != null && avatarPageContent.isNotEmpty));

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

  AvatarHandler avatarHandler = AvatarHandler.instance;

  router.get(
    '/avatarSocket',
    webSocketHandler((WebSocketChannel webSocket, dynamic requestContext) {
      print('avatar connected to socket');
      avatarHandler.activeClients.add(webSocket);

      webSocket.stream.listen(
        (message) {
          for (WebSocketChannel client in avatarHandler.activeClients) {
            if (client != webSocket) {
              client.sink.add(message);
            }
          }
        },
        onDone: () {
          avatarHandler.activeClients.remove(webSocket);
        },
        onError: (error) {
          print('socket error: $error');
          avatarHandler.activeClients.remove(webSocket);
        },
      );
    }),
  );

  router.get('/avatar', (Request request) {
    if (avatarPageContent == null || avatarPageContent.isEmpty) {
      return Response.notFound('Avatar page not loaded');
    }

    return Response.ok(
      //'<!DOCTYPE html><html><body><h1>Iframe test</h1></body></html>',
      avatarPageContent,
      headers: {
        'Content-Type': 'text/html',
        'X-Frame-Options': 'ALLOWALL',
        'Content-Security-Policy': "frame-ancestors *;",
        'Access-Control-Allow-Origin': '*',
        'Cross-Origin-Resource-Policy': 'cross-origin',
        'Cross-Origin-Opener-Policy': 'unsafe-none',
        'Cross-Origin-Embedder-Policy': 'unsafe-none',
      },
    );
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
