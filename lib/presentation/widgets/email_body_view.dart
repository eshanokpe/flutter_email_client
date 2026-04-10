import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/theme/app_theme.dart';

/// Renders an email body — HTML with images, links, and formatting,
/// or falls back to plain selectable text when there is no HTML.
class EmailBodyView extends StatefulWidget {
  final String body;
  final bool isHtml;

  const EmailBodyView({super.key, required this.body, this.isHtml = false});

  @override
  State<EmailBodyView> createState() => _EmailBodyViewState();
}

class _EmailBodyViewState extends State<EmailBodyView> {
  InAppWebViewController? _webController;

  // Start with a reasonable minimum height; grows as content loads
  double _webHeight = 300;

  /// Wraps raw HTML in a full document with Gmail-matching styles.
  String _buildHtmlDocument(String body) {
    return '''
<!DOCTYPE html>
<html>
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0, maximum-scale=1.0">
  <style>
    * { box-sizing: border-box; margin: 0; padding: 0; }

    body {
      font-family: Roboto, Arial, sans-serif;
      font-size: 14px;
      line-height: 1.6;
      color: #202124;
      background: #ffffff;
      padding: 0 4px;
      word-break: break-word;
      overflow-wrap: break-word;
    }

    /* Images */
    img {
      max-width: 100% !important;
      height: auto !important;
      display: block;
    }

    /* Links */
    a {
      color: #1a73e8;
      text-decoration: none;
    }
    a:hover { text-decoration: underline; }

    /* Tables — Gmail uses them heavily for layout */
    table {
      max-width: 100% !important;
      border-collapse: collapse;
    }
    td, th {
      word-break: break-word;
    }

    /* Blockquotes — replied/forwarded content */
    blockquote {
      border-left: 3px solid #dadce0;
      margin: 8px 0;
      padding-left: 12px;
      color: #5f6368;
    }

    /* Preformatted / code */
    pre, code {
      font-family: monospace;
      font-size: 13px;
      background: #f1f3f4;
      padding: 2px 4px;
      border-radius: 2px;
    }

    /* Gmail quote toggle */
    .gmail_quote { color: #5f6368; }

    /* Dividers */
    hr {
      border: none;
      border-top: 1px solid #e0e0e0;
      margin: 12px 0;
    }

    /* Prevent wide elements from causing horizontal scroll */
    body > * { max-width: 100% !important; }
  </style>
</head>
<body>
$body
</body>
</html>
''';
  }

  @override
  Widget build(BuildContext context) {
    // Plain text — simple selectable text, no WebView overhead
    if (!widget.isHtml || widget.body.isEmpty) {
      return SelectableText(
        widget.body.isNotEmpty ? widget.body : '(no content)',
        style: const TextStyle(
          fontSize: 14,
          color: AppTheme.onSurface,
          height: 1.6,
        ),
      );
    }

    // HTML — render in WebView with dynamic height
    final html = _buildHtmlDocument(widget.body);
    final encoded = Uri.dataFromString(
      html,
      mimeType: 'text/html',
      encoding: utf8,
    );

    return SizedBox(
      height: _webHeight,
      child: InAppWebView(
        initialUrlRequest: URLRequest(url: WebUri.uri(encoded.normalizePath())),
        initialSettings: InAppWebViewSettings(
          // Disable zoom — email clients don't zoom
          supportZoom: false,
          builtInZoomControls: false,
          displayZoomControls: false,
          // Transparent background matches the scaffold
          transparentBackground: true,
          // Allow images to load (including remote ones)
          blockNetworkImage: false,
          // Fit content width to device
          useWideViewPort: false,
          loadWithOverviewMode: true,
          // Disable scrolling inside WebView — parent ListView scrolls
          disableVerticalScroll: true,
          disableHorizontalScroll: true,
          // Allow mixed content (some emails use http images)
          mixedContentMode: MixedContentMode.MIXED_CONTENT_ALWAYS_ALLOW,
          // Disable context menu to keep it clean
          disableLongPressContextMenuOnLinks: false,
        ),
        onWebViewCreated: (controller) {
          _webController = controller;
        },
        // Intercept all link taps → open in external browser
        shouldOverrideUrlLoading: (controller, navigationAction) async {
          final url = navigationAction.request.url;
          if (url == null) return NavigationActionPolicy.ALLOW;

          final urlString = url.toString();

          // Allow the initial data:// load through
          if (urlString.startsWith('data:')) {
            return NavigationActionPolicy.ALLOW;
          }

          // Open everything else externally
          final uri = Uri.tryParse(urlString);
          if (uri != null) {
            if (await canLaunchUrl(uri)) {
              await launchUrl(uri, mode: LaunchMode.externalApplication);
            }
          }
          return NavigationActionPolicy.CANCEL;
        },
        // Dynamically resize height to fit content — no scroll bars
        onLoadStop: (controller, url) async {
          final height = await controller.evaluateJavascript(
            source: 'document.documentElement.scrollHeight',
          );
          if (height != null && mounted) {
            final h = double.tryParse(height.toString()) ?? _webHeight;
            setState(() => _webHeight = h + 16); // small bottom padding
          }
        },
        // Handle errors gracefully
        onReceivedError: (controller, request, error) {
          debugPrint('WebView error: ${error.description}');
        },
      ),
    );
  }
}
