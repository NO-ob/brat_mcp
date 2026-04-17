import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:brat_mcp/dice.dart';
import 'package:brat_mcp/extensions.dart';
import 'package:brat_mcp/html_text_parser.dart';
import 'package:brat_mcp/mcp/mcp_response.dart';
import 'package:brat_mcp/mcp/mcp_tool.dart';
import 'package:brat_mcp/mcp/mcp_tool_property.dart';
import 'package:brat_mcp/puppeteer.dart';
import 'package:brat_mcp/utils.dart';
import 'package:dio/dio.dart' as dio;
import 'package:html/dom.dart';
import 'package:html/parser.dart';
import 'package:puppeteer/puppeteer.dart';

List<MCPToolPropertyString> httpHeaderProperties = [
  MCPToolPropertyString(
    name: "userAgent",
    description: "User agent override",
    defaultValue: "Mozilla/5.0 (Windows NT 10.0; Win64; x64; rv:149.0) Gecko/20100101 Firefox/149.0",
  ),
  MCPToolPropertyString(name: "referer", description: "Referer override", defaultValue: null),
];

Map<String, String> getHeaders(List<MCPToolProperty> properties, Map<String, dynamic> args) {
  String? userAgent = args['userAgent'] ?? getProperty(properties, 'userAgent')?.defaultValue;
  String? referer = args['referer'] ?? getProperty(properties, 'referer')?.defaultValue;
  return {
    // ignore: use_null_aware_elements
    if (userAgent != null) "User-Agent": userAgent,
    // ignore: use_null_aware_elements
    if (referer != null) "Referer": referer,
  };
}

MCPToolProperty? getProperty(List<MCPToolProperty> properties, String name) {
  for (MCPToolProperty property in properties) {
    if (property.name == name) {
      return property;
    }
  }
  return null;
}

List<MCPTool> defaultTools = [
  MCPTool(
    name: 'roll_dice',
    description:
        'Roll dice using dice notation.\n'
        'Maths Ops: ${MathsOperation.instructions}\n'
        'Dice Ops: ${DiceOperation.instructions}.',
    properties: [MCPToolPropertyString(name: "roll", description: "Dice roll notiation string", required: true)],
    execute: (props, args) async {
      String roll = args['roll'];

      List<List<int>> parsed = parseDice(roll);

      return MCPResponse.text('$parsed');
    },
  ),
  MCPTool(
    name: 'random_number',
    description: 'Get a random, number, supports min and max',
    properties: [
      MCPToolPropertyInt(name: "max", description: "Max number"),
      MCPToolPropertyInt(name: "min", description: "Min number"),
    ],
    execute: (props, args) async {
      int max = (Utils().getInt(key: "max", map: args, def: 10000000)).clamp(0, 4294967296);
      int min = Utils().getInt(key: "min", map: args, def: 0).clamp(0, max);

      int rand = random.nextInt(max - min) + min;

      return MCPResponse.text('$rand');
    },
  ),
  MCPTool(
    name: 'sleep_timer',
    description:
        'Sleep for a period of time, useful to wait before continuing output or before anotehr tool call.'
        'You could use this multiple times in a turn to simulate loop.'
        'Sleeps longer than 45 seconds will fail so may need multiple calls',
    properties: [
      MCPToolPropertyInt(name: "seconds", description: "Seconds to pause for", defaultValue: 0),
      MCPToolPropertyInt(name: "milliseconds", description: "Millliseconds to pause for", defaultValue: 0),
    ],
    execute: (props, args) async {
      int seconds = Utils().getInt(key: "seconds", map: args, def: getProperty(props, "seconds")?.defaultValue ?? 0);
      int milliseconds = Utils().getInt(key: "milliseconds", map: args, def: getProperty(props, "milliseconds")?.defaultValue ?? 0);

      Duration sleepTime = Duration(seconds: seconds, milliseconds: milliseconds);

      if (sleepTime.inSeconds > 45) {
        sleepTime = Duration(seconds: 45);
      }

      await Future.delayed(sleepTime);
      return MCPResponse.text("You slept for ${sleepTime.inMilliseconds} milliseconds");
    },
  ),
  MCPTool(
    name: 'http_get_text',
    description: 'Read and extract readable text from a webpage using http get. Prefer over puppeteer_get_text',
    properties: [
      MCPToolPropertyString(name: 'url', description: 'The url to get', required: true),
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
      MCPToolPropertyString(name: 'url', description: 'The url to get', required: true),
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
    description: 'Search the web using duck duck go, useful for finding links to actual information or content',
    properties: [
      MCPToolPropertyString(name: 'query', description: 'The thing to search for', required: true),
      MCPToolPropertyInt(name: 'page', description: 'The page number inital is 0', required: false, defaultValue: 0),
      ...httpHeaderProperties,
    ],
    execute: (props, args) async {
      String query = args['query'];

      int page = Utils().getInt(key: "page", map: args, def: getProperty(props, "page")?.defaultValue ?? 0);
      dio.Response resp = await dio.Dio(
        dio.BaseOptions(headers: getHeaders(props, args)),
      ).get("https://lite.duckduckgo.com/lite", queryParameters: {"q": query, "s": page * 10});

      String respString = resp.data.toString();
      try {
        Document document = parse(respString);
        HTMLTextParser parser = HTMLTextParser(page: document, url: "https://lite.duckduckgo.com/");
        respString = parser.textContent;
      } catch (e) {
        print("${resp.realUri} is not html");
      }

      return MCPResponse.text(respString);
    },
  ),
  MCPTool(
    name: 'date_time',
    description: 'Get the current date and time in the format day/month/year - hour:minute',
    properties: [],
    execute: (props, args) async {
      return MCPResponse.text(DateTime.now().dateString);
    },
  ),
];

List<ConditionalMCPTool> conditionalTools = [
  ConditionalMCPTool(
    binaries: ['llama'],
    key: 'llama',
    builder: (String path) {
      return [
        MCPTool(
          name: 'restart_llama',
          description: 'Restart the llama server. Run this if the user asks you to kill yourself or kys.',
          properties: [],
          execute: (props, args) async {
            Future.delayed(Duration(seconds: 10)).then((_) async {
              await Process.run('pkill', ['-9', 'llama-server']);
              print("Llama server killed");
              Process.run(path, []);
            });
            return MCPResponse.text("Server will restart in 10 seconds. Please alert the user that you have killed yourself.");
          },
        ),
      ];
    },
  ),
  ConditionalMCPTool(
    binaries: ['google-chrome-stable', 'google-chrome', 'chrome', 'chromium'],
    key: "chrome",
    builder: (String path) {
      return [
        MCPTool(
          name: 'puppeteer_get_text',
          description:
              'Get text from a webpage using a headless browser. '
              'Prefer http_get_text first as its faster.',
          properties: puppeteerBaseProperties,
          execute: (List<MCPToolProperty> props, Map<String, dynamic> args) async {
            PuppeteerSession session = PuppeteerSession.fromArgs(path, props, args);

            try {
              await session.loadBrowser();
              String url = args['url'];
              Page page = await session.navigate(url: url, waitForSelector: args['wait_for_selector'] ?? getProperty(props, 'wait_for_selector')?.defaultValue);

              String html = await page.content ?? '';

              String result = html;
              try {
                Document document = parse(html);
                HTMLTextParser parser = HTMLTextParser(page: document, url: url);
                result = parser.textContent;
              } catch (e) {
                print('$url HTML parsing failed, returning raw HTML: $e');
              }

              return MCPResponse.text(result);
            } catch (e) {
              String extra = e is TimeoutException ? ' Try a different wait_until value.' : '';
              return MCPResponse.text('puppeteer_get_text failed: $e $extra');
            } finally {
              await session.close();
            }
          },
        ),
        MCPTool(
          name: 'puppeteer_screenshot',
          description:
              'Take a full-page screenshot of a webpage using a headless Chromium browser. '
              'Captures the entire scrollable page, not just the visible viewport. '
              'Returns an image the assistant can see.',
          properties: puppeteerBaseProperties,
          execute: (List<MCPToolProperty> props, Map<String, dynamic> args) async {
            PuppeteerSession session = PuppeteerSession.fromArgs(path, props, args);
            try {
              await session.loadBrowser();
              String url = args['url'];
              Page page = await session.navigate(url: url, waitForSelector: args['wait_for_selector'] ?? getProperty(props, 'wait_for_selector')?.defaultValue);

              Uint8List screenshot = await page.screenshot(fullPage: true, format: ScreenshotFormat.png);
              return MCPResponse.image(screenshot, 'image/png');
            } catch (e) {
              String extra = e is TimeoutException ? ' Try a different wait_until value.' : '';
              return MCPResponse.text('puppeteer_screenshot failed: $e$extra');
            } finally {
              await session.close();
            }
          },
        ),
        MCPTool(
          name: 'puppeteer_session_create',
          description:
              'Create a web browser session that can be controlleed through multiple steps.'
              'Use this if you want to load a page and then interact with it or navigate multiple pages',
          properties: puppeteerBaseProperties,
          execute: (List<MCPToolProperty> props, Map<String, dynamic> args) async {
            try {
              PuppeteerSession session = PuppeteerSession.fromArgs(path, props, args);
              String sessionId = await PuppeteerSessionHandler.instance.open(session: session);
              await session.loadBrowser();
              String url = args['url'];
              await session.navigate(url: url, waitForSelector: args['wait_for_selector'] ?? getProperty(props, 'wait_for_selector')?.defaultValue);

              return MCPResponse.text('session_id: $sessionId');
            } catch (e) {
              String extra = e is TimeoutException ? ' Try a different wait_until value.' : '';
              return MCPResponse.text('puppeteer_create_session failed: $e$extra');
            }
          },
        ),
        MCPTool(
          name: 'puppeteer_session_screenshot',
          description:
              'Take a full-page screenshot of a webpage of a currently running browser session. '
              'Captures the entire scrollable page, not just the visible viewport. '
              'Returns an image the assistant can see.',
          properties: [MCPToolPropertyString(name: 'session_id', description: 'The session id of the browser session', required: true)],
          execute: (List<MCPToolProperty> props, Map<String, dynamic> args) async {
            String? sessionId = args["session_id"];

            if (sessionId == null) {
              return MCPResponse.text('session id is required');
            }

            try {
              ManagedPuppeteerSession? managedSession = PuppeteerSessionHandler.instance.get(sessionId);
              if (managedSession == null) {
                return MCPResponse.text('No session found for $sessionId');
              }

              Page? page = managedSession.session.page;

              if (page == null) {
                return MCPResponse.text('No loaded page please navigate to a page');
              }

              Uint8List screenshot = await page.screenshot(fullPage: true, format: ScreenshotFormat.png);
              return MCPResponse.image(screenshot, 'image/png');
            } catch (e) {
              String extra = e is TimeoutException ? ' Try a different wait_until value.' : '';
              return MCPResponse.text('puppeteer_screenshot_session failed: $e$extra');
            }
          },
        ),
        MCPTool(
          name: 'puppeteer_session_navigate',
          description: 'Navigate to a url in the current puppeteer session.',
          properties: [
            MCPToolPropertyString(name: 'session_id', description: 'The session id of the browser session', required: true),
            ...puppeteerBaseProperties,
          ],
          execute: (List<MCPToolProperty> props, Map<String, dynamic> args) async {
            String? sessionId = args["session_id"];

            if (sessionId == null) {
              return MCPResponse.text('session id is required');
            }

            try {
              ManagedPuppeteerSession? managedSession = PuppeteerSessionHandler.instance.get(sessionId);
              if (managedSession == null) {
                return MCPResponse.text('No session found for $sessionId');
              }

              String url = args['url'];
              await managedSession.session.navigate(
                url: url,
                waitForSelector: args['wait_for_selector'] ?? getProperty(props, 'wait_for_selector')?.defaultValue,
              );

              return MCPResponse.text("Page loaded");
            } catch (e) {
              String extra = e is TimeoutException ? ' Try a different wait_until value.' : '';
              return MCPResponse.text('puppeteer_navigate_session failed: $e$extra');
            }
          },
        ),
        MCPTool(
          name: 'puppeteer_session_get_page_text',
          description: 'Get text from the currently open webpage of a puppeteer session. ',
          properties: [MCPToolPropertyString(name: 'session_id', description: 'The session id of the browser session', required: true)],
          execute: (List<MCPToolProperty> props, Map<String, dynamic> args) async {
            String? sessionId = args["session_id"];

            if (sessionId == null) {
              return MCPResponse.text('session id is required');
            }

            try {
              ManagedPuppeteerSession? managedSession = PuppeteerSessionHandler.instance.get(sessionId);
              if (managedSession == null) {
                return MCPResponse.text('No session found for $sessionId');
              }

              Page? page = managedSession.session.page;

              if (page == null) {
                return MCPResponse.text('No loaded page please navigate to a page');
              }

              String html = await page.content ?? '';

              String result = html;
              try {
                Document document = parse(html);
                HTMLTextParser parser = HTMLTextParser(page: document, url: page.url ?? '');
                result = parser.textContent;
              } catch (e) {
                print('$page.url HTML parsing failed, returning raw HTML: $e');
              }

              return MCPResponse.text(result);
            } catch (e) {
              String extra = e is TimeoutException ? ' Try a different wait_until value.' : '';
              return MCPResponse.text('puppeteer_session_get_page_text failed: $e$extra');
            }
          },
        ),
      ];
    },
  ),
];

// Worse than manual html parsing with get because it doesnt support nip
/*Map<String, MCPTool> conditionalTools = {
  "lynx": MCPTool(
    name: 'lynx_get_text',
    description: 'Read and extract readable text from a webpage using the lynx prefer this over http_get_text',
    properties: [
      MCPToolPropertyString(name: 'url', description: 'The Url to get', required: true),
      ...httpHeaderProperties,
      MCPToolPropertyBool(
        name: "include_urls",
        description:
            "Whether or not to include urls on the page of the otuput such as images or hrefs (true/false), save context by setting to false if theyre not needed",
        required: true,
        defaultValue: false,
      ),
    ],
    execute: (props, args) async {
      final String url = args['url'];
      final String? userAgent = args['userAgent'];
      final String? referer = args['referer'];
      final bool includeUrls = Utils().getBool(key: "include_urls", map: args, def: getProperty(props, "include_urls")?.defaultValue ?? false);

      final List<String> lynxArgs = ['-dump', '-assume_charset=utf-8'];

      if (userAgent != null && userAgent.isNotEmpty) {
        lynxArgs.add('-useragent=$userAgent');
      }

      if (referer != null && referer.isNotEmpty) {
        lynxArgs.add('-referer=$referer');
      }

      if (!includeUrls) {
        lynxArgs.add('-nolist');
      }

      lynxArgs.add(url);

      try {
        ProcessResult result = await Process.run('lynx', lynxArgs, stdoutEncoding: null, stderrEncoding: null);

        if (result.exitCode != 0) {
          return MCPResponse.text('lynx failed (code ${result.exitCode}): ${result.stderr}');
        }

        Uint8List bytes = Uint8List.fromList(result.stdout);

        String text = utf8.decode(bytes, allowMalformed: true);

        return MCPResponse.text(text);
      } catch (e) {
        return MCPResponse.text('Failed to run lynx: $e');
      }
    },
  ),*/
