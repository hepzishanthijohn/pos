
import 'dart:convert';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
class Firebaseapii{
 final _firebasemessageapi= FirebaseMessaging.instance;
 final _androidChannel =const AndroidNotificationChannel('high_importance_channel', 'High Imortance Notifications',description: 'This chammel is used for important notification',importance: Importance.defaultImportance);
 final _localNotifications = FlutterLocalNotificationsPlugin();
 Future<void> initmessage() async{
   await _firebasemessageapi.requestPermission();
   await Future.delayed(Duration(seconds: 1));
   var token = await _firebasemessageapi.getAPNSToken();
   
   await _firebasemessageapi.subscribeToTopic("rcspos");
  
 
  ininitPushNotification();
  initLocalNotifications();
 }
 Future<void> myBackgroundHandler(RemoteMessage message) async {
}
Future ininitPushNotification () async{
 await FirebaseMessaging.instance.setForegroundNotificationPresentationOptions(
   alert: true,
   badge: true,
   sound: true,
 );
 FirebaseMessaging.instance.getInitialMessage().then(handleMessage);
 FirebaseMessaging.onMessageOpenedApp.listen(handleMessage);
 FirebaseMessaging.onMessage.listen((message){
     final notification=message.notification;
     if(notification== null) return;
     _localNotifications.show(notification.hashCode, notification.title, notification.body, NotificationDetails(
         android: AndroidNotificationDetails(_androidChannel.id,_androidChannel.name,
         channelDescription: _androidChannel.description,
        //  enableVibration: true,
        icon: "@drawable/ic_launcher"
 
         )
     ),
     payload: jsonEncode(message.toMap()),
    
     );
 });
}
void handleMessage(RemoteMessage? message){
if(message==null) return;
}


Future initLocalNotifications()async{
 const android =AndroidInitializationSettings("drawable/ic_launcher");
 const settings=InitializationSettings(android: android);
 await _localNotifications.initialize(settings, onDidReceiveNotificationResponse: (payload){
   final message=RemoteMessage.fromMap(jsonDecode(payload as String));
   handleMessage(message);
 } );
 final platform =_localNotifications.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
 await platform?.createNotificationChannel(_androidChannel);
}


}