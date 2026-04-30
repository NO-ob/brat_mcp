import 'dart:async';
import 'package:brat_mcp/dice.dart';
import 'package:brat_mcp/mcp/mcp_tool_property.dart';
import 'package:brat_mcp/mcp/mcp_tools.dart';
import 'package:brat_mcp/utils.dart';
import 'package:puppeteer/puppeteer.dart';

class ManagedPuppeteerSession {
  final String id;
  final PuppeteerSession session;
  late Timer expiryTimer;
  final Duration duration;
  final Stopwatch stopwatch = Stopwatch();
  bool keepAlive = false;
  void Function(String id) onExpiry;

  ManagedPuppeteerSession({required this.id, required this.session, required this.onExpiry, required this.duration}) {
    initTimer();
  }

  void initTimer() {
    if (keepAlive) {
      return;
    }
    expiryTimer = Timer(duration, () {
      onExpiry.call(id);
    });
    stopwatch.start();
  }

  void resetTimer() {
    expiryTimer.cancel();
    stopwatch.stop();
    stopwatch.reset();
    initTimer();
  }

  Future<void> closeSession() async {
    expiryTimer.cancel();
    stopwatch.stop();
    return session.browser?.close();
  }

  @override
  String toString() {
    return "id: $id, url: ${session.page?.url}, timeRemaining: ${((duration.inSeconds - stopwatch.elapsed.inSeconds) / 60).toStringAsFixed(1)} minutes, killTimerActive: ${expiryTimer.isActive}, headless: ${session.headless}\n";
  }
}

class PuppeteerSessionHandler {
  PuppeteerSessionHandler._();
  static final PuppeteerSessionHandler instance = PuppeteerSessionHandler._();

  final Map<String, ManagedPuppeteerSession> sessions = {};
  int counter = 0;

  Future<String> open({required PuppeteerSession session, Duration expiry = const Duration(minutes: 10)}) async {
    String id = "session_${++counter}";
    sessions[id] = ManagedPuppeteerSession(
      id: id,
      session: session,
      duration: expiry,
      onExpiry: (id) async {
        closeSession(id: id, isExpired: true);
      },
    );
    print("created browser session: $id");
    return id;
  }

  ManagedPuppeteerSession? get(String id) {
    ManagedPuppeteerSession? session = sessions[id];
    session?.resetTimer();
    return session;
  }

  Future<bool> closeSession({required String id, bool isExpired = false}) async {
    ManagedPuppeteerSession? session = sessions.remove(id);
    if (session == null) {
      return false;
    }
    await session.closeSession();
    print("$id closed, reason: ${isExpired ? "expired" : "closed"}");
    return true;
  }

  Future<void> closeAll() async {
    List<String> sessionsIds = sessions.keys.toList();
    for (String id in sessionsIds) {
      await closeSession(id: id);
    }
    print("all sessions closed");
  }
}

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
];

class PuppeteerSession {
  String executablePath;
  Until navigationWait;
  int waitMs;
  int viewportWidth;
  bool headless;
  String? userAgent;
  String? referer;

  Browser? browser;
  Page? page;

  PuppeteerSession({
    required this.executablePath,
    required this.navigationWait,
    this.waitMs = 0,
    this.viewportWidth = 1280,
    this.headless = true,
    this.userAgent,
    this.referer,
  });

  factory PuppeteerSession.fromArgs(String executablePath, List<MCPToolProperty> props, Map<String, dynamic> args) {
    String waitUntil = args['wait_until'] ?? getProperty(props, 'wait_until')?.defaultValue ?? 'networkalmostidle';
    int waitMs = Utils().getInt(key: 'wait_ms', map: args, def: getProperty(props, 'wait_ms')?.defaultValue ?? 0);
    int viewportWidth = Utils().getInt(key: 'viewport_width', map: args, def: getProperty(props, 'viewport_width')?.defaultValue ?? 1280);
    bool headless = Utils().getBool(key: 'headless', map: args, def: getProperty(props, 'headless')?.defaultValue ?? true);

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

    return PuppeteerSession(executablePath: executablePath, navigationWait: navigationWait, waitMs: waitMs, viewportWidth: viewportWidth, headless: headless);
  }

  Future<void> loadBrowser() async {
    browser = await puppeteer.launch(
      headless: headless,
      executablePath: executablePath,
      args: [
        '--no-sandbox',
        '--disable-setuid-sandbox',
        '--disable-dev-shm-usage',
        '--disable-blink-features=AutomationControlled',
        '--window-position=-10000,0',
      ],
    );

    BrowserContext context = await browser!.createIncognitoBrowserContext();

    Page loadedPage = await context.newPage();

    await loadedPage.setViewport(DeviceViewport(width: viewportWidth, height: 900));

    if (userAgent != null && userAgent!.isNotEmpty) {
      await page!.setUserAgent(userAgent!);
    }

    if (referer != null && referer!.isNotEmpty) {
      await page!.setExtraHTTPHeaders({'Referer': referer!});
    }

    page = loadedPage;
  }

  Future<Page> navigate({String? waitForSelector, required String url}) async {
    try {
      await page!.goto(url, wait: navigationWait, timeout: Duration(seconds: 10));
    } catch (e) {
      print('Navigation event never fired for $url, continuing anyway: $e');
    }

    if (waitForSelector != null && waitForSelector.isNotEmpty) {
      try {
        await page!.waitForSelector(waitForSelector, timeout: Duration(seconds: 10));
      } catch (e) {
        print('Selector "$waitForSelector" never appeared, continuing anyway: $e');
      }
    }

    if (waitMs > 0) {
      await Future.delayed(Duration(milliseconds: waitMs));
    }

    return page!;
  }

  Future<void> close() async {
    await browser?.close();
    browser = null;
    page = null;
  }
}
