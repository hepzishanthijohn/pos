// import 'dart:io';
// import 'package:flutter/material.dart';
// import 'package:webview_flutter/webview_flutter.dart';
// import 'package:webview_flutter_android/webview_flutter_android.dart';

// class RazorpayWebViewPage extends StatefulWidget {
//   final String filePath;
//   final Function(String paymentId) onSuccess;

//   const RazorpayWebViewPage({super.key, required this.filePath, required this.onSuccess});

//   @override
//   State<RazorpayWebViewPage> createState() => _RazorpayWebViewPageState();
// }

// class _RazorpayWebViewPageState extends State<RazorpayWebViewPage> {
//   late final WebViewController _controller;

//  @override
// void initState() {
//   super.initState();

//   if (Platform.isAndroid) {
//     WebView.platform = AndroidWebView(); // ✅ Correct for latest versions
//   }

//   _controller = WebViewController()
//     ..setJavaScriptMode(JavaScriptMode.unrestricted)
//     ..loadFile(widget.filePath)
//     ..setNavigationDelegate(
//       NavigationDelegate(
//         onNavigationRequest: (request) {
//           final url = request.url;

//           if (url.startsWith('success://payment')) {
//             final uri = Uri.parse(url);
//             final paymentId = uri.queryParameters['payment_id'];
//             if (paymentId != null) {
//               Navigator.pop(context);
//               widget.onSuccess(paymentId);
//             }
//             return NavigationDecision.prevent;
//           }

//           if (url.startsWith('cancel://payment')) {
//             Navigator.pop(context);
//             return NavigationDecision.prevent;
//           }

//           return NavigationDecision.navigate;
//         },
//       ),
//     );
// }

//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       appBar: AppBar(title: const Text("Razorpay Payment")),
//       body: WebViewWidget(controller: _controller),
//     );
//   }
// }
