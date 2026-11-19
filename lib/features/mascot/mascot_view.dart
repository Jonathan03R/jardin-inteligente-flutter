import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';

/// Ordenes hacia la mascota 3D. Las llamadas antes de cargar se guardan y se aplican al cargar.
class MascotController {
  InAppWebViewController? _web;
  bool _ready = false;
  String _base = 'Idle';
  String? _leaf;

  bool get ready => _ready;

  void setBase(String clip) {
    if (clip == _base && _ready) return;
    _base = clip;
    _run('mascot.setBase(${jsonEncode(clip)})');
  }

  String? _pending;

  /// Reaccion de una vez. Si el modelo aun carga, se reproduce apenas este listo.
  void react(String clip) {
    if (!_ready) {
      _pending = clip;
      return;
    }
    _run('mascot.react(${jsonEncode(clip)})');
  }

  void leafColor(String hex) {
    if (hex == _leaf && _ready) return;
    _leaf = hex;
    _run('mascot.tint("Leaf", ${jsonEncode(hex)})');
  }

  void _attach(InAppWebViewController web) => _web = web;

  void _onReady() {
    _ready = true;
    _run('mascot.setBase(${jsonEncode(_base)})');
    if (_leaf != null) _run('mascot.tint("Leaf", ${jsonEncode(_leaf)})');
    final pending = _pending;
    _pending = null;
    if (pending != null) react(pending);
  }

  void _run(String js) {
    if (!_ready) return;
    unawaited(_web?.evaluateJavascript(source: js).catchError((_) => null));
  }
}

/// Mascota 3D local: pagina con model-viewer servida por un servidor HTTP en 127.0.0.1.
/// No usa Internet; GLB, HTML y JS van dentro del APK.
class MascotView extends StatefulWidget {
  const MascotView({super.key, required this.controller, this.onTap});
  final MascotController controller;
  final VoidCallback? onTap;

  @override
  State<MascotView> createState() => _MascotViewState();
}

class _MascotViewState extends State<MascotView> {
  static const _files = {
    '/': ('assets/mascot/mascot.html', 'text/html; charset=utf-8'),
    '/model-viewer.min.js': ('assets/mascot/model-viewer.min.js', 'application/javascript; charset=utf-8'),
    '/brotito.glb': ('assets/mascot/brotito.glb', 'model/gltf-binary'),
    '/faces.json': ('assets/mascot/faces.json', 'application/json; charset=utf-8'),
  };
  HttpServer? _server;
  Uri? _url;
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    unawaited(_serve());
  }

  Future<void> _serve() async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    if (!mounted) {
      await server.close(force: true);
      return;
    }
    _server = server;
    server.listen((request) async {
      final file = _files[request.uri.path];
      final response = request.response;
      if (file == null) {
        response.statusCode = HttpStatus.notFound;
      } else {
        final bytes = (await rootBundle.load(file.$1)).buffer.asUint8List();
        response.headers
          ..set(HttpHeaders.contentTypeHeader, file.$2)
          ..set(HttpHeaders.cacheControlHeader, 'no-store');
        response.add(bytes);
      }
      await response.close();
    });
    setState(() => _url = Uri.parse('http://127.0.0.1:${server.port}/'));
  }

  @override
  void dispose() {
    unawaited(_server?.close(force: true));
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final url = _url;
    return Stack(
      fit: StackFit.expand,
      children: [
        if (url != null)
          AnimatedOpacity(
            opacity: _loaded ? 1 : 0,
            duration: const Duration(milliseconds: 500),
            child: InAppWebView(
              initialUrlRequest: URLRequest(url: WebUri.uri(url)),
              initialSettings: InAppWebViewSettings(
                transparentBackground: true,
                supportZoom: false,
                disableHorizontalScroll: true,
                disableVerticalScroll: true,
                verticalScrollBarEnabled: false,
                horizontalScrollBarEnabled: false,
                mediaPlaybackRequiresUserGesture: false,
                useHybridComposition: true,
              ),
              onWebViewCreated: (web) {
                widget.controller._attach(web);
                web.addJavaScriptHandler(
                  handlerName: 'ready',
                  callback: (_) {
                    widget.controller._onReady();
                    if (mounted) setState(() => _loaded = true);
                  },
                );
                web.addJavaScriptHandler(handlerName: 'reactionEnd', callback: (_) {});
                web.addJavaScriptHandler(
                  handlerName: 'error',
                  callback: (args) {
                    if (kDebugMode) debugPrint('[Mascota] error: $args');
                  },
                );
              },
            ),
          ),
        // Capa encima del WebView: captura toques y deja pasar el scroll a la lista.
        Positioned.fill(
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: widget.onTap,
          ),
        ),
      ],
    );
  }
}
