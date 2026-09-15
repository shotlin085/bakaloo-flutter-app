import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:webview_flutter/webview_flutter.dart';

import 'package:bakaloo_flutter_app/core/theme/app_colors.dart';
import 'package:bakaloo_flutter_app/features/nav_button/presentation/providers/nav_button_provider.dart';

/// Full-screen embedded destination for a WEBVIEW nav button — a website
/// or a game, taking over the whole screen the way an in-app event page
/// does in apps like this one's design was modeled on. Deliberately no
/// bottom nav bar and no app bar of this app's own chrome, only a small
/// floating close control, so the destination page genuinely reads as its
/// own full-screen experience rather than a cramped panel inside Bakaloo.
class NavButtonWebviewScreen extends ConsumerStatefulWidget {
  const NavButtonWebviewScreen({
    required this.url,
    this.passIdentity = false,
    super.key,
  });

  final String url;
  final bool passIdentity;

  @override
  ConsumerState<NavButtonWebviewScreen> createState() =>
      _NavButtonWebviewScreenState();
}

class _NavButtonWebviewScreenState
    extends ConsumerState<NavButtonWebviewScreen> {
  late final WebViewController _controller;
  bool _loading = true;
  bool _resolvingIdentity;

  _NavButtonWebviewScreenState() : _resolvingIdentity = false;

  @override
  void initState() {
    super.initState();
    _resolvingIdentity = widget.passIdentity;
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (_) {
            if (mounted) setState(() => _loading = true);
          },
          onPageFinished: (_) {
            if (mounted) setState(() => _loading = false);
          },
        ),
      );
    unawaited(_load());
  }

  Future<void> _load() async {
    var target = widget.url;
    if (widget.passIdentity) {
      try {
        final token = await ref
            .read(navButtonRemoteDataSourceProvider)
            .getWebviewToken();
        if (token != null && token.isNotEmpty) {
          final uri = Uri.parse(widget.url);
          target = uri
              .replace(
                queryParameters: <String, String>{
                  ...uri.queryParameters,
                  'bakaloo_token': token,
                },
              )
              .toString();
        }
      } catch (_) {
        // Identity handoff is best-effort — the destination still loads,
        // it just won't be able to identify the customer automatically.
      }
    }
    if (!mounted) return;
    setState(() => _resolvingIdentity = false);
    await _controller.loadRequest(Uri.parse(target));
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: true,
      child: Scaffold(
        backgroundColor: Colors.white,
        body: SafeArea(
          child: Stack(
            children: <Widget>[
              if (!_resolvingIdentity) WebViewWidget(controller: _controller),
              if (_loading || _resolvingIdentity)
                const Center(
                  child: CircularProgressIndicator(
                    color: AppColors.orderViolet,
                  ),
                ),
              Positioned(
                top: 8,
                left: 8,
                child: Material(
                  color: Colors.black.withValues(alpha: 0.35),
                  shape: const CircleBorder(),
                  child: InkWell(
                    customBorder: const CircleBorder(),
                    onTap: () => Navigator.of(context).maybePop(),
                    child: const Padding(
                      padding: EdgeInsets.all(8),
                      child: Icon(
                        Icons.close_rounded,
                        color: Colors.white,
                        size: 22,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
