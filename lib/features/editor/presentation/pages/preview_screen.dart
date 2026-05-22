import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

class PreviewScreen extends StatefulWidget {
  final String responderUri;
  final String formTitle;

  const PreviewScreen({
    super.key,
    required this.responderUri,
    required this.formTitle,
  });

  @override
  State<PreviewScreen> createState() => _PreviewScreenState();
}

class _PreviewScreenState extends State<PreviewScreen> {
  late final WebViewController _controller;
  int _loadingProgress = 0;

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onProgress: (progress) =>
              setState(() => _loadingProgress = progress),
        ),
      )
      ..loadRequest(Uri.parse(widget.responderUri));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.formTitle,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        bottom: _loadingProgress < 100
            ? PreferredSize(
                preferredSize: const Size.fromHeight(2),
                child: LinearProgressIndicator(value: _loadingProgress / 100),
              )
            : null,
      ),
      body: WebViewWidget(controller: _controller),
    );
  }
}
