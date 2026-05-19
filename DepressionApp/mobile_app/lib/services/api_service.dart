import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

class ApiService {

  // =====================================================
  // 🔴 CHANGE THIS WHEN BACKEND IP CHANGES
  // =====================================================

  static const String baseUrl =
      "http://172.20.10.9:8000";

  // =====================================================
  // REQUEST TIMEOUT
  // =====================================================

  static const Duration timeout =
      Duration(seconds: 30);

  // =====================================================
  // 📸 INSTAGRAM NLP ANALYSIS
  // =====================================================

  static Future<Map<String, dynamic>>
      getInstagramScore(String username) async {

    try {

      var request = http.MultipartRequest(

        'POST',

        Uri.parse(
          "$baseUrl/instagram_analysis",
        ),
      );

      request.fields['username'] =
          username;

      request.fields['limit'] =
          '5';

      var response =
          await request.send()
              .timeout(timeout);

      if (response.statusCode == 200) {

        return jsonDecode(

          await response.stream
              .bytesToString(),
        );

      } else {

        throw Exception(
          'Instagram API error',
        );
      }

    } catch (e) {

      print(
        "Instagram API error: $e",
      );

      return {

        'avg_text_score': 50.0
      };
    }
  }

  // =====================================================
  // 🎥 UNIFIED MULTIMODAL SCORE
  // =====================================================

  static Future<Map<String, dynamic>>
      getUnifiedScoreWithVideo(

    Map<String, dynamic> usage,

    double textScore,

    List<File> frames,

  ) async {

    try {

      if (frames.isEmpty) {

        throw Exception(
          "No video frames available",
        );
      }

      var request = http.MultipartRequest(

        'POST',

        Uri.parse(
          "$baseUrl/predict",
        ),
      );

      // =================================================
      // PHONE BEHAVIOR DATA
      // =================================================

      request.fields["screen_time"] =

          usage["screen_time"]
              .toString();

      request.fields["night_usage"] =

          usage["night_usage"]
              .toString();

      request.fields["social_media_hours"] =

          usage["social_media_hours"]
              .toString();

      request.fields["unlock_count"] =

          usage["unlock_count"]
              .toString();

      // =================================================
      // TEXT SCORE
      // =================================================

      request.fields["text_score"] =

          textScore.toString();

      // =================================================
      // ATTACH VIDEO FRAMES
      // =================================================

      for (var frame in frames) {

        request.files.add(

          await http.MultipartFile
              .fromPath(

            'files',

            frame.path,
          ),
        );
      }

      // =================================================
      // SEND REQUEST
      // =================================================

      var streamedResponse =

          await request.send()
              .timeout(timeout);

      if (streamedResponse.statusCode != 200) {

        throw Exception(

          "Unified API failed "
          "(${streamedResponse.statusCode})",
        );
      }

      var responseData =

          await streamedResponse.stream
              .bytesToString();

      final decoded =
          jsonDecode(responseData);

      print(
        "Unified API Response: $decoded",
      );

      return decoded;

    } catch (e) {

      print(
        "Unified Video Error: $e",
      );

      throw Exception(
        "Unified Video Score Error: $e",
      );
    }
  }

  // =====================================================
  // 📝 TEXT ANALYSIS
  // =====================================================

  static Future<Map<String, dynamic>>
      analyzeText(String text) async {

    try {

      if (text.trim().isEmpty) {

        throw Exception(
          "Text cannot be empty",
        );
      }

      var request = http.MultipartRequest(

        "POST",

        Uri.parse(
          "$baseUrl/text",
        ),
      );

      request.fields["text"] =
          text;

      var streamedResponse =

          await request.send()
              .timeout(timeout);

      if (streamedResponse.statusCode != 200) {

        throw Exception(

          "Text API failed "
          "(${streamedResponse.statusCode})",
        );
      }

      var responseData =

          await streamedResponse.stream
              .bytesToString();

      final decoded =
          jsonDecode(responseData);

      print(
        "Text API Response: $decoded",
      );

      return decoded;

    } catch (e) {

      print(
        "Text API Error: $e",
      );

      throw Exception(
        "Text Analysis Error: $e",
      );
    }
  }

  // =====================================================
  // 🧠 XAI EXPLANATION
  // =====================================================

  static Future<Map<String, dynamic>>
      getExplanation(
    double screenTime,
  ) async {

    try {

      final response = await http.post(

        Uri.parse(
          "$baseUrl/explain",
        ),

        headers: {

          "Content-Type":
              "application/json"
        },

        body: jsonEncode({

          "screen_time":
              screenTime
        }),
      ).timeout(timeout);

      if (response.statusCode == 200) {

        return jsonDecode(
          response.body,
        );

      } else {

        throw Exception(

          "Explain API failed: "
          "${response.statusCode}",
        );
      }

    } catch (e) {

      print(
        "XAI Error: $e",
      );

      throw Exception(
        "Explanation Error: $e",
      );
    }
  }

  // =====================================================
  // 🤖 AGENTIC AI
  // =====================================================

  static Future<Map<String, dynamic>>
      getAgentic(

    Map<String, dynamic> scores,

  ) async {

    try {

      final response = await http.post(

        Uri.parse(
          "$baseUrl/agentic",
        ),

        headers: {

          "Content-Type":
              "application/json"
        },

        body: jsonEncode(scores),
      ).timeout(timeout);

      if (response.statusCode == 200) {

        return jsonDecode(
          response.body,
        );

      } else {

        throw Exception(

          "Agentic API failed: "
          "${response.statusCode}",
        );
      }

    } catch (e) {

      print(
        "Agentic Error: $e",
      );

      return {

        "agentic_ai":

            "Unable to generate "
            "personalized advice "
            "at this time."
      };
    }
  }
}