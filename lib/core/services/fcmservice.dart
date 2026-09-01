import 'dart:convert';
import 'dart:developer' show log;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:hooper/screens/chat_screen.dart';

class FCMService {
  static final FCMService _instance = FCMService._internal();
  factory FCMService() => _instance;
  FCMService._internal();

  final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _localNotificationsPlugin = FlutterLocalNotificationsPlugin();

  Future<void> init() async {
    await _messaging.requestPermission(alert: true, badge: true, sound: true);

    const AndroidInitializationSettings initializationSettingsAndroid = AndroidInitializationSettings(
      '@mipmap/ic_launcher',
    );
    const DarwinInitializationSettings initializationSettingsDarwin = DarwinInitializationSettings();

    const InitializationSettings initializationSettings = InitializationSettings(
      android: initializationSettingsAndroid,
      iOS: initializationSettingsDarwin,
    );

    await _localNotificationsPlugin.initialize(
      settings: initializationSettings,
      onDidReceiveNotificationResponse: (NotificationResponse response) {
        if (response.payload != null) {
          try {
            final Map<String, dynamic> data = jsonDecode(response.payload!);
            _handleNotificationTap(data);
          } catch (e) {
            log("Error decoding notification payload: $e");
          }
        }
      },
    );

    final initialMessage = await FirebaseMessaging.instance.getInitialMessage();
    if (initialMessage != null) {
      _handleNotificationTap(initialMessage.data);
    }

    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      _localNotificationsPlugin.show(
        id: message.hashCode,
        title: message.notification?.title,
        body: message.notification?.body,
        notificationDetails: const NotificationDetails(
          android: AndroidNotificationDetails('default_channel', 'Notifications'),
          iOS: DarwinNotificationDetails(),
        ),
        payload: jsonEncode(message.data),
      );
    });

    await FirebaseMessaging.instance.setForegroundNotificationPresentationOptions(
      alert: true,
      badge: true,
      sound: true,
    );

    FirebaseMessaging.onMessageOpenedApp.listen((message) {
      _handleNotificationTap(message.data);
    });
  }

  final navigatorKey = GlobalKey<NavigatorState>();

  void _handleNotificationTap(Map<String, dynamic> data) {
    if (data['type'] == 'chat_message' || data['type'] == 'match_request') {
      navigatorKey.currentState?.push(MaterialPageRoute(builder: (_) => ChatScreen(chatId: data['chatId'])));
    }
  }

  Future<void> registerFcmToken(String uid) async {
    final token = await FirebaseMessaging.instance.getToken();
    if (token == null) return;
    await FirebaseFirestore.instance.collection('playerProfiles').doc(uid).update({
      'fcmTokens': FieldValue.arrayUnion([token]),
    });

    FirebaseMessaging.instance.onTokenRefresh.listen((newToken) {
      FirebaseFirestore.instance.collection('playerProfiles').doc(uid).update({
        'fcmTokens': FieldValue.arrayUnion([newToken]),
      });
    });
  }

  Future<String?> getToken() async {
    return await _messaging.getToken();
  }
}
