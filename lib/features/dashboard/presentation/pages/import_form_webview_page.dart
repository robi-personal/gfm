import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';

import '../../../../core/theme/app_colors.dart';

class ImportFormWebViewPage extends StatefulWidget {
  const ImportFormWebViewPage({super.key});

  @override
  State<ImportFormWebViewPage> createState() => _ImportFormWebViewPageState();
}

class _ImportFormWebViewPageState extends State<ImportFormWebViewPage> {
  InAppWebViewController? _controller;
  double _progress = 0;
  bool _isClosing = false;

  // Matches /forms/d/{id}/edit or /viewform, with optional /u/N/ user-account
  // prefix. Excludes /disabledform (thumbnail previews) and other suffixes.
  static final _formIdPattern = RegExp(
      r'/forms/(?:u/\d+/)?d/([a-zA-Z0-9_-]{20,})/(?:edit|viewform)\b');

  // Track whether the user has interacted with the page. We only honor form
  // navigations after a real user gesture — this blocks Google's "open last
  // form" auto-redirect at page load.
  bool _hasUserInteracted = false;

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
          title: const Text(
            'Import Form',
            style: TextStyle(
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
                      'https://drive.google.com/drive/u/0/search?q=type:form'),
                ),
                initialSettings: InAppWebViewSettings(
                  javaScriptEnabled: true,
                  userAgent:
                      'Mozilla/5.0 (iPhone; CPU iPhone OS 17_5 like Mac OS X) '
                      'AppleWebKit/605.1.15 (KHTML, like Gecko) '
                      'Version/17.5 Mobile/15E148 Safari/604.1',
                ),
                onWebViewCreated: (c) {
                  _controller = c;
                  c.addJavaScriptHandler(
                    handlerName: 'UserTap',
                    callback: (_) {
                      _hasUserInteracted = true;
                    },
                  );
                  c.addJavaScriptHandler(
                    handlerName: 'FormTap',
                    callback: (args) {
                      final id = args.isNotEmpty ? args.first as String? : null;
                      if (id == null || id.isEmpty || _isClosing) return;
                      _popWithId(id);
                    },
                  );
                },
                onProgressChanged: (_, p) =>
                    setState(() => _progress = p / 100),
                shouldOverrideUrlLoading: (controller, action) async {
                  final url = action.request.url?.toString() ?? '';
                  final navType = action.navigationType;
                  final isMainFrame =
                      action.targetFrame?.isMainFrame ?? action.isForMainFrame;

                  // Ignore iframe loads (thumbnails / prefetches).
                  if (!isMainFrame) return NavigationActionPolicy.ALLOW;

                  final match = _formIdPattern.firstMatch(url);
                  if (match != null) {
                    final isUserTap =
                        navType == NavigationType.LINK_ACTIVATED ||
                            _hasUserInteracted;
                    if (isUserTap && !_isClosing) {
                      final formId = match.group(1)!;
                      _popWithId(formId);
                      return NavigationActionPolicy.CANCEL;
                    }
                  }
                  return NavigationActionPolicy.ALLOW;
                },
                onLoadStop: (controller, _) async {
                  // Hook into clicks at the document level (capture phase) to
                  // find a Drive/Forms file ID from the tapped element. Drive's
                  // mobile UI doesn't navigate in the main frame when a form is
                  // tapped, so we can't intercept via shouldOverrideUrlLoading
                  // — we have to find the ID from the DOM directly.
                  await controller.evaluateJavascript(source: r'''
                    (function() {
                      if (window.__gfmTapHook) return;
                      window.__gfmTapHook = true;

                      var hrefPattern = /\/forms\/(?:u\/\d+\/)?d\/([a-zA-Z0-9_-]{20,})/;
                      var idPattern = /^[a-zA-Z0-9_-]{20,}$/;
                      var attrs = ['data-id', 'data-target-id', 'data-document-id'];

                      function findFormId(el) {
                        while (el && el !== document.body) {
                          if (el.tagName === 'A' && el.href) {
                            var m = el.href.match(hrefPattern);
                            if (m) return m[1];
                          }
                          if (el.getAttribute) {
                            for (var i = 0; i < attrs.length; i++) {
                              var v = el.getAttribute(attrs[i]);
                              if (v && idPattern.test(v)) return v;
                            }
                          }
                          el = el.parentElement;
                        }
                        return null;
                      }

                      // Track interaction (still used by shouldOverrideUrlLoading
                      // as a fallback signal).
                      ['touchstart','pointerdown','mousedown'].forEach(function(evt) {
                        document.addEventListener(evt, function() {
                          window.flutter_inappwebview.callHandler('UserTap');
                        }, true);
                      });

                      // Primary interception: find form ID on click.
                      document.addEventListener('click', function(e) {
                        var id = findFormId(e.target);
                        if (id) {
                          e.preventDefault();
                          e.stopPropagation();
                          window.flutter_inappwebview.callHandler('FormTap', id);
                        }
                      }, true);
                    })();
                  ''');
                },
                onLoadStart: (controller, url) {
                  // Reset interaction flag when a fresh page begins loading,
                  // unless we're mid-tap (handler will set it true momentarily).
                  setState(() => _hasUserInteracted = false);
                },
              ),
            ),
            const _HintBar(),
          ],
        ),
      ),
    );
  }

  Future<void> _popWithResult(String? id) async {
    if (_isClosing) return;
    setState(() => _isClosing = true);
    // Wait for rebuild + native platform-view disposal. Without this delay
    // the WebView's PlatformView leaves a black artifact during the route's
    // exit animation, because iOS hasn't fully released the layer by the
    // time the slide-out starts.
    await Future.delayed(const Duration(milliseconds: 120));
    if (mounted) Navigator.of(context).pop(id);
  }

  void _popWithId(String id) {
    _popWithResult(id);
  }

  Future<void> _handleBack() async {
    if (_isClosing) return;
    if (_controller != null && await _controller!.canGoBack()) {
      await _controller!.goBack();
    } else {
      await _popWithResult(null);
    }
  }
}

class _HintBar extends StatelessWidget {
  const _HintBar();

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
      child: const Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(CupertinoIcons.hand_point_left,
              size: 14, color: AppColors.textSecondary),
          SizedBox(width: 6),
          Text(
            'Tap any form to import it',
            style: TextStyle(
              fontSize: 13,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}
