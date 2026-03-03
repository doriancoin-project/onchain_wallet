// ignore_for_file: avoid_print

import 'dart:io';

// import 'package:on_chain_wallet/app/core.dart';

// import 'package:on_chain_wallet/app/core.dart';

const _extensionDir = "requirement/extensions/";
const _webviewDir = "requirement/webview/";
const _browserDir = "requirement/browser/";
const _wasmSetupScriptDir = "requirement/wasm.mjs";
const _dmgInstallerDir = "requirement/dmg_installer/";
const List<String> _webArgs = ["-chrome", "-firefox", "-opera", "-ie", "-web"];
const String _buildWebDir = "build/web/";

class _FileAndDirUtils {
  static void copyFiles(Directory source, Directory destination,
      {String? extension}) {
    if (!destination.existsSync()) {
      destination.createSync(recursive: true);
    }

    source.listSync(recursive: false).forEach((var entity) {
      if (entity is File) {
        if (extension != null && !entity.uri.path.endsWith(extension)) return;
        final newFile =
            File('${destination.path}/${entity.uri.pathSegments.last}');
        newFile.writeAsBytesSync(entity.readAsBytesSync());
      }
    });
  }

  static void copyDirectory(Directory source, Directory destination) {
    if (!destination.existsSync()) {
      destination.createSync(recursive: true);
    }

    source.listSync(recursive: false).forEach((var entity) {
      if (entity is Directory) {
        final uri = Uri.parse(entity.path);
        final newDirectory = Directory(
          '${destination.path}/${uri.pathSegments.last}',
        );
        _FileAndDirUtils.copyDirectory(entity, newDirectory);
      } else if (entity is File) {
        final newFile = File(
          '${destination.path}/${entity.uri.pathSegments.last}',
        );
        newFile.writeAsBytesSync(entity.readAsBytesSync());
      }
    });
  }
}

class _ExtensionAndWebScriptsBuilder {
  static void copyWebFiles() {
    final r = Directory("web");
    if (r.existsSync()) {
      r.deleteSync(recursive: true);
    }
    r.createSync(recursive: true);
    final browserFiles = Directory(_browserDir);
    _FileAndDirUtils.copyDirectory(browserFiles, r);
  }

  static bool hasWebScripts() {
    if (!Directory(_browserDir).existsSync()) return false;
    return File("${_browserDir}index.html").existsSync() &&
        File("${_browserDir}manifest.json").existsSync() &&
        File("${_browserDir}style.css").existsSync();
  }

  static void cleanUpBuildFolder() {
    if (!Directory(_buildWebDir).existsSync()) return;
    File file = File("${_buildWebDir}tron_web.js");
    if (file.existsSync()) {
      file.deleteSync();
    }
    file = File("${_buildWebDir}content.js");
    if (file.existsSync()) {
      file.deleteSync();
    }
    file = File("${_buildWebDir}background.js");
    if (file.existsSync()) {
      file.deleteSync();
    }
    file = File("${_buildWebDir}page.js");
    if (file.existsSync()) {
      file.deleteSync();
    }
    file = File("${_buildWebDir}index.html");
    if (file.existsSync()) {
      file.deleteSync();
    }
    file = File("${_buildWebDir}side_panel.html");
    if (file.existsSync()) {
      file.deleteSync();
    }
    file = File("${_buildWebDir}iframe.html");
    if (file.existsSync()) {
      file.deleteSync();
    }
    file = File("${_buildWebDir}iframe_events.js");
    if (file.existsSync()) {
      file.deleteSync();
    }
    _log("build folder cleaned");
  }

  static bool hasExtensionScripts() {
    if (!Directory(_extensionDir).existsSync()) return false;
    return File("${_extensionDir}chrome_manifest.json").existsSync() &&
        File("${_extensionDir}content.js").existsSync() &&
        File("${_extensionDir}firefox_content.js").existsSync() &&
        File("${_extensionDir}iframe.html").existsSync() &&
        File("${_extensionDir}iframe_events.js").existsSync() &&
        File("${_extensionDir}index.html").existsSync() &&
        File("${_extensionDir}mozila_manifest.json").existsSync() &&
        File("${_extensionDir}opera_manifest.json").existsSync() &&
        File("${_extensionDir}page.js").existsSync() &&
        File("${_extensionDir}side_panel.html").existsSync() &&
        File("${_extensionDir}style.css").existsSync() &&
        File("${_extensionDir}tron_web.js").existsSync();
  }

  static Future<void> buildContent(
      {bool minify = false, bool isMozila = false}) async {
    _log(
      "Building content ${isMozila ? 'Mozila extension' : 'chrome based extension'}. please wait...",
    );
    final String out = isMozila
        ? "${_extensionDir}firefox_content.js"
        : "${_extensionDir}content.js";
    const String command = 'dart';
    final List<String> args = [
      'compile',
      'js',
      "--no-source-maps",
      if (minify) '-m',
      '-o',
      out,
      'js/content.dart',
      "--no-source-maps",
    ];

    await _FlutterCommands.doProcess(command, args);
    File file = File(out);
    if (isMozila) {
      String data = file.readAsStringSync();
      if (minify) {
        assert(
          data.contains("(function dartProgram(){"),
          "unknow mozila content file",
        );
        data = data.replaceFirst(
          "(function dartProgram(){",
          r'''(function dartProgram(){if(self.browser === undefined){self.browser = browser;self.cloneInto = cloneInto; self.Uint8Array = Uint8Array;}''',
        );
      } else {
        assert(data.contains("main() {"), "unknow mozila content file");
        data = data.replaceFirst("main() {", r'''    main() {
      if(self.browser === undefined){
        self.browser = browser
        self.cloneInto = cloneInto
        self.Uint8Array = Uint8Array;
      }''');
      }
      await file.writeAsString(data);
    }
    file = File("$out.deps");
    if (file.existsSync()) file.deleteSync(recursive: true);
  }

  static Future<void> buildBackground({bool minify = false}) async {
    _log("Building background. please wait...");
    const String command = 'dart';
    final List<String> args = [
      'compile',
      'js',
      "--no-source-maps",
      if (minify) '-m',
      '-o',
      '${_extensionDir}background.js',
      'js/background/background.dart',
      "--no-source-maps",
    ];

    await _FlutterCommands.doProcess(command, args);
    File file = File("${_extensionDir}background.js.deps");
    if (file.existsSync()) file.deleteSync();
  }

  static Future<void> buildPage({bool minify = false}) async {
    _log("Building page. please wait...");
    const String command = 'dart';
    final List<String> args = [
      'compile',
      'js',
      "--no-source-maps",
      if (minify) '-m',
      '-o',
      '${_extensionDir}page.js',
      'js/page.dart',
    ];

    await _FlutterCommands.doProcess(command, args);
    File file = File("${_extensionDir}page.js.deps");
    if (file.existsSync()) file.deleteSync(recursive: true);
  }

  static bool hasHttp() {
    if (!Directory("assets/wasm/").existsSync()) return false;
    return File("assets/wasm/http.js").existsSync();
  }

  static Future<void> buildHttpJs({bool minify = true}) async {
    _log("Building JS web http. please wait...");
    const String command = 'dart';
    final List<String> args = [
      'compile',
      'js',
      if (minify) '-m',
      '-o',
      'assets/wasm/http.js',
      'web_http/http.dart',
      "--no-source-maps",
    ];
    await _FlutterCommands.doProcess(command, args);
    if (File("assets/wasm/http.js.map").existsSync()) {
      File("assets/wasm/http.js.map").deleteSync();
    }
    if (File("assets/wasm/http.js.deps").existsSync()) {
      File("assets/wasm/http.js.deps").deleteSync();
    }
  }

  static bool hasValidCryptoAssets(bool isExtension) {
    if (!Directory("assets/wasm/").existsSync()) return false;
    final hasWasm = File("assets/wasm/crypto.wasm").existsSync() &&
        File("assets/wasm/stream_crypto.wasm").existsSync() &&
        File("assets/wasm/crypto.mjs").existsSync() &&
        File("assets/wasm/crypto.support.js").existsSync() &&
        File("assets/wasm/stream_crypto.mjs").existsSync() &&
        File("assets/wasm/stream_crypto.support.js").existsSync() &&
        File("assets/wasm/stream_crypto.mjs").existsSync();
    final hasJs = File("assets/wasm/crypto.js").existsSync() &&
        File("assets/wasm/stream_crypto.js").existsSync();
    if (isExtension) {
      return hasWasm;
    }
    return hasJs && hasWasm;
  }

  static Future<void> buildCrypto() async {
    _log("Building WASM web crypto. please wait...");
    const String command = 'dart';
    final List<String> args = [
      'compile',
      'wasm',
      '-o',
      'assets/wasm/crypto.wasm',
      'web_crypto/crypto.dart',
    ];
    await _FlutterCommands.doProcess(command, args);
    if (File("assets/wasm/crypto.wasm.map").existsSync()) {
      File("assets/wasm/crypto.wasm.map").deleteSync();
    }
    if (File("assets/wasm/crypto.unopt.wasm.map").existsSync()) {
      File("assets/wasm/crypto.unopt.wasm.map").deleteSync();
    }
    if (File("assets/wasm/crypto.unopt.wasm").existsSync()) {
      File("assets/wasm/crypto.unopt.wasm").deleteSync();
    }
  }

  static Future<void> buildCryptoJs({bool minify = true}) async {
    _log("Building JS web crypto $minify. please wait...");
    const String command = 'dart';
    final List<String> args = [
      'compile',
      'js',
      if (minify) '-m',
      '-o',
      'assets/wasm/crypto.js',
      'web_crypto/crypto.dart',
      "--no-source-maps",
    ];
    await _FlutterCommands.doProcess(command, args);
    if (File("assets/wasm/crypto.js.deps").existsSync()) {
      File("assets/wasm/crypto.js.deps").deleteSync();
    }
  }

  static Future<void> buildStreamCryptoJs({bool minify = true}) async {
    _log("Building JS stream crypto. please wait...");
    const String command = 'dart';
    final List<String> args = [
      'compile',
      'js',
      if (minify) '-m',
      '-o',
      'assets/wasm/stream_crypto.js',
      'web_crypto/stream_crypto.dart',
      "--no-source-maps",
    ];
    await _FlutterCommands.doProcess(command, args);
    if (File("assets/wasm/stream_crypto.js.deps").existsSync()) {
      File("assets/wasm/stream_crypto.js.deps").deleteSync();
    }
  }

  static Future<void> buildStreamCrypto() async {
    _log("Building WASM stream crypto. please wait...");
    const String command = 'dart';
    final List<String> args = [
      'compile',
      'wasm',
      '-o',
      'assets/wasm/stream_crypto.wasm',
      'web_crypto/stream_crypto.dart',
    ];
    await _FlutterCommands.doProcess(command, args);
    if (File("assets/wasm/stream_crypto.wasm.map").existsSync()) {
      File("assets/wasm/stream_crypto.wasm.map").deleteSync();
    }
    if (File("assets/wasm/stream_crypto.unopt.wasm.map").existsSync()) {
      File("assets/wasm/stream_crypto.unopt.wasm.map").deleteSync();
    }
    if (File("assets/wasm/stream_crypto.unopt.wasm").existsSync()) {
      File("assets/wasm/stream_crypto.unopt.wasm").deleteSync();
    }
  }

  static Future<void> buildWebOrExtensions(
    List<String> commands, {
    String? releaseLocation = "release/",
  }) async {
    final bool chrome = commands.contains("-chrome");
    final bool firefox = commands.contains("-firefox");
    final bool opera = commands.contains("-opera");
    final bool ie = commands.contains("-ie");
    final bool minify = !commands.contains("--debug");
    final bool clean = commands.contains("--clean") || commands.contains("--c");
    final bool wasm = commands.contains("--wasm") || commands.contains("--w");
    final bool crypto = !commands.contains("--no-crypto");
    final bool http = !commands.contains("--no-http");
    final bool scripts = !commands.contains("--no-scripts");
    final bool extension = chrome | firefox | opera | ie;
    bool compileApp = !commands.contains("--no-app");
    final bool page = commands.contains("--script-page");
    final bool content = commands.contains("--script-content");
    final bool background = commands.contains("--script-background");
    final bool isScriptPart = page || content || background;
    // final String baseHref = "--base-href=/onchain_wallet/";
    final String baseHref = "--base-href=/";
    if (clean) {
      await _FlutterCommands.clean();
    }
    if (Directory("assets/webview/").existsSync()) {
      Directory("assets/webview/").deleteSync(recursive: true);
    }
    Directory("assets/webview/").createSync(recursive: true);
    Directory("assets/wasm/").createSync(recursive: true);
    if (crypto) {
      await buildStreamCryptoJs(minify: minify);
      await buildCryptoJs(minify: minify);
      await buildStreamCrypto();
      await buildCrypto();
    }
    if (http) {
      await buildHttpJs(minify: minify);
    }
    if (extension && scripts) {
      if (!isScriptPart) {
        await buildBackground(minify: minify);
        await buildPage(minify: minify);
        await buildContent(minify: minify);
        await buildContent(minify: minify, isMozila: true);
      }
      if (page) {
        await buildPage(minify: minify);
      }
      if (background) {
        await buildBackground(minify: minify);
      }
      if (content) {
        await buildContent(minify: minify);
        await buildContent(minify: minify, isMozila: true);
      }
    }
    if (!hasValidCryptoAssets(extension)) {
      _error(
          "missing some crypto files.${!crypto ? 'please avoid using --no-crypto' : ''}");
      return;
    }
    if (!hasWebScripts()) {
      _error("some script missing.");
      return;
    }
    if (!hasHttp()) {
      _error(
          "missing http script files.${!http ? 'please avoid using --no-http' : ''}");
      return;
    }
    if (extension && !hasExtensionScripts()) {
      _error(
          "missing some extension script files. ${!scripts ? 'please avoid using --no-scripts' : ''}");
      return;
    }
    if (!extension && wasm) {
      _log("compile web with wasm does not work in safari browser.");
    }

    _log("come build Extension: $extension Mozila: $firefox Minify: $minify");
    cleanUpBuildFolder();
    copyWebFiles();
    File file = File("requirement/wasm.mjs");
    file.copySync("assets/wasm/wasm.mjs");
    if (extension) {
      File file = File("${_extensionDir}tron_web.js");
      file.copySync("web/tron_web.js");

      file = File("${_extensionDir}background.js");
      file.copySync("web/background.js");
      file = File("${_extensionDir}page.js");
      file.copySync("web/page.js");
      file = File("${_extensionDir}index.html");
      file.copySync("web/index.html");
      if (!firefox) {
        file = File("${_extensionDir}content.js");
        file.copySync("web/content.js");
      }
      if (chrome || ie) {
        file = File("${_extensionDir}chrome_manifest.json");
        file.copySync("web/manifest.json");
        file = File("${_extensionDir}side_panel.html");
        file.copySync("web/side_panel.html");
      }
      if (opera) {
        file = File("${_extensionDir}opera_manifest.json");
        file.copySync("web/manifest.json");
        file = File("${_extensionDir}side_panel.html");
        file.copySync("web/side_panel.html");
      }
      if (firefox) {
        file = File("${_extensionDir}firefox_content.js");
        file.copySync("web/content.js");
        file = File("${_extensionDir}side_panel.html");
        file.copySync("web/side_panel.html");
        file = File("${_extensionDir}iframe.html");
        file.copySync("web/iframe.html");
        file = File("${_extensionDir}iframe_events.js");
        file.copySync("web/iframe_events.js");
        file = File("${_extensionDir}mozila_manifest.json");
        file.copySync("web/manifest.json");
      }
    }
    if (compileApp) {
      const String command = 'flutter';
      final List<String> args = [
        'build',
        'web',
        if (wasm) '--wasm',
        if (!minify) '--debug' else '--release',
        if (extension) '--csp',
        "--no-web-resources-cdn",
        if (!extension) baseHref,
      ];
      await _FlutterCommands.doProcess(command, args,
          shell: Platform.isWindows);
      if (extension) {
        const canvasUri =
            r"https://www\.gstatic\.com/flutter-canvaskit/([a-f0-9]+)/";
        final file = File("${_buildWebDir}main.dart.js");
        String data = await file.readAsString();
        final regex = RegExp(canvasUri);
        final match = regex.firstMatch(data);
        if (match != null && match.groupCount == 1) {
          final part = match.group(0);
          if (part != null) {
            data = data.replaceFirst(part, "/canvaskit/");
            await file.writeAsString(data);
            _log("canvaskit replaced $part");
          }
        }
      }
    }

    if (releaseLocation != null) {
      if (chrome) {
        final chromeDir = Directory("${releaseLocation}chrome/");
        if (chromeDir.existsSync()) {
          chromeDir.deleteSync(recursive: true);
        }
        chromeDir.createSync(recursive: true);
        _FileAndDirUtils.copyDirectory(Directory(_buildWebDir), chromeDir);
        _log("chrome extension release copied to ${chromeDir.absolute.path}");
      }
      if (firefox) {
        final firefixDir = Directory("${releaseLocation}firefox/");
        if (firefixDir.existsSync()) {
          firefixDir.deleteSync(recursive: true);
        }
        firefixDir.createSync(recursive: true);
        _FileAndDirUtils.copyDirectory(Directory(_buildWebDir), firefixDir);
        _log("firefix extension release copied to ${firefixDir.absolute.path}");
      }
      if (opera) {
        final operaDir = Directory("${releaseLocation}opera/");
        if (operaDir.existsSync()) {
          operaDir.deleteSync(recursive: true);
        }
        operaDir.createSync(recursive: true);
        _FileAndDirUtils.copyDirectory(Directory(_buildWebDir), operaDir);
        _log("firefix extension release copied to ${operaDir.absolute.path}");
      }
      if (ie) {
        final ieDir = Directory("${releaseLocation}internet_explorer/");
        if (ieDir.existsSync()) {
          ieDir.deleteSync(recursive: true);
        }
        ieDir.createSync(recursive: true);
        _FileAndDirUtils.copyDirectory(Directory(_buildWebDir), ieDir);
        _log("firefix extension release copied to ${ieDir.absolute.path}");
      }
      if (!extension) {
        final webDir = Directory("${releaseLocation}web/");
        if (webDir.existsSync()) {
          webDir.deleteSync(recursive: true);
        }
        webDir.createSync(recursive: true);
        _FileAndDirUtils.copyDirectory(Directory(_buildWebDir), webDir);
        _log("firefix extension release copied to ${webDir.absolute.path}");
      }
    }
  }
}

class _IoWebViewScriptsBuilder {
  static bool hasWebViewScripts({bool useWebviewWorker = true}) {
    if (!Directory("assets/webview").existsSync()) return false;
    if (!useWebviewWorker) {
      return File("assets/webview/script_page.js").existsSync();
    }
    return File("assets/webview/script_page.js").existsSync() &&
        File("assets/webview/script.js").existsSync();
  }

  static Future<void> buildWebView({bool minify = false}) async {
    _log("Building webview script. please wait...");
    const String command = 'dart';
    final List<String> args = [
      'compile',
      'js',
      "--no-source-maps",
      if (minify) '-m',
      '-o',
      'assets/webview/script.js',
      'js/webview.dart',
    ];
    await _FlutterCommands.doProcess(command, args);
    File file = File("assets/webview/script.js.deps");
    file.deleteSync(recursive: true);
    file = File("assets/webview/script.js");
    if (File(
            "/Users/macbookpro/Documents/projects/onchain_web3_js_examples/public/webview.js")
        .existsSync()) {
      file.copySync(
        r'/Users/macbookpro/Documents/projects/onchain_web3_js_examples/public/webview.js',
      );
    }
  }

  static Future<void> buildWebViewPage(
      {bool minify = false, bool worker = true}) async {
    _log(
      "Building webview page script ${worker ? 'worker' : 'main'}. please wait...",
    );
    const String command = 'dart';
    final List<String> args = [
      'compile',
      'js',
      "--no-source-maps",
      if (minify) '-m',
      '-o',
      'assets/webview/script_page.js',
      if (worker) 'js/webview_page.dart' else 'js/webview_page_main.dart',
    ];
    await _FlutterCommands.doProcess(command, args);
    File file = File("assets/webview/script_page.js.deps");
    file.deleteSync(recursive: true);
    file = File("assets/webview/script_page.js");
    if (File(
            r'/Users/macbookpro/Documents/projects/onchain_web3_js_examples/public/webview_page.js')
        .existsSync()) {
      file.copySync(
        r'/Users/macbookpro/Documents/projects/onchain_web3_js_examples/public/webview_page.js',
      );
    }
  }
}

class _FlutterCommands {
  static Future<void> doProcess(
    String command,
    List<String> args, {
    bool shell = false,
  }) async {
    final process = await Process.start(command, args, runInShell: shell);
    await stdout.addStream(process.stdout);
    await stderr.addStream(process.stderr);
    final result = await process.exitCode;
    // print(process.s)
    _log("${[command, ...args].join(" ")} done with exit code $result");
    if (result != 0) {
      _error("process failed with exit code $result");
      throw Exception("process failed with exit code $result");
    }
  }

  static Future<void> clean() async {
    const String command = 'flutter';
    List<String> args = ['clean'];
    await doProcess(command, args, shell: Platform.isWindows);
    args = ["pub", "get"];
    await doProcess(command, args, shell: Platform.isWindows);
  }
}

bool _isWalletContext() {
  File file = File("pubspec.yaml");
  if (!file.existsSync()) return false;
  if (!Directory(_extensionDir).existsSync()) return false;
  if (!Directory(_browserDir).existsSync()) return false;
  if (!File(_wasmSetupScriptDir).existsSync()) return false;
  if (!Directory("web_crypto").existsSync()) return false;
  if (!Directory("web_http").existsSync()) return false;
  file = File("pubspec.yaml");
  final lines = file.readAsLinesSync();
  if (lines.isEmpty) return false;
  if (lines.first.startsWith("name: on_chain_wallet")) return true;
  return false;
}

Future<void> _buildApk(
  List<String> commands, {
  String? releaseLocation = "release/",
}) async {
  if (Directory("assets/wasm/").existsSync()) {
    Directory("assets/wasm/").deleteSync(recursive: true);
  }
  Directory("assets/wasm/").createSync();
  final bool minify = !commands.contains("--debug");
  final bool splitPerAbi = commands.contains("--split-per-abi");
  final bool webview = !commands.contains("--no-webview");
  final bool useWorker = !commands.contains("--no-webview-worker");
  File file = File("$_webviewDir/tron_web.js");
  file.copySync("assets/webview/tron_web.js");
  if (webview) {
    await _IoWebViewScriptsBuilder.buildWebView(minify: minify);
    await _IoWebViewScriptsBuilder.buildWebViewPage(
        minify: minify, worker: useWorker);
  }
  if (!_IoWebViewScriptsBuilder.hasWebViewScripts(
      useWebviewWorker: useWorker)) {
    _error(
        "missing some webview script files. ${!webview ? 'please avoid using --no-webview' : ''}");
    return;
  }

  const String command = 'flutter';
  final List<String> args = [
    'build',
    'apk',
    if (!minify) '--debug' else '--release',
    if (splitPerAbi) "--split-per-abi"
  ];
  await _FlutterCommands.doProcess(command, args, shell: Platform.isWindows);
  if (releaseLocation != null) {
    if (minify) {
      final outDir = Directory("build/app/outputs/apk/release/");
      if (outDir.existsSync()) {
        final dest = Directory("$releaseLocation/apk/release");
        dest.createSync(recursive: true);
        _FileAndDirUtils.copyFiles(outDir, dest, extension: "apk");
        _log("android profile build files copied to ${dest.absolute.path}");
      }
    } else {
      final outDir = Directory("build/app/outputs/apk/debug/");
      if (outDir.existsSync()) {
        final dest = Directory("$releaseLocation/apk/debug");
        dest.createSync(recursive: true);
        _FileAndDirUtils.copyFiles(outDir, dest, extension: "apk");
        _log("android debug build files copied to ${dest.absolute.path}");
      }
    }
  }
}

Future<void> _buildMacos(
  List<String> commands, {
  String? releaseLocation = "release/",
}) async {
  if (!Platform.isMacOS) {
    _error('This build targets macOS and must be run on a macOS device.');
    return;
  }
  final bool webview = !commands.contains("--no-webview");
  if (Directory("assets/wasm/").existsSync()) {
    Directory("assets/wasm/").deleteSync(recursive: true);
  }
  Directory("assets/wasm/").createSync();
  final bool minify = !commands.contains("--debug");

  final bool useWorker = !commands.contains("--no-webview-worker");
  File file = File("$_webviewDir/tron_web.js");
  file.copySync("assets/webview/tron_web.js");
  if (webview) {
    await _IoWebViewScriptsBuilder.buildWebView(minify: minify);
    await _IoWebViewScriptsBuilder.buildWebViewPage(
        minify: minify, worker: useWorker);
  }
  if (!_IoWebViewScriptsBuilder.hasWebViewScripts(
      useWebviewWorker: useWorker)) {
    _error(
        "missing some webview script files. ${!webview ? 'please avoid using --no-webview' : ''}");
    return;
  }

  String command = 'flutter';
  List<String> args = [
    'build',
    'macos',
    if (!minify) '--debug' else '--release'
  ];
  await _FlutterCommands.doProcess(command, args, shell: Platform.isWindows);
  if (!Directory(_dmgInstallerDir).existsSync()) {
    _error("dmg installer config missing.");
    return;
  }
  _log(
      'Make sure Node.js and the appdmg package are installed in your environment.');
  final dmg = File("${_dmgInstallerDir}onchain.dmg");
  if (dmg.existsSync()) {
    dmg.deleteSync();
  }
  command = "appdmg";
  args = [
    "$_dmgInstallerDir${minify ? 'config.json' : 'debug_config.json'}",
    "${_dmgInstallerDir}onchain.dmg"
  ];
  await _FlutterCommands.doProcess(command, args, shell: Platform.isWindows);
  if (releaseLocation != null && dmg.existsSync()) {
    final outDir = Directory("${releaseLocation}macos/");
    outDir.createSync(recursive: true);
    dmg.copySync(
        "${releaseLocation}macos/${minify ? 'onchain.dmg' : 'onchain_debug.dmg'}");
    _log("dmg file copied to ${outDir.absolute.path}");
  }
}

void _log(Object? text) {
  print('\x1B[33m$text\x1B[0m');
}

void _error(String text) {
  print('\x1B[31m$text\x1B[0m');
}

void main(List<String> args) async {
  if (!_isWalletContext()) {
    _log("Invalid onchain wallet context.");
    return;
  }
  final bool release = !args.contains("--debug");
  if (release) {
    _log("Make sure app logger is disabled.");
    _log("Make sure set webview to use with worker");
  }
  String? outDir;
  try {
    outDir = args
        .firstWhere((e) => e.startsWith("--out="))
        .replaceFirst("--out=", 'to');
  } catch (_) {}
  if (outDir == null || outDir.isEmpty) {
    outDir = 'release/';
  }
  final bool isWeb = args.any((e) => _webArgs.contains(e));
  if (isWeb) {
    await _ExtensionAndWebScriptsBuilder.buildWebOrExtensions(args,
        releaseLocation: outDir);
  } else if (args.contains("-apk")) {
    await _buildApk(args, releaseLocation: outDir);
  } else if (args.contains("-macos")) {
    await _buildMacos(args, releaseLocation: outDir);
  }
}
