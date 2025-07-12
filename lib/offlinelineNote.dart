// screens/offline_notice.dart
import 'package:flutter/material.dart';

class OfflineNotice extends StatelessWidget {
  const OfflineNotice({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: Text(
          'You are offline. Please connect to the internet to login.',
          style: TextStyle(fontSize: 16, color: Colors.red),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}
