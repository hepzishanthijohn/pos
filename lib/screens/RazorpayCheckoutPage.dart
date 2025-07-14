// import 'dart:io';
// import 'package:flutter/material.dart';
// import 'package:webview_flutter/webview_flutter.dart';

// class RazorpayCheckoutPage extends StatefulWidget {
//   @override
//   State<RazorpayCheckoutPage> createState() => _RazorpayCheckoutPageState();
// }

// class _RazorpayCheckoutPageState extends State<RazorpayCheckoutPage> {
//   late WebViewController _controller;

//   @override
//   void initState() {
//     super.initState();

//     // Initialize WebView
//     if (Platform.isAndroid || Platform.isIOS) {
//       WebView.platform = SurfaceAndroidWebView(); // For Android, set platform to SurfaceAndroidWebView
//     }

//     // Initializing the WebView controller
//     _controller = WebViewController();
//   }

//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       appBar: AppBar(
//         title: const Text("Razorpay Checkout"),
//         backgroundColor: Colors.green,
//       ),
//       body: WebView(
//         initialUrl: 'https://checkout.razorpay.com/v1/checkout.js',
//         javascriptMode: JavascriptMode.unrestricted, // Allow JavaScript execution
//         onWebViewCreated: (WebViewController webViewController) {
//           _controller = webViewController;
//         },
//         navigationDelegate: (NavigationRequest request) {
//           // Handle success or cancellation
//           if (request.url.startsWith('success://payment')) {
//             final Uri uri = Uri.parse(request.url);
//             final paymentId = uri.queryParameters['payment_id'];
//             if (paymentId != null) {
//               // Handle success
//               print('Payment successful with ID: $paymentId');
//               // You can navigate to a success screen here or show a confirmation message.
//             }
//             return NavigationDecision.prevent;
//           }

//           if (request.url.startsWith('cancel://payment')) {
//             // Handle cancellation
//             print('Payment canceled');
//             return NavigationDecision.prevent;
//           }

//           return NavigationDecision.navigate;
//         },
//       ),
//     );
//   }
// }
