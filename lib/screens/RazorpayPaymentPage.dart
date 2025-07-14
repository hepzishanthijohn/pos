import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:razorpay_flutter/razorpay_flutter.dart';
import 'package:flutter_razorpay_web/flutter_razorpay_web.dart';
import 'package:url_launcher/url_launcher.dart';

class RazorpayPaymentPage extends StatefulWidget {
  final double totalAmount;
  final String customerName;
  final String customerPhone;

  const RazorpayPaymentPage({
    Key? key,
    required this.totalAmount,
    required this.customerName,
    required this.customerPhone,
  }) : super(key: key);

  @override
  State<RazorpayPaymentPage> createState() => _RazorpayPaymentPageState();
}

class _RazorpayPaymentPageState extends State<RazorpayPaymentPage> {
  Razorpay? _razorpay;
  late RazorpayWeb _razorpayWeb;

  @override
  void initState() {
    super.initState();

    if (kIsWeb) {
      _razorpayWeb = RazorpayWeb(
        onSuccess: _onSuccess,
        onCancel: _onCancel,
        onFailed: _onFailed,
      );
    } else if (Platform.isAndroid || Platform.isIOS) {
      _razorpay = Razorpay();
      _razorpay!.on(Razorpay.EVENT_PAYMENT_SUCCESS, _handlePaymentSuccess);
      _razorpay!.on(Razorpay.EVENT_PAYMENT_ERROR, _handlePaymentError);
      _razorpay!.on(Razorpay.EVENT_EXTERNAL_WALLET, _handleExternalWallet);
    }
  }

  @override
  void dispose() {
    _razorpay?.clear();
    super.dispose();
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  void startPayment() async {
    final int amountInPaise = (widget.totalAmount * 100).toInt();

    if (kIsWeb) {
      try {
        _razorpayWeb.open({
          'key': 'rzp_test_AqRRFQaXY603FG',
          'amount': amountInPaise,
          'currency': 'INR',
          'name': widget.customerName,
          'prefill': {
            'contact': widget.customerPhone,
            'email': 'test@example.com',
          },
          'theme': {'color': '#3399cc'},
        });
      } catch (e) {
        _showError('Web Razorpay error: $e');
      }
    } else if (Platform.isAndroid || Platform.isIOS) {
      try {
        var options = {
          'key': 'rzp_test_AqRRFQaXY603FG',
          'amount': amountInPaise,
          'currency': 'INR',
          'name': widget.customerName,
          'description': 'POS Order Payment',
          'prefill': {
            'contact': widget.customerPhone,
            'email': 'test@example.com',
          },
          'theme': {'color': '#3399cc'},
        };
        _razorpay!.open(options);
      } catch (e) {
        _showError('Mobile Razorpay error: $e');
      }
    } else {
      // Fallback for Desktop (Windows/macOS/Linux): Open Razorpay via browser
      final url = Uri.parse('https://rzp.io/l/demo'); // <-- Replace with real payment link or hosted checkout
      if (await canLaunchUrl(url)) {
        await launchUrl(url, mode: LaunchMode.externalApplication);
      } else {
        _showError('Could not open Razorpay in browser.');
      }
    }
  }

  // Web callbacks
  void _onSuccess(RpaySuccessResponse response) {
    debugPrint('Web Payment Success: ${response.paymentId}');
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Payment Successful')),
    );
  }

  void _onCancel(RpayCancelResponse response) {
    debugPrint('Web Payment Cancelled');
    _showError('Payment cancelled by user.');
  }

  void _onFailed(RpayFailedResponse response) {
    debugPrint('Web Payment Failed');
    _showError('Payment failed');
  }

  // Android/iOS callbacks
  void _handlePaymentSuccess(PaymentSuccessResponse response) {
    debugPrint('Mobile Payment Success: ${response.paymentId}');
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Payment Successful')),
    );
  }

  void _handlePaymentError(PaymentFailureResponse response) {
    debugPrint('Mobile Payment Failed: ${response.code} - ${response.message}');
    _showError('Payment failed: ${response.message}');
  }

  void _handleExternalWallet(ExternalWalletResponse response) {
    debugPrint('External wallet selected: ${response.walletName}');
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('External wallet selected: ${response.walletName}')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Razorpay Checkout'),
        backgroundColor: Colors.green,
      ),
      body: Center(
        child: ElevatedButton(
          onPressed: startPayment,
          child: const Text('Pay Now'),
        ),
      ),
    );
  }
}
