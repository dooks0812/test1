import 'dart:convert';
import 'package:http/http.dart' as http;

/// EmailJS service for MOBILE (Android/iOS)
class EmailJsService {
  static const String serviceId = "service_zwfrz3y";
  static const String templateId = "template_b0hsty6";
  static const String publicKey = "uAPxBLjvp9Nc3o-LI";

  static const String _endpoint = "https://api.emailjs.com/api/v1.0/email/send";

  /// Returns (ok, debugText)
  static Future<(bool ok, String debug)> sendStatusEmail({
    required String toEmail,
    required String toName,
    required String subject,
    required String message,
    required String bookingId,
    required String bookingDate,
    required String bookingTime,
    required String status,
  }) async {
    final payload = <String, dynamic>{
      "service_id": serviceId,
      "template_id": templateId,

      // keep user_id as EmailJS expects
      "user_id": publicKey,

      "template_params": {
        "to_email": toEmail,
        "to_name": toName,
        "subject": subject,
        "message": message,
        "booking_id": bookingId,
        "booking_date": bookingDate,
        "booking_time": bookingTime,
        "status": status,
      }
    };

    try {
      final res = await http.post(
        Uri.parse(_endpoint),
        headers: const {"Content-Type": "application/json"},
        body: jsonEncode(payload),
      );

      final debug =
          "status=${res.statusCode}\nbody=${res.body.isEmpty ? '(empty)' : res.body}";

      final ok = res.statusCode >= 200 && res.statusCode < 300;
      return (ok, debug);
    } catch (e) {
      return (false, "exception=$e");
    }
  }
}
