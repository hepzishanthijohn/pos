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

  // Platform-specific Hive initialization
  if (!kIsWeb) { // For mobile and desktop
    final appDocDir = await getApplicationDocumentsDirectory();
    Hive.init(appDocDir.path);
  } else { // For web
    await Hive.initFlutter(); // Use hive_flutter for web
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
        // Set the default font family for the entire app
        fontFamily: 'Arial', // <-- This line sets Arial as the default font

        // Define a comprehensive TextTheme
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
          return online ? const Login() : const OfflineNotice();
        },
      ),
    );
  }
}