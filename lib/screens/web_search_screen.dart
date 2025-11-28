import 'package:ai_medicine_tracker/widgets/app_text.dart';
import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

class WebSearchScreen extends StatelessWidget {
  final String medicineName;
  final String title;
  final String query;

  const WebSearchScreen({
    super.key,
    required this.medicineName,
    required this.title,
    required this.query,
  });

  @override
  Widget build(BuildContext context) {
    final url = "https://www.google.com/search?q=$query";

    return Scaffold(
      appBar: AppBar(title: AppText("$medicineName $title", maxLines: 30)),
      body: WebViewWidget(
        controller: WebViewController()
          ..setJavaScriptMode(JavaScriptMode.unrestricted)
          ..loadRequest(Uri.parse(url)),
      ),
    );
  }
}
