import 'package:brat_mcp/mcp/avatar/avatar_handler.dart';
import 'package:brat_mcp/mcp/mcp_response.dart';
import 'package:brat_mcp/mcp/mcp_tool.dart';
import 'package:brat_mcp/mcp/mcp_tool_property.dart';
import 'package:brat_mcp/utils.dart';

enum AvatarExpression { neutral, smug, happy, angry, horny, surprised, blush, sad, confused }

enum AvatarAnimation { idle, bounce, spin, leanLeft, leanRight, nod, shakeHead, jump }

enum CameraView { closeUp, fullBody, dutchLeft, dutchRight, medium, thighs }

enum AvatarParticles { heart, anger, sweat, star, musicNote }

enum AvatarClothing { chefHat }

enum AvatarHair { himeCut, buns, pixieCut, shortTwinTails, longTwinTails, mediumSideLocks, shortSideLocks, longSideLocks }

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
  MCPTool(
    name: 'avatar_set_clothing',
    description: 'Wear pieces of clothing, use this if there are clothes that suit a question youve been ask or an action youre doing\n',
    properties: [
      MCPToolPropertyStringList(
        name: "clothing",
        description: "The clothes to wear. available options: [${AvatarClothing.values.map((expr) => expr.name).join(",")}]",
        required: true,
      ),
    ],
    execute: (props, args) async {
      List<String> clothingStrings = Utils().getList<String>(key: "clothing", map: args, def: []);
      List<AvatarClothing> clothes = [];
      try {
        for (String item in clothingStrings) {
          AvatarClothing clothing = AvatarClothing.values.byName(item);
          clothes.add(clothing);
        }
      } catch (e, stackTrace) {
        //
      }

      try {
        if (clothes.isEmpty) {
          return MCPResponse.text('Clothes lsit is empty');
        }

        AvatarHandler.instance.setClothing(clothes);
        return MCPResponse.text('${clothes.map((elem) => elem.name).join(", ")} set');
      } catch (e, stackTrace) {
        return MCPResponse.text('Failed to parse clothes $e, $stackTrace');
      }
    },
  ),

  MCPTool(
    name: 'avatar_set_hair_style',
    description: 'Set your hair style\n',
    properties: [
      MCPToolPropertyStringList(
        name: "styles",
        description:
            "The styles to set they can be combined e.g longSideLocks and buns. available options: [${AvatarHair.values.map((expr) => expr.name).join(",")}]",
        required: true,
      ),
    ],
    execute: (props, args) async {
      List<String> hairStrings = Utils().getList<String>(key: "styles", map: args, def: []);
      List<AvatarHair> styles = [];
      try {
        for (String item in hairStrings) {
          AvatarHair style = AvatarHair.values.byName(item);
          styles.add(style);
        }
      } catch (e, stackTrace) {
        //
      }

      try {
        if (styles.isEmpty) {
          return MCPResponse.text('Styles lsit is empty');
        }

        AvatarHandler.instance.setHairStyle(styles);
        return MCPResponse.text('${styles.map((elem) => elem.name).join(", ")} set');
      } catch (e, stackTrace) {
        return MCPResponse.text('Failed to parse hair styles $e, $stackTrace');
      }
    },
  ),
  MCPTool(
    name: 'avatar_remove_clothing',
    description: 'Remove pieces of clothing\n',
    properties: [
      MCPToolPropertyStringList(
        name: "clothing",
        description: "The clothes to remove. available options: [${AvatarClothing.values.map((expr) => expr.name).join(",")}]",
        required: true,
      ),
    ],
    execute: (props, args) async {
      List<String> clothingStrings = Utils().getList<String>(key: "clothing", map: args, def: []);
      List<AvatarClothing> clothes = [];
      try {
        for (String item in clothingStrings) {
          AvatarClothing clothing = AvatarClothing.values.byName(item);
          clothes.add(clothing);
        }
      } catch (e, stackTrace) {
        //
      }

      try {
        if (clothes.isEmpty) {
          return MCPResponse.text('Clothes lsit is empty');
        }

        AvatarHandler.instance.removeClothing(clothes);
        return MCPResponse.text('${clothes.map((elem) => elem.name).join(", ")} set');
      } catch (e, stackTrace) {
        return MCPResponse.text('Failed to parse clothes $e, $stackTrace');
      }
    },
  ),
  MCPTool(
    name: 'avatar_set_hair_colour',
    description: 'Set the hair colour of your avatar\n',
    properties: [MCPToolPropertyString(name: "colour", description: "The hair colour as a hex string e.g #ff0000", required: true)],
    execute: (props, args) async {
      String? color = args['colour'];

      if (color == null || color.isEmpty) {
        return MCPResponse.text('No color provided');
      }

      try {
        AvatarHandler.instance.setHairColour(color);
        return MCPResponse.text('Hair colour set to $color');
      } catch (e, stackTrace) {
        return MCPResponse.text('Failed to set hair colour $e, $stackTrace');
      }
    },
  ),
];
