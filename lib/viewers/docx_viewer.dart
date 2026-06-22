import 'dart:io';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as shelf_io;
import 'package:shelf_static/shelf_static.dart';
import 'package:webview_windows/webview_windows.dart';
import 'package:file_picker/file_picker.dart';

class DocxViewer extends StatefulWidget {
  final String filePath;
  const DocxViewer({super.key, required this.filePath});

  @override
  State<DocxViewer> createState() => _DocxViewerState();
}

class _DocxViewerState extends State<DocxViewer> {
  final _webviewController = WebviewController();
  HttpServer? _localServer;
  bool _isReady = false;
  String? _activePath;

  @override
  void initState() {
    super.initState();
    _activePath = widget.filePath;
    if (_activePath != null && _activePath!.isNotEmpty) {
      _initAll();
    }
  }

  Future<void> _pickFile() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['docx', 'xlsx', 'pptx'],
    );
    if (result != null && result.files.single.path != null) {
      setState(() => _activePath = result.files.single.path);
      _initAll();
    }
  }

  // ── Middleware: מגיש קבצי .gz עם Content-Encoding: gzip ──────────────
  Handler _buildHandler(String webPath) {
    final staticHandler = createStaticHandler(webPath, defaultDocument: 'index.html');

    return const Pipeline()
        // 1. Headers נדרשים ל-SharedArrayBuffer (ל-WASM)
        .addMiddleware((inner) => (req) async {
              final res = await inner(req);
              return res.change(headers: {
                'Cross-Origin-Opener-Policy': 'same-origin',
                'Cross-Origin-Embedder-Policy': 'require-corp',
                'Access-Control-Allow-Origin': '*',
                ...res.headers,
              });
            })
        // 2. Gzip: אם קיים .gz מגיש אותו עם Content-Encoding
        .addMiddleware((inner) => (req) async {
              final acceptEncoding = req.headers['accept-encoding'] ?? '';
              if (acceptEncoding.contains('gzip')) {
                final filePath = p.join(webPath, req.url.path);
                final gzFile = File('$filePath.gz');
                if (await gzFile.exists()) {
                  final ext = p.extension(req.url.path);
                  return Response.ok(
                    gzFile.openRead(),
                    headers: {
                      'Content-Encoding': 'gzip',
                      'Content-Type': _mimeType(ext),
                      'Cache-Control': 'public, max-age=86400',
                    },
                  );
                }
              }
              return inner(req);
            })
        .addHandler((Request request) async {
          // נתיב מיוחד לטעינת הקובץ הנוכחי
          if (request.url.path == 'fetch_file') {
            final file = File(_activePath!);
            if (await file.exists()) {
              final ext = p.extension(_activePath!).toLowerCase();
              return Response.ok(
                file.openRead(),
                headers: {'Content-Type': _mimeType(ext)},
              );
            }
            return Response.notFound('File not found');
          }
          return staticHandler(request);
        });
  }

  String _mimeType(String ext) {
    switch (ext.toLowerCase()) {
      case '.js':   return 'application/javascript';
      case '.css':  return 'text/css';
      case '.json': return 'application/json';
      case '.html': return 'text/html; charset=utf-8';
      case '.wasm': return 'application/wasm';
      case '.svg':  return 'image/svg+xml';
      case '.png':  return 'image/png';
      case '.docx': return 'application/vnd.openxmlformats-officedocument.wordprocessingml.document';
      case '.xlsx': return 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet';
      case '.pptx': return 'application/vnd.openxmlformats-officedocument.presentationml.presentation';
      default:      return 'application/octet-stream';
    }
  }

  Future<void> _initAll() async {
    try {
      // סגור שרת קודם אם קיים
      await _localServer?.close(force: true);
      setState(() => _isReady = false);

      final exeDir = p.dirname(Platform.resolvedExecutable);
      final webPath = Directory(p.join(exeDir, 'onlyoffice_web')).existsSync()
          ? p.join(exeDir, 'onlyoffice_web')
          : p.join(Directory.current.path, 'onlyoffice_web');

      _localServer = await shelf_io.serve(
        _buildHandler(webPath),
        '127.0.0.1',
        0, // פורט אקראי
      );

      await _webviewController.initialize();

      final port = _localServer!.port;
      final fileName = Uri.encodeComponent(p.basename(_activePath!));
      final fileUrl  = Uri.encodeComponent('http://127.0.0.1:$port/fetch_file');
      final startUrl = 'http://127.0.0.1:$port/index.html#/?url=$fileUrl&filename=$fileName';

      debugPrint('Opening: $startUrl');
      await _webviewController.loadUrl(startUrl);

      if (mounted) setState(() => _isReady = true);
    } catch (e) {
      debugPrint('Error in _initAll: $e');
    }
  }

  @override
  void dispose() {
    _localServer?.close();
    _webviewController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_activePath == null || _activePath!.isEmpty) {
      return Container(
        color: const Color(0xFF333333),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.description, size: 80, color: Colors.white24),
              const SizedBox(height: 20),
              const Text('עורך המסמכים מוכן',
                  style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
              const SizedBox(height: 10),
              const Text('בחר קובץ מהמחשב כדי להתחיל בעריכה',
                  style: TextStyle(color: Colors.white70, fontSize: 16)),
              const SizedBox(height: 30),
              ElevatedButton.icon(
                onPressed: _pickFile,
                icon: const Icon(Icons.file_open),
                label: const Text('בחר קובץ DOCX / XLSX / PPTX'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 20),
                  backgroundColor: Theme.of(context).primaryColor,
                  foregroundColor: Colors.white,
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (!_isReady) {
      return const Center(child: CircularProgressIndicator());
    }

    return Webview(_webviewController);
  }
}