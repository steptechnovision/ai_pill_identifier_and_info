import 'package:ai_medicine_tracker/helper/app_colors.dart';
import 'package:ai_medicine_tracker/widgets/app_bar_title_view.dart';
import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_flutter_android/webview_flutter_android.dart';

class WebViewPage extends StatefulWidget {
  final String title;
  final String url;

  const WebViewPage({super.key, required this.title, required this.url});

  @override
  State<WebViewPage> createState() => _WebViewPageState();
}

class _WebViewPageState extends State<WebViewPage> {
  late final WebViewController _controller;
  bool isLoading = true;
  bool isInScreen = true;

  @override
  void initState() {
    super.initState();
    createWebView();
  }

  void createWebView() async {
    _controller = WebViewController();
    await _controller.setJavaScriptMode(JavaScriptMode.unrestricted);
    await _controller.setBackgroundColor(const Color(0x00000000));
    await _controller.setNavigationDelegate(
      NavigationDelegate(
        onProgress: (int progress) {},
        onPageStarted: (String url) {},
        onPageFinished: (String url) {
          if (isInScreen) {
            setState(() {
              isLoading = false;
            });
          }
        },
      ),
    );
    if (_controller.platform is AndroidWebViewController) {
      AndroidWebViewCookieManager cookieManager = AndroidWebViewCookieManager(
        const PlatformWebViewCookieManagerCreationParams(),
      );
      await cookieManager.setAcceptThirdPartyCookies(
        _controller.platform as AndroidWebViewController,
        true,
      );
    }
    await _controller.loadRequest(Uri.parse(widget.url));
  }

  @override
  void dispose() {
    super.dispose();
    isInScreen = false;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: UIConstants.darkBackgroundStart,
      appBar: AppBar(
        backgroundColor: UIConstants.darkBackgroundStart,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close_rounded, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: AppBarTitleView(title: widget.title),
      ),
      body: Column(
        children: [
          Expanded(
            child: Stack(
              children: [
                WebViewWidget(controller: _controller),
                isLoading
                    ? const Center(
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.greenAccent,
                        ),
                      )
                    : const SizedBox.shrink(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
