import 'dart:collection';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';

import '../../../../core/design.dart';

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

  // Only honour form navigations after a real user gesture — blocks Google's
  // "open last form" auto-redirect that fires at page load.
  bool _hasUserInteracted = false;

  static const _kDriveSearchUrl =
      'https://drive.google.com/drive/u/0/search?q=type:form';

  static const _kSafariUserAgent =
      'Mozilla/5.0 (iPhone; CPU iPhone OS 17_5 like Mac OS X) '
      'AppleWebKit/605.1.15 (KHTML, like Gecko) '
      'Version/17.5 Mobile/15E148 Safari/604.1';

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) => _handleBack(),
      child: Scaffold(
        backgroundColor: AppColors.bg,
        appBar: _buildAppBar(),
        body: _isClosing ? _buildClosingSpinner() : _buildBody(),
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
      title: const Text(
        'Import Form',
        style: TextStyle(
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

  Widget _buildClosingSpinner() {
    return const Center(
      child: CupertinoActivityIndicator(radius: 14, color: AppColors.purple),
    );
  }

  Widget _buildBody() {
    return Column(
      children: [
        Expanded(child: _buildWebView()),
        const _HintBar(),
      ],
    );
  }

  Widget _buildWebView() {
    return InAppWebView(
      initialUrlRequest: URLRequest(url: WebUri(_kDriveSearchUrl)),
      initialSettings: InAppWebViewSettings(
        javaScriptEnabled: true,
        userAgent: _kSafariUserAgent,
      ),
      initialUserScripts: UnmodifiableListView<UserScript>([
        _buildHideHeaderScript(),
      ]),
      onWebViewCreated: _onWebViewCreated,
      onProgressChanged: (_, p) => setState(() => _progress = p / 100),
      onLoadStart: (controller, url) => setState(() => _hasUserInteracted = false),
      onLoadStop: (controller, url) => _injectTapHook(controller),
      shouldOverrideUrlLoading: _shouldOverrideUrlLoading,
    );
  }

  UserScript _buildHideHeaderScript() {
    return UserScript(
      // Hide Drive's search toolbar and its outer wrapper before any content
      // renders so the header never paints (no glimpse).
      source: r'''
        (function() {
          var s = document.createElement('style');
          s.textContent = '.a-s-tb-Kg, .D-B { display: none !important; }';
          (document.head || document.documentElement).appendChild(s);
        })();
      ''',
      injectionTime: UserScriptInjectionTime.AT_DOCUMENT_START,
    );
  }

  void _onWebViewCreated(InAppWebViewController c) {
    _controller = c;
    c.addJavaScriptHandler(
      handlerName: 'UserTap',
      callback: (_) => _hasUserInteracted = true,
    );
    c.addJavaScriptHandler(
      handlerName: 'FormTap',
      callback: (args) {
        final id = args.isNotEmpty ? args.first as String? : null;
        if (id == null || id.isEmpty || _isClosing) return;
        _popWithId(id);
      },
    );
  }

  Future<NavigationActionPolicy?> _shouldOverrideUrlLoading(
      InAppWebViewController controller, NavigationAction action) async {
    final url = action.request.url?.toString() ?? '';
    final isMainFrame =
        action.targetFrame?.isMainFrame ?? action.isForMainFrame;

    if (!isMainFrame) return NavigationActionPolicy.ALLOW;

    final match = _formIdPattern.firstMatch(url);
    if (match != null) {
      final isUserTap = action.navigationType == NavigationType.LINK_ACTIVATED
          || _hasUserInteracted;
      if (isUserTap && !_isClosing) {
        _popWithId(match.group(1)!);
        return NavigationActionPolicy.CANCEL;
      }
    }
    return NavigationActionPolicy.ALLOW;
  }

  Future<void> _injectTapHook(InAppWebViewController controller) async {
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

        ['touchstart', 'pointerdown', 'mousedown'].forEach(function(evt) {
          document.addEventListener(evt, function() {
            window.flutter_inappwebview.callHandler('UserTap');
          }, true);
        });

        document.addEventListener('click', function(e) {
          var id = findFormId(e.target);
          if (id) {
            e.preventDefault();
            e.stopPropagation();
            window.flutter_inappwebview.callHandler('FormTap', id);
          }
        }, true);

        function hideSearchHeader() {
          var inputs = document.querySelectorAll(
              'input[aria-label="Search all items"]');
          for (var i = 0; i < inputs.length; i++) {
            var p = inputs[i];
            for (var d = 0; d < 6 && p && p.parentElement; d++) {
              p = p.parentElement;
            }
            if (p) p.style.display = 'none';
          }
        }
        hideSearchHeader();
        setTimeout(hideSearchHeader, 300);
        setTimeout(hideSearchHeader, 1200);
      })();
    ''');
  }

  void _popWithId(String id) => _popWithResult(id);

  Future<void> _popWithResult(String? id) async {
    if (_isClosing) return;
    setState(() => _isClosing = true);
    // Delay lets the rebuild + native PlatformView disposal complete before
    // popping — avoids a black artifact during the exit animation on iOS.
    await Future.delayed(const Duration(milliseconds: 120));
    if (mounted) Navigator.of(context).pop(id);
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

// ── Hint bar ──────────────────────────────────────────────────────────────────

class _HintBar extends StatelessWidget {
  const _HintBar();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      color: AppColors.surface,
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
              size: 14, color: AppColors.muted),
          SizedBox(width: 6),
          Text(
            'Tap any form to import it',
            style: TextStyle(fontSize: 13, color: AppColors.muted),
          ),
        ],
      ),
    );
  }
}
