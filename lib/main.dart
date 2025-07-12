import 'dart:io' show Directory, Platform;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:hive_flutter/hive_flutter.dart'; // 👈 for web-safe init
import 'package:path_provider/path_provider.dart'; // desktop/mobile only
import 'package:rcspos/screens/loginpage.dart';
import 'package:rcspos/screens/home.dart';
import 'package:rcspos/offlinelineNote.dart';
import 'package:connectivity_plus/connectivity_plus.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  if (kIsWeb) {
    await Hive.initFlutter(); // ✅ Web safe
  } else {
    Directory dir = await getApplicationDocumentsDirectory();
    Hive.init(dir.path); // ✅ Native platforms only
  }

  await Hive.openBox('login');

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  Future<bool> isOnline() async {
    final result = await Connectivity().checkConnectivity();
    return result != ConnectivityResult.none;
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'RCSPOS',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: FutureBuilder<bool>(
        future: isOnline(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Scaffold(
              body: Center(child: CircularProgressIndicator()),
            );
          }

          final online = snapshot.data!;
          // Always show login first
          return online ? const Login() : const OfflineNotice();
        },
      ),
    );
  }
}
