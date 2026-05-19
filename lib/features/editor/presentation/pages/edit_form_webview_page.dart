import 'dart:collection';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';

import '../../../../core/theme/app_colors.dart';

/// Opens the Google Forms web editor for a specific form in an in-app
/// WebView. Used to add features the Forms API doesn't support (currently
/// just file-upload questions). On pop, the caller is expected to refresh
/// the form so any changes made in the web editor surface locally.
class EditFormWebViewPage extends StatefulWidget {
  final String formId;
  final String title;

  const EditFormWebViewPage({
    super.key,
    required this.formId,
    this.title = 'Add file upload',
  });

  @override
  State<EditFormWebViewPage> createState() => _EditFormWebViewPageState();
}

class _EditFormWebViewPageState extends State<EditFormWebViewPage> {
  InAppWebViewController? _controller;
  double _progress = 0;
  bool _isClosing = false;

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) => _handleBack(),
      child: Scaffold(
        backgroundColor: AppColors.groupedBackground,
        appBar: AppBar(
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
              color: AppColors.textPrimary,
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
        ),
        body: _isClosing
            ? const Center(
                child: CupertinoActivityIndicator(
                    radius: 14, color: AppColors.purple),
              )
            : Column(
                children: [
                  Expanded(
                    child: InAppWebView(
                      initialUrlRequest: URLRequest(
                        url: WebUri(
                            'https://docs.google.com/forms/d/${widget.formId}/edit'),
                      ),
                      initialSettings: InAppWebViewSettings(
                        javaScriptEnabled: true,
                        userAgent:
                            'Mozilla/5.0 (iPhone; CPU iPhone OS 17_5 like Mac OS X) '
                            'AppleWebKit/605.1.15 (KHTML, like Gecko) '
                            'Version/17.5 Mobile/15E148 Safari/604.1',
                      ),
                      initialUserScripts: UnmodifiableListView<UserScript>([
                        UserScript(
                          source: r'''
                            (function() {
                              var s = document.createElement('style');
                              // Hide Drive/Forms mobile toolbars so only the
                              // editor itself shows under our AppBar.
                              s.textContent =
                                '.a-s-tb-Kg, .D-B { display: none !important; }';
                              (document.head || document.documentElement).appendChild(s);
                            })();
                          ''',
                          injectionTime:
                              UserScriptInjectionTime.AT_DOCUMENT_START,
                        ),
                      ]),
                      onWebViewCreated: (c) => _controller = c,
                      onProgressChanged: (_, p) =>
                          setState(() => _progress = p / 100),
                    ),
                  ),
                  _HintBar(isEditing: widget.title.startsWith('Edit')),
                ],
              ),
      ),
    );
  }

  Future<void> _handleBack() async {
    if (_isClosing) return;
    if (_controller != null && await _controller!.canGoBack()) {
      await _controller!.goBack();
      return;
    }
    setState(() => _isClosing = true);
    // Let the rebuild + native PlatformView disposal complete before popping
    // to avoid a black artifact during the exit animation.
    await Future.delayed(const Duration(milliseconds: 120));
    if (mounted) Navigator.of(context).pop();
  }
}

class _HintBar extends StatelessWidget {
  final bool isEditing;

  const _HintBar({required this.isEditing});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      color: Colors.white,
      padding: EdgeInsets.only(
        top: 10,
        bottom: MediaQuery.of(context).padding.bottom + 10,
        left: 16,
        right: 16,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(CupertinoIcons.arrow_up_doc,
              size: 14, color: AppColors.textSecondary),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              isEditing
                  ? 'Edit your file upload question, then tap ← to return'
                  : 'Add your file upload question, then tap ← to return',
              style: const TextStyle(
                fontSize: 13,
                color: AppColors.textSecondary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
