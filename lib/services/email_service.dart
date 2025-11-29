// services/email_service.dart
import 'dart:developer' as developer;

class EmailService {
  // Placeholder for email notification service
  // This will be implemented later when you decide on the email service provider

  static bool _isInitialized = false;

  // Initialize email service
  static Future<void> initialize() async {
    if (_isInitialized) {
      developer.log('Email Service already initialized');
      return;
    }

    try {
      // TODO: Initialize email service (SendGrid, AWS SES, etc.)
      developer.log('Email Service initialized (placeholder)');
      _isInitialized = true;
    } catch (e) {
      developer.log('Error initializing Email Service: $e');
    }
  }

  // Send email notification
  static Future<bool> sendEmailNotification({
    required String recipientEmail,
    required String subject,
    required String body,
    String? htmlBody,
  }) async {
    try {
      developer.log('Sending email notification to: $recipientEmail');
      developer.log('Subject: $subject');

      // TODO: Implement actual email sending logic
      // This could use:
      // - SendGrid API
      // - AWS SES
      // - Firebase Functions with email service
      // - Other email service providers

      // Placeholder implementation
      await Future.delayed(Duration(seconds: 1)); // Simulate API call

      developer.log('Email notification sent successfully');
      return true;
    } catch (e) {
      developer.log('Error sending email notification: $e');
      return false;
    }
  }

  // Send plant alert email
  static Future<bool> sendPlantAlertEmail({
    required String recipientEmail,
    required String basketId,
    required String alertType,
    required String message,
    required String severity,
  }) async {
    try {
      String subject =
          'Terra Alert: $alertType - ${_formatBasketName(basketId)}';
      String body = '''
Hello,

You have received a plant alert from Terra:

Alert Type: $alertType
Basket: ${_formatBasketName(basketId)}
Severity: ${severity.toUpperCase()}
Message: $message

Please check your Terra app for more details.

Best regards,
Terra Team
      ''';

      String htmlBody = '''
<html>
<body>
  <h2>Terra Plant Alert</h2>
  <p><strong>Alert Type:</strong> $alertType</p>
  <p><strong>Basket:</strong> ${_formatBasketName(basketId)}</p>
  <p><strong>Severity:</strong> <span style="color: ${_getSeverityColor(severity)}">${severity.toUpperCase()}</span></p>
  <p><strong>Message:</strong> $message</p>
  <br>
  <p>Please check your Terra app for more details.</p>
  <br>
  <p>Best regards,<br>Terra Team</p>
</body>
</html>
      ''';

      return await sendEmailNotification(
        recipientEmail: recipientEmail,
        subject: subject,
        body: body,
        htmlBody: htmlBody,
      );
    } catch (e) {
      developer.log('Error sending plant alert email: $e');
      return false;
    }
  }

  // Helper method to format basket name
  static String _formatBasketName(String basketId) {
    if (basketId.startsWith('basket')) {
      final number = basketId.substring(6);
      return 'Basket $number';
    }
    return basketId;
  }

  // Helper method to get severity color for HTML
  static String _getSeverityColor(String severity) {
    switch (severity.toLowerCase()) {
      case 'critical':
        return 'red';
      case 'warning':
        return 'orange';
      case 'info':
        return 'blue';
      default:
        return 'black';
    }
  }

  // Check if email service is available
  static bool get isAvailable => _isInitialized;

  // Get service status
  static Map<String, dynamic> getServiceStatus() {
    return {
      'isInitialized': _isInitialized,
      'isAvailable': isAvailable,
      'serviceName': 'Email Service (Placeholder)',
    };
  }
}
