import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';

import '../design.dart';

class SimpleWebViewPage extends StatefulWidget {
  final String title;
  final String url;

  const SimpleWebViewPage({
    super.key,
    required this.title,
    required this.url,
  });

  @override
  State<SimpleWebViewPage> createState() => _SimpleWebViewPageState();
}

class _SimpleWebViewPageState extends State<SimpleWebViewPage> {
  InAppWebViewController? _controller;
  double _progress = 0;
  bool _isClosing = false;

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) => _handleBack(),
      child: Scaffold(
        backgroundColor: AppColors.bg,
        appBar: _buildAppBar(),
        body: _isClosing
            ? const Center(
                child: CupertinoActivityIndicator(
                    radius: 14, color: AppColors.purple),
              )
            : InAppWebView(
                initialUrlRequest: URLRequest(url: WebUri(widget.url)),
                initialSettings: InAppWebViewSettings(javaScriptEnabled: true),
                onWebViewCreated: (c) => _controller = c,
                onProgressChanged: (_, p) =>
                    setState(() => _progress = p / 100),
              ),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: Colors.transparent,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_ios_new,
            color: AppColors.purple, size: 18),
        onPressed: _handleBack,
      ),
      title: Text(
        widget.title,
        style: const TextStyle(
          fontSize: 17,
          fontWeight: FontWeight.w700,
          color: AppColors.ink,
        ),
      ),
      bottom: _progress < 1
          ? PreferredSize(
              preferredSize: const Size.fromHeight(2),
              child: LinearProgressIndicator(
                value: _progress,
                backgroundColor: Colors.transparent,
                color: AppColors.purple,
              ),
            )
          : null,
    );
  }

  Future<void> _handleBack() async {
    if (_isClosing) return;
    if (_controller != null && await _controller!.canGoBack()) {
      await _controller!.goBack();
      return;
    }
    setState(() => _isClosing = true);
    await Future.delayed(const Duration(milliseconds: 120));
    if (mounted) Navigator.of(context).pop();
  }
}
