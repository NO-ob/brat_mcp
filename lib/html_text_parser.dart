import 'package:brat_mcp/extensions.dart';
import 'package:html/dom.dart';

class HTMLTextParser {
  final Node page;
  final StringBuffer buffer = StringBuffer();
  final String url;

  HTMLTextParser({required this.page, required this.url});

  void _walkNode(Node node) {
    //print("visiting: ${node.attributes}");
    if (node is Text) {
      if (node is Element) {
        //print("text is element: ${(node as Element).localName}, class='${(node as Element).className}' id='${(node as Element).id}'");
      }
      String text = node.text.trim();
      if (text.isNotEmpty) {
        buffer.write('$text ');
      }

      return;
    }

    if (node is Element) {
      //print("is element: ${node.attributes}");
      String? content = node.textContent(url);

      if (content != null) {
        //print("ggot text content: ${node.localName}, class='${node.className}' id='${node.id}'");
        buffer.write(content);
      }

      if (node.addNewLine) {
        buffer.write('\n');
      }

      if (!node.walkable) {
        //print("not walking: ${node.localName}, class='${node.className}' id='${node.id}'");
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

    return content.replaceAll(RegExp(r' +'), ' ').replaceAll(RegExp(r'\n\n+'), '\n\n').replaceAll("<bos>", "").trim();
  }
}
