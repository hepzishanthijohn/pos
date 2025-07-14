// import 'dart:convert';
// import 'package:firebase_messaging/firebase_messaging.dart';
// import 'package:flutter_local_notifications/flutter_local_notifications.dart';

// class Firebaseapii {
//   final _firebasemessageapi = FirebaseMessaging.instance;

//   final _androidChannel = const AndroidNotificationChannel(
//     'high_importance_channel',
//     'High Importance Notifications',
//     description: 'This channel is used for important notifications',
//     importance: Importance.high,
//   );

//   final _localNotifications = FlutterLocalNotificationsPlugin();

//   Future<void> initmessage() async {
//     await _firebasemessageapi.requestPermission();
//     await Future.delayed(const Duration(seconds: 1));

//     await _firebasemessageapi.subscribeToTopic("rcspos");

//     await ininitPushNotification();
//     await initLocalNotifications();
//   }

//   Future<void> myBackgroundHandler(RemoteMessage message) async {
//     // Handle background messages if needed
//   }

//   Future<void> ininitPushNotification() async {
//     await FirebaseMessaging.instance.setForegroundNotificationPresentationOptions(
//       alert: true,
//       badge: true,
//       sound: true,
//     );

//     FirebaseMessaging.instance.getInitialMessage().then(handleMessage);
//     FirebaseMessaging.onMessageOpenedApp.listen(handleMessage);

//     FirebaseMessaging.onMessage.listen((message) {
//       final notification = message.notification;
//       if (notification == null) return;

//       _localNotifications.show(
//         notification.hashCode,
//         notification.title,
//         notification.body,
//         NotificationDetails(
//           android: AndroidNotificationDetails(
//             _androidChannel.id,
//             _androidChannel.name,
//             channelDescription: _androidChannel.description,
//             icon: "@mipmap/ic_launcher",
//           ),
//         ),
//         payload: jsonEncode(message.toMap()),
//       );
//     });
//   }

//   void handleMessage(RemoteMessage? message) {
//     if (message == null) return;
//     // Handle navigation or other logic here
//   }

//   Future<void> initLocalNotifications() async {
//     const android = AndroidInitializationSettings("@mipmap/ic_launcher");

//     const settings = InitializationSettings(android: android);

//     await _localNotifications.initialize(
//       settings,
//       onDidReceiveNotificationResponse: (NotificationResponse response) {
//         final String? payload = response.payload;
//         if (payload != null) {
//           final message = RemoteMessage.fromMap(jsonDecode(payload));
//           handleMessage(message);
//         }
//       },
//     );

//     final platform = _localNotifications.resolvePlatformSpecificImplementation<
//         AndroidFlutterLocalNotificationsPlugin>();
//     await platform?.createNotificationChannel(_androidChannel);
//   }
// }
