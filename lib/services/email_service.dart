import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../models/mandi_models.dart';

class EmailService {
  // EmailJS configuration
  static const String _serviceId = 'service_bdcncug';
  static const String _templateId = 'template_4rjewrk';
  static const String _publicKey = 'lmZzEDt3RQ2m1Ojhq';

  /// Sends a 6-digit OTP to the user's Gmail address via EmailJS.
  static Future<bool> sendOtpEmail({
    required String recipientEmail,
    required String recipientName,
    required String otp,
    required String purpose,
  }) async {
    final cleanEmail = recipientEmail.trim().toLowerCase();
    final cleanName =
        recipientName.trim().isEmpty ? 'Member' : recipientName.trim();
    final cleanOtp = otp.trim();
    final cleanPurpose = purpose.trim();

    if (cleanEmail.isEmpty || !cleanEmail.contains('@')) {
      debugPrint('EmailService Error: Invalid recipient email "$cleanEmail"');
      return false;
    }

    final url = Uri.parse('https://api.emailjs.com/api/v1.0/email/send');

    // Headers compatible across Web, Android Release APK & iOS
    final Map<String, String> headers = {
      'Content-Type': 'application/json',
      'origin':
          'http://localhost', // Essential for EmailJS to accept mobile requests
    };

    final Map<String, dynamic> payload = {
      'service_id': _serviceId,
      'template_id': _templateId,
      'user_id': _publicKey,
      'template_params': {
        'to_name': cleanName,
        'to_email': cleanEmail,
        'otp': cleanOtp,
        'purpose': cleanPurpose,
        'app_name': kAppName,
      },
    };

    try {
      final response = await http
          .post(url, headers: headers, body: jsonEncode(payload))
          .timeout(const Duration(seconds: 15));

      debugPrint(
          'EmailJS status: ${response.statusCode} | body: ${response.body}');

      if (response.statusCode == 200) {
        return true;
      } else {
        debugPrint(
            '❌ EmailJS API rejected request: HTTP ${response.statusCode} - ${response.body}');
        return false;
      }
    } catch (e) {
      debugPrint(
          '❌ EmailJS network exception (Check AndroidManifest internet permission): $e');
      return false;
    }
  }
}
