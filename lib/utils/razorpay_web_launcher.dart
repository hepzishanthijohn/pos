// razorpay_web_launcher.dart

import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:url_launcher/url_launcher.dart';

void launchRazorpayCheckout({
  required double amount,
  required String key,
  required String name,
  required String phone,
  String email = '',
}) async {
  final htmlContent = '''
    <html>
    <head>
      <script src="https://checkout.razorpay.com/v1/checkout.js"></script>
    </head>
    <body onload="startRazorpay()">
      <script>
        function startRazorpay() {
          var options = {
            "key": "$key",
            "amount": ${amount.toInt() * 100},
            "currency": "INR",
            "name": "$name",
            "description": "POS Payment",
            "prefill": {
              "contact": "$phone",
              "email": "$email"
            },
            "handler": function (response){
              window.location.href = "https://example.com/success?payment_id=" + response.razorpay_payment_id;
            },
            "modal": {
              "ondismiss": function(){
                window.location.href = "https://example.com/cancelled";
              }
            }
          };
          var rzp = new Razorpay(options);
          rzp.open();
        }
      </script>
    </body>
    </html>
  ''';

  final dir = await getTemporaryDirectory();
  final file = File('${dir.path}/razorpay_checkout.html');
  await file.writeAsString(htmlContent);

  final uri = Uri.file(file.path);
  if (!await launchUrl(uri)) {
    throw 'Could not launch browser with Razorpay';
  }
}
