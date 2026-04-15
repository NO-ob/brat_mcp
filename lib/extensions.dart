import 'package:html/dom.dart';

extension NodeExtensions on Element {
  String? textContent(String url) {
    // 4chan iamges

    if (className.startsWith('postContainer ')) {
      String imageString = "";
      String messageString = "";
      String postTimeString = "";
      String nameString = "";

      Element? imageElement = querySelector('.fileThumb');
      if (imageElement != null) {
        String? href = imageElement.attributes['href'];
        if (href != null && href.isNotEmpty) {
          String link = Uri.parse(url).resolve(href).toString();
          imageString = '\nImage $link\n';
        }
      }

      Element? messageElement = querySelector('.postMessage');
      if (messageElement != null) {
        messageString = messageElement.text;
      }

      Element? postTimeElement = querySelector('.dateTime');

      if (postTimeElement != null) {
        postTimeString = postTimeElement.text;
      }

      Element? nameElement = querySelector('.name');

      if (nameElement != null) {
        nameString = nameElement.text;
      }

      return "$nameString - ${id.replaceAll("pc", "")} - $postTimeString\n$imageString\n$messageString\n\n";
    }

    if (localName == 'a') {
      String? href = attributes['href'];
      if (href != null && href.isNotEmpty) {
        String link = Uri.parse(url).resolve(href).toString();
        return '\nLink $link - $text\n';
      }
    }

    if (localName == 'img') {
      String? src = attributes['src'];
      if (src != null && src.isNotEmpty) {
        String imageUrl = Uri.parse(url).resolve(src).toString();
        return ('\nImage $imageUrl\n');
      }
    }
    return null;
  }

  bool get walkable {
    if (['script', 'style'].contains(localName)) {
      return false;
    }

    if (className.startsWith('postContainer ')) {
      return false;
    }

    if (['fileThumb', 'fileText'].contains(className)) {
      return false;
    }

    return true;
  }

  bool get addNewLine => ['p', 'div', 'section', 'article', 'br', 'li', 'ul', 'ol', 'h1', 'h2', 'h3', 'h4', 'h5', 'h6'].contains(localName);
}

extension DateTimeExtensions on DateTime {
  String get dateString {
    return "$day/$month/$year - ${hour.toString().padLeft(2)}:${minute.toString().padLeft(2)}";
  }
}
