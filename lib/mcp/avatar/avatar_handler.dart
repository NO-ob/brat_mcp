import 'dart:convert';

import 'package:brat_mcp/mcp/avatar/avatar_tools.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

class AvatarHandler {
  AvatarHandler._();
  static final AvatarHandler instance = AvatarHandler._();

  final List<WebSocketChannel> activeClients = [];

  void setExpression(AvatarExpression expression) async {
    for (WebSocketChannel client in activeClients) {
      client.sink.add(
        jsonEncode({
          "action": "set_expression",
          "args": {"expression": expression.name},
        }),
      );
    }
  }

  void setCamera(CameraView view) async {
    for (WebSocketChannel client in activeClients) {
      client.sink.add(
        jsonEncode({
          "action": "set_camera",
          "args": {"view": view.name},
        }),
      );
    }
  }

  void spawnParticles(AvatarParticles particles) async {
    for (WebSocketChannel client in activeClients) {
      client.sink.add(
        jsonEncode({
          "action": "spawn_particle",
          "args": {"type": particles.name},
        }),
      );
    }
  }

  void setAnimation(AvatarAnimation animation, int seconds) async {
    for (WebSocketChannel client in activeClients) {
      client.sink.add(
        jsonEncode({
          "action": "set_animation",
          "args": {"animation": animation.name, "duration": seconds},
        }),
      );
    }
  }
}
