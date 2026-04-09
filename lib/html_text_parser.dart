import 'package:brat_mcp/extensions.dart';
import 'package:html/dom.dart';

class HTMLTextParser {
  final Node page;
  final StringBuffer buffer = StringBuffer();
  final String url;

  HTMLTextParser({required this.page, required this.url});

  void _walkNode(Node node) {
    if (node is Text) {
      String text = node.text.trim();
      if (text.isNotEmpty) {
        buffer.write('$text ');
      }

      return;
    }

    if (node is Element) {
      String? content = node.textContent(url);

      if (content != null) {
        buffer.write(content);
      }

      if (node.addNewLine) {
        buffer.write('\n');
      }

      if (!node.walkable) {
        return;
      }
    }

    for (Node child in node.nodes) {
      _walkNode(child);
    }
  }

  String get textContent {
    _walkNode(page);
    String content = buffer.toString();

    return content.replaceAll(RegExp(r'\s+\n'), '\n').replaceAll(RegExp(r'\n{2,}'), '\n').replaceAll(RegExp(r'\s{2,}'), ' ');
  }
}
