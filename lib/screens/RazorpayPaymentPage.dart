import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';

class RazorpayPaymentPage extends StatefulWidget {
  final double totalAmount;
  final String customerName;
  final String customerPhone;

  RazorpayPaymentPage({
    required this.totalAmount,
    required this.customerName,
    required this.customerPhone,
  });

  @override
  State<RazorpayPaymentPage> createState() => _RazorpayPaymentPageState();
}

class _RazorpayPaymentPageState extends State<RazorpayPaymentPage> {
  late InAppWebViewController webViewController;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Razorpay Payment"),
      ),
      body: InAppWebView(
        initialUrlRequest: URLRequest(
          url: WebUri("assets/razorpay_checkout.html"), // Or wherever your local HTML is served
        ),
        onWebViewCreated: (controller) {
          webViewController = controller;
        },
        onLoadStop: (controller, url) {
          controller.evaluateJavascript(source: '''
            var options = {
              key: 'rzp_test_AqRRFQaXY603FG',
              amount: ${widget.totalAmount.toInt() * 100},
              currency: 'INR',
              name: '${widget.customerName}',
              description: "POS Payment",
              prefill: {
                contact: '${widget.customerPhone}',
                email: 'customer@example.com'
              },
              handler: function (response) {
                window.location.href = "success://payment?payment_id=" + response.razorpay_payment_id;
              },
              modal: {
                ondismiss: function () {
                  window.location.href = "cancel://payment";
                }
              }
            };
            var rzp = new Razorpay(options);
            rzp.open();
          ''');
        },
        shouldOverrideUrlLoading: (controller, navigationAction) async {
          final url = navigationAction.request.url.toString();
          if (url.startsWith("success://payment")) {
            final uri = Uri.parse(url);
            final paymentId = uri.queryParameters["payment_id"];
            Navigator.pop(context, paymentId);
            return NavigationActionPolicy.CANCEL;
          } else if (url.startsWith("cancel://payment")) {
            Navigator.pop(context);
            return NavigationActionPolicy.CANCEL;
          }
          return NavigationActionPolicy.ALLOW;
        },
      ),
    );
  }
}
