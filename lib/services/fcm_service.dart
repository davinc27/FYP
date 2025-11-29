// services/fcm_service.dart
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter/material.dart';
import 'dart:io';
import 'dart:developer' as developer;

class FCMService {
  static final FirebaseMessaging _firebaseMessaging =
      FirebaseMessaging.instance;
  static final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();
  static String? _fcmToken;
  static bool _isInitialized = false;

  // Get FCM token
  static String? get fcmToken => _fcmToken;

  // Initialize FCM
  static Future<void> initialize() async {
    if (_isInitialized) {
      print('✅ FCM Service already initialized');
      return;
    }

    try {
      print('🔥 Starting FCM initialization...');

      // Initialize local notifications first
      await _initializeLocalNotifications();

      // Get FCM token first (faster than requesting permission)
      print('🔑 Getting FCM token...');
      _fcmToken = await _firebaseMessaging.getToken();
      print('🎯 FCM Token: $_fcmToken');

      // Request permission for notifications (async, don't wait)
      print('🔔 Requesting notification permissions...');
      _requestPermissionAsync();

      // Listen for token refresh
      _firebaseMessaging.onTokenRefresh.listen((String token) {
        _fcmToken = token;
        print('🔄 FCM Token refreshed: $token');
        // TODO: Send updated token to your server
      });

      // Set up message handlers
      print('📱 Setting up message handlers...');
      _setupMessageHandlers();

      _isInitialized = true;
      print('✅ FCM Service initialized successfully');
    } catch (e) {
      print('❌ Error initializing FCM: $e');
      developer.log('Error initializing FCM: $e');
    }
  }

  // Request permission asynchronously to avoid blocking startup
  static void _requestPermissionAsync() async {
    try {
      print('🔔 Requesting notification permissions...');

      // Request FCM permissions
      NotificationSettings settings = await _firebaseMessaging
          .requestPermission(
            alert: true,
            announcement: false,
            badge: true,
            carPlay: false,
            criticalAlert: false,
            provisional: false,
            sound: true,
          );

      print('✅ FCM permission: ${settings.authorizationStatus}');

      // Request local notification permissions for Android
      if (Platform.isAndroid) {
        final bool? result =
            await _localNotifications
                .resolvePlatformSpecificImplementation<
                  AndroidFlutterLocalNotificationsPlugin
                >()
                ?.requestNotificationsPermission();

        print('✅ Local notification permission: $result');
      }

      developer.log('User granted permission: ${settings.authorizationStatus}');
    } catch (e) {
      print('❌ Error requesting notification permission: $e');
      developer.log('Error requesting notification permission: $e');
    }
  }

  // Set up message handlers
  static void _setupMessageHandlers() {
    // Handle messages when app is in foreground
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      developer.log('Got a message whilst in the foreground!');
      developer.log('Message data: ${message.data}');

      if (message.notification != null) {
        developer.log(
          'Message also contained a notification: ${message.notification}',
        );
        // TODO: Show local notification or in-app notification
        _showInAppNotification(message);
      }
    });

    // Handle messages when app is opened from background
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      developer.log('A new onMessageOpenedApp event was published!');
      developer.log('Message data: ${message.data}');
      // TODO: Navigate to specific screen based on message data
    });
  }

  // Initialize local notifications
  static Future<void> _initializeLocalNotifications() async {
    try {
      const AndroidInitializationSettings initializationSettingsAndroid =
          AndroidInitializationSettings('@mipmap/ic_launcher');

      const DarwinInitializationSettings initializationSettingsIOS =
          DarwinInitializationSettings(
            requestAlertPermission: true,
            requestBadgePermission: true,
            requestSoundPermission: true,
          );

      const InitializationSettings initializationSettings =
          InitializationSettings(
            android: initializationSettingsAndroid,
            iOS: initializationSettingsIOS,
          );

      await _localNotifications.initialize(
        initializationSettings,
        onDidReceiveNotificationResponse: _onNotificationTapped,
      );

      // Create notification channel for Android
      await _createNotificationChannel();

      print('✅ Local notifications initialized');
    } catch (e) {
      print('❌ Error initializing local notifications: $e');
    }
  }

  // Create notification channel for Android
  static Future<void> _createNotificationChannel() async {
    try {
      const AndroidNotificationChannel channel = AndroidNotificationChannel(
        'terra_alerts',
        'Terra Plant Alerts',
        description: 'Notifications for plant alerts and monitoring',
        importance: Importance.high,
        playSound: true,
        enableVibration: true,
        showBadge: true,
      );

      await _localNotifications
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >()
          ?.createNotificationChannel(channel);

      print('✅ Notification channel created');
    } catch (e) {
      print('❌ Error creating notification channel: $e');
    }
  }

  // Handle notification tap
  static void _onNotificationTapped(NotificationResponse response) {
    developer.log('Notification tapped: ${response.payload}');
    // TODO: Navigate to specific screen based on payload
  }

  // Show local notification
  static Future<void> showLocalNotification({
    required int id,
    required String title,
    required String body,
    String? payload,
  }) async {
    try {
      // Check if local notifications are initialized
      if (!_isInitialized) {
        developer.log(
          'Local notifications not initialized, initializing now...',
        );
        await _initializeLocalNotifications();
      }

      const AndroidNotificationDetails androidDetails =
          AndroidNotificationDetails(
            'terra_alerts',
            'Terra Plant Alerts',
            channelDescription: 'Notifications for plant alerts and monitoring',
            importance: Importance.high,
            priority: Priority.high,
            icon: '@mipmap/ic_launcher',
            color: Color(0xFF4CAF50), // Green color for plant theme
            playSound: true,
            enableVibration: true,
            showWhen: true,
          );

      const DarwinNotificationDetails iOSDetails = DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      );

      const NotificationDetails platformDetails = NotificationDetails(
        android: androidDetails,
        iOS: iOSDetails,
      );

      await _localNotifications.show(
        id,
        title,
        body,
        platformDetails,
        payload: payload,
      );

      developer.log('Local notification shown: $title');
    } catch (e) {
      developer.log('Error showing local notification: $e');
      // Try to reinitialize and show again
      try {
        await _initializeLocalNotifications();
        await _localNotifications.show(
          id,
          title,
          body,
          const NotificationDetails(
            android: AndroidNotificationDetails(
              'terra_alerts',
              'Terra Plant Alerts',
              channelDescription:
                  'Notifications for plant alerts and monitoring',
              importance: Importance.high,
              priority: Priority.high,
            ),
          ),
          payload: payload,
        );
        developer.log(
          'Local notification shown after reinitialization: $title',
        );
      } catch (e2) {
        developer.log(
          'Error showing local notification after reinitialization: $e2',
        );
      }
    }
  }

  // Show in-app notification (enhanced version)
  static void _showInAppNotification(RemoteMessage message) {
    developer.log(
      'Showing in-app notification: ${message.notification?.title}',
    );

    // Show local notification for better visibility
    showLocalNotification(
      id: DateTime.now().millisecondsSinceEpoch ~/ 1000,
      title: message.notification?.title ?? 'Terra Alert',
      body: message.notification?.body ?? 'Plant alert notification',
      payload: message.data.toString(),
    );
  }

  // Subscribe to a topic
  static Future<void> subscribeToTopic(String topic) async {
    try {
      await _firebaseMessaging.subscribeToTopic(topic);
      developer.log('Subscribed to topic: $topic');
    } catch (e) {
      developer.log('Error subscribing to topic $topic: $e');
    }
  }

  // Unsubscribe from a topic
  static Future<void> unsubscribeFromTopic(String topic) async {
    try {
      await _firebaseMessaging.unsubscribeFromTopic(topic);
      developer.log('Unsubscribed from topic: $topic');
    } catch (e) {
      developer.log('Error unsubscribing from topic $topic: $e');
    }
  }

  // Get initial message (when app is opened from terminated state)
  static Future<RemoteMessage?> getInitialMessage() async {
    return await _firebaseMessaging.getInitialMessage();
  }

  // Send token to server (implement based on your backend)
  static Future<void> sendTokenToServer(String token) async {
    try {
      // TODO: Implement API call to send token to your server
      developer.log('Sending FCM token to server: $token');
      // Example:
      // await ApiService.updateFCMToken(token);
    } catch (e) {
      developer.log('Error sending token to server: $e');
    }
  }

  // Check if notifications are enabled
  static Future<bool> areNotificationsEnabled() async {
    try {
      NotificationSettings settings =
          await _firebaseMessaging.getNotificationSettings();
      return settings.authorizationStatus == AuthorizationStatus.authorized;
    } catch (e) {
      developer.log('Error checking notification status: $e');
      return false;
    }
  }

  // Request notification permission
  static Future<bool> requestNotificationPermission() async {
    try {
      NotificationSettings settings = await _firebaseMessaging
          .requestPermission(
            alert: true,
            announcement: false,
            badge: true,
            carPlay: false,
            criticalAlert: false,
            provisional: false,
            sound: true,
          );

      bool isAuthorized =
          settings.authorizationStatus == AuthorizationStatus.authorized;
      developer.log('Notification permission granted: $isAuthorized');
      return isAuthorized;
    } catch (e) {
      developer.log('Error requesting notification permission: $e');
      return false;
    }
  }

  // Check if notifications are enabled
  static Future<bool> areLocalNotificationsEnabled() async {
    try {
      if (Platform.isAndroid) {
        final bool? result =
            await _localNotifications
                .resolvePlatformSpecificImplementation<
                  AndroidFlutterLocalNotificationsPlugin
                >()
                ?.areNotificationsEnabled();
        return result ?? false;
      }
      return true; // iOS doesn't need explicit check
    } catch (e) {
      print('Error checking local notification status: $e');
      return false;
    }
  }
}
