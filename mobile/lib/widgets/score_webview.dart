import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

class ScoreWebView extends StatefulWidget {
  const ScoreWebView({super.key, required this.musicXmlUrl});

  final String musicXmlUrl;

  @override
  State<ScoreWebView> createState() => _ScoreWebViewState();
}

class _ScoreWebViewState extends State<ScoreWebView> {
  late final WebViewController _controller;

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(const Color(0x00000000));
    _loadSheet();
  }

  @override
  void didUpdateWidget(covariant ScoreWebView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.musicXmlUrl != widget.musicXmlUrl) {
      _loadSheet();
    }
  }

  Future<void> _loadSheet() async {
    final safeUrl = widget.musicXmlUrl.replaceAll("'", "%27");
    final html = '''
<!doctype html>
<html>
<head>
  <meta name="viewport" content="width=device-width,initial-scale=1" />
  <script src="https://cdn.jsdelivr.net/npm/opensheetmusicdisplay@1.9.2/build/opensheetmusicdisplay.min.js"></script>
  <style>
    body { margin: 0; font-family: sans-serif; background: #fff; }
    #osmd { width: 100vw; min-height: 100vh; padding: 8px; box-sizing: border-box; }
  </style>
</head>
<body>
  <div id="osmd"></div>
  <script>
    async function render() {
      const osmd = new opensheetmusicdisplay.OpenSheetMusicDisplay('osmd', {
        autoResize: true,
        backend: 'svg',
        drawPartNames: true,
      });
      await osmd.load('$safeUrl');
      osmd.render();
    }
    render();
  </script>
</body>
</html>
''';

    await _controller.loadHtmlString(html);
  }

  @override
  Widget build(BuildContext context) {
    return WebViewWidget(controller: _controller);
  }
}
