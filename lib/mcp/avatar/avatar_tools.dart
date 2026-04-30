import 'package:brat_mcp/mcp/avatar/avatar_handler.dart';
import 'package:brat_mcp/mcp/mcp_response.dart';
import 'package:brat_mcp/mcp/mcp_tool.dart';
import 'package:brat_mcp/mcp/mcp_tool_property.dart';
import 'package:brat_mcp/utils.dart';

enum AvatarExpression { neutral, smug, happy, angry, horny, surprised, blush, sad, confused }

enum AvatarAnimation { idle, bounce, spin, leanLeft, leanRight, nod, shakeHead, jump }

enum CameraView { closeUp, fullBody, dutchLeft, dutchRight, medium }

enum AvatarParticles { heart, anger, sweat, star, musicNote }

List<MCPTool> avatarTools = [
  MCPTool(
    name: 'avatar_set_expression',
    description: 'Set your avatars facial expression try to use this atleast once per turn\n',
    properties: [
      MCPToolPropertyString(
        name: "expression",
        description: "The expression to display. available options: [${AvatarExpression.values.map((expr) => expr.name).join(",")}]",
        required: true,
      ),
    ],
    execute: (props, args) async {
      String? expressionString = args['expression'];

      try {
        AvatarExpression? expression = AvatarExpression.values.byName(expressionString!);

        AvatarHandler.instance.setExpression(expression);
        return MCPResponse.text('${expression.name} set');
      } catch (e, stackTrace) {
        return MCPResponse.text('Failed to parse expression $e, $stackTrace');
      }
    },
  ),
  MCPTool(
    name: 'avatar_spawn_particle',
    description: 'Spawn particles over your avatar\n',
    properties: [
      MCPToolPropertyString(
        name: "particleType",
        description: "The type of particles to spawn. available options: [${AvatarParticles.values.map((expr) => expr.name).join(",")}]",
        required: true,
      ),
      MCPToolPropertyInt(name: "amount", description: "The amount of partices", required: true, defaultValue: 1),
    ],
    execute: (props, args) async {
      String? particleString = args['particleType'];
      int particleCount = Utils().getInt(key: "amount", map: args, def: 1);

      try {
        AvatarParticles? particles = AvatarParticles.values.byName(particleString!);

        AvatarHandler.instance.spawnParticles(particles, particleCount);
        return MCPResponse.text('spawned particles: ${particles.name}');
      } catch (e, stackTrace) {
        return MCPResponse.text('Failed to parse expression $e, $stackTrace');
      }
    },
  ),
  MCPTool(
    name: 'avatar_set_camera',
    description: 'Set the camera view of your avatar\n',
    properties: [
      MCPToolPropertyString(
        name: "view",
        description: "The camera view to set. available options: [${CameraView.values.map((expr) => expr.name).join(",")}]",
        required: true,
      ),
    ],
    execute: (props, args) async {
      String? viewString = args['view'];

      try {
        CameraView? cameraView = CameraView.values.byName(viewString!);

        AvatarHandler.instance.setCamera(cameraView);
        return MCPResponse.text('${cameraView.name} view set');
      } catch (e, stackTrace) {
        return MCPResponse.text('Failed to parse expression $e, $stackTrace');
      }
    },
  ),
  MCPTool(
    name: 'avatar_set_animation',
    description: 'Set your avatars animation try to use this to be expressive\n',
    properties: [
      MCPToolPropertyString(
        name: "animation",
        description: "The animation to display. available options: [${AvatarAnimation.values.map((expr) => expr.name).join(",")}]",
        required: true,
      ),
      MCPToolPropertyInt(name: "duration", description: "The length of the animation in seconds", required: true),
    ],
    execute: (props, args) async {
      String? animationString = args['animation'];
      int seconds = Utils().getInt(key: "duration", map: args, def: 3);

      try {
        AvatarAnimation? animation = AvatarAnimation.values.byName(animationString!);

        AvatarHandler.instance.setAnimation(animation, seconds);
        return MCPResponse.text('${animation.name} set for $seconds seconds');
      } catch (e, stackTrace) {
        return MCPResponse.text('Failed to parse animation $e, $stackTrace');
      }
    },
  ),
];
