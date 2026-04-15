import 'dart:async';
import 'package:brat_mcp/mcp/mcp_tool_property.dart';
import 'package:brat_mcp/mcp/mcp_tools.dart';
import 'package:brat_mcp/utils.dart';
import 'package:puppeteer/puppeteer.dart';

List<MCPToolProperty> puppeteerBaseProperties = [
  MCPToolPropertyString(name: 'url', description: 'The URL to load', required: true),
  MCPToolPropertyString(
    name: 'wait_until',
    description: 'When to consider navigation done: "load", "domcontentloaded", "networkalmostidle", "networkidle". Default: networkalmostidle',
    defaultValue: 'networkalmostidle',
  ),
  MCPToolPropertyString(
    name: 'wait_for_selector',
    description:
        'CSS selector to wait for before extracting (e.g. ".postContainer" for 4chan, "article"). '
        'Useful for JS-rendered pages where load/networkidle are unreliable.',
    required: false,
    defaultValue: null,
  ),
  MCPToolPropertyInt(
    name: 'wait_ms',
    description: 'Extra milliseconds to wait after page load before extracting (default 0)',
    required: false,
    defaultValue: 0,
  ),
  MCPToolPropertyInt(name: 'viewport_width', description: 'Browser viewport width in pixels (default 1280)', required: false, defaultValue: 1280),
  MCPToolPropertyString(name: 'userAgent', description: 'User agent override', defaultValue: null),
  MCPToolPropertyString(name: 'referer', description: 'Referer override', defaultValue: null),
];

class PuppeteerSession {
  String executablePath;
  String url;
  Until navigationWait;
  String? waitForSelector;
  int waitMs;
  int viewportWidth;
  bool headless;
  String? userAgent;
  String? referer;

  Browser? browser;
  Page? page;

  PuppeteerSession({
    required this.executablePath,
    required this.url,
    required this.navigationWait,
    this.waitForSelector,
    this.waitMs = 0,
    this.viewportWidth = 1280,
    this.headless = true,
    this.userAgent,
    this.referer,
  });

  factory PuppeteerSession.fromArgs(String executablePath, List<MCPToolProperty> props, Map<String, dynamic> args) {
    String waitUntil = args['wait_until'] ?? getProperty(props, 'wait_until')?.defaultValue ?? 'networkalmostidle';
    String? waitForSelector = args['wait_for_selector'] ?? getProperty(props, 'wait_for_selector')?.defaultValue;
    int waitMs = Utils().getInt(key: 'wait_ms', map: args, def: getProperty(props, 'wait_ms')?.defaultValue ?? 0);
    int viewportWidth = Utils().getInt(key: 'viewport_width', map: args, def: getProperty(props, 'viewport_width')?.defaultValue ?? 1280);
    String? userAgent = args['userAgent'] ?? getProperty(props, 'userAgent')?.defaultValue;
    String? referer = args['referer'] ?? getProperty(props, 'referer')?.defaultValue;

    Until navigationWait;

    switch (waitUntil) {
      case 'load':
        navigationWait = Until.load;
        break;
      case 'domcontentloaded':
        navigationWait = Until.domContentLoaded;
        break;
      case 'networkalmostidle':
        navigationWait = Until.networkAlmostIdle;
        break;
      case 'networkidle':
        navigationWait = Until.networkIdle;
        break;
      default:
        navigationWait = Until.networkAlmostIdle;
    }

    return PuppeteerSession(
      executablePath: executablePath,
      url: args['url'],
      navigationWait: navigationWait,
      waitForSelector: waitForSelector,
      waitMs: waitMs,
      viewportWidth: viewportWidth,
      headless: true,
      userAgent: userAgent,
      referer: referer,
    );
  }

  Future<Page> load() async {
    browser = await puppeteer.launch(
      headless: headless,
      executablePath: executablePath,
      args: ['--no-sandbox', '--disable-setuid-sandbox', '--disable-dev-shm-usage', '--disable-gpu'],
    );

    Page loadedPage = await browser!.newPage();
    page = loadedPage;

    await loadedPage.setViewport(DeviceViewport(width: viewportWidth, height: 900));

    if (userAgent != null && userAgent!.isNotEmpty) {
      await loadedPage.setUserAgent(userAgent!);
    }

    if (referer != null && referer!.isNotEmpty) {
      await loadedPage.setExtraHTTPHeaders({'Referer': referer!});
    }

    try {
      await loadedPage.goto(url, wait: navigationWait);
    } catch (e) {
      print('Navigation event never fired for $url, continuing anyway: $e');
    }

    if (waitForSelector != null && waitForSelector!.isNotEmpty) {
      try {
        await loadedPage.waitForSelector(waitForSelector!, timeout: Duration(seconds: 15));
      } catch (e) {
        print('Selector "$waitForSelector" never appeared, continuing anyway: $e');
      }
    }

    if (waitMs > 0) {
      await Future.delayed(Duration(milliseconds: waitMs));
    }

    return loadedPage;
  }

  Future<void> close() async {
    await browser?.close();
    browser = null;
    page = null;
  }
}
