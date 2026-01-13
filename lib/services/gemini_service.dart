import 'dart:io';
import 'dart:convert';
import 'package:google_generative_ai/google_generative_ai.dart';
import '../models/session.dart';

class GeminiService {
  static const _apiKey = 'AIzaSyDqfodBwAy6sgS0xuDSgpPd-Tqu7whHBwI';
  
  static Future<MockSession> analyzeVideo(File videoFile, int durationSeconds) async {
    final model = GenerativeModel(
      model: 'gemini-2.5-flash',
      apiKey: _apiKey,
      safetySettings: [
        SafetySetting(HarmCategory.harassment, HarmBlockThreshold.none),
        SafetySetting(HarmCategory.hateSpeech, HarmBlockThreshold.none),
        SafetySetting(HarmCategory.sexuallyExplicit, HarmBlockThreshold.none),
        SafetySetting(HarmCategory.dangerousContent, HarmBlockThreshold.none),
      ],
    );

    final fileSize = await videoFile.length();
    print('📂 Reading video file: ${videoFile.path} (${(fileSize / 1024 / 1024).toStringAsFixed(2)} MB)');
    final videoBytes = await videoFile.readAsBytes();
    
    final prompt = [
      Content.multi([
        TextPart("""
          You are a professional interview coach. Analyze this mock interview video.
          Evaluate the user's performance on the following criteria on a scale of 0-100:
          1. Eye Contact (Did they look at the camera?)
          2. Face Presence (Was their face clear and centered?)
          3. Smile & Expression (Did they look friendly and professional?)
          4. Confidence (Head stability and tone)
          5. Content Quality (Did they answer effectively?)

          Return ONLY a JSON object with these keys:
          - totalScore (average of all criteria)
          - eyeContactPct
          - facePresencePct
          - smilePct
          - headStability (meaning confidence/professionalism)
          - tips (provide exactly 5 specific, high-quality coaching tips based on what you saw and heard)
        """),
        DataPart('video/mp4', videoBytes),
      ]),
    ];

    try {
      print('🚀 Sending video to Gemini (${(videoBytes.length / 1024 / 1024).toStringAsFixed(2)} MB)...');
      print('⏳ This can take 1-3 minutes depending on your internet upload speed.');
      
      // Adding a longer timeout (5 minutes) for larger video files
      final response = await model.generateContent(prompt).timeout(
        const Duration(seconds: 300),
        onTimeout: () => throw Exception('Gemini analysis timed out after 5 minutes. The video file might be too large or your internet upload speed is slow.'),
      );
      
      final text = response.text;
      
      print('📩 Gemini Response received');
      if (text == null) {
        print('❌ Empty response from Gemini');
        throw Exception('Empty response from Gemini');
      }
      
      print('📝 Raw Response: $text');
      
      // Clean up the response to extract JSON
      final jsonString = _extractJson(text);
      print('📦 Extracted JSON: $jsonString');
      
      final Map<String, dynamic> data = jsonDecode(jsonString);

      return MockSession(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        createdAt: DateTime.now(),
        durationSeconds: durationSeconds, 
        facePresencePct: (data['facePresencePct'] as num).toDouble(),
        eyeContactPct: (data['eyeContactPct'] as num).toDouble(),
        smilePct: (data['smilePct'] as num).toDouble(),
        headStability: (data['headStability'] as num).toDouble(),
        totalScore: (data['totalScore'] as num).toDouble(),
        tips: List<String>.from(data['tips']),
      );
    } catch (e) {
      print('❌ ERROR in GeminiService: $e');
      if (e is GenerativeAIException) {
        print('🚫 GenerativeAIException details: ${e.message}');
      }
      rethrow;
    }
  }

  static String _extractJson(String text) {
    // Look for markdown code blocks first
    final codeBlockMatch = RegExp(r'```json\s*([\s\S]*?)\s*```').firstMatch(text);
    if (codeBlockMatch != null) {
      return codeBlockMatch.group(1)!;
    }
    
    // Fallback to finding the first { and last }
    final start = text.indexOf('{');
    final end = text.lastIndexOf('}');
    if (start == -1 || end == -1) return text;
    return text.substring(start, end + 1);
  }
}
