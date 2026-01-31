import 'dart:io';
import 'dart:convert';
import 'package:google_generative_ai/google_generative_ai.dart';
import '../models/session.dart';
import '../secrets.dart';

class GeminiService {
  // IMPORTANT: This key is now local. For production, use --dart-define=GEMINI_API_KEY=your_key
  static const _apiKey = String.fromEnvironment(
    'GEMINI_API_KEY',
    defaultValue: geminiApiKey,
  );
  
  static final _model = GenerativeModel(
    model: 'gemini-2.5-flash',
    apiKey: _apiKey,
    safetySettings: [
      SafetySetting(HarmCategory.harassment, HarmBlockThreshold.none),
      SafetySetting(HarmCategory.hateSpeech, HarmBlockThreshold.none),
      SafetySetting(HarmCategory.sexuallyExplicit, HarmBlockThreshold.none),
      SafetySetting(HarmCategory.dangerousContent, HarmBlockThreshold.none),
    ],
  );

  static Future<T> _retryWithBackoff<T>(Future<T> Function() operation, {int maxRetries = 3}) async {
    for (int i = 0; i < maxRetries; i++) {
      try {
        return await operation();
      } catch (e) {
        if (i == maxRetries - 1) rethrow;
        final delay = Duration(seconds: (1 << i)); // 1, 2, 4 seconds
        print('⚠️ API Busy/Error, retrying in ${delay.inSeconds}s... (Attempt ${i + 1}/$maxRetries)');
        await Future.delayed(delay);
      }
    }
    throw Exception('Failed after $maxRetries retries');
  }

  static Future<String> generateQuestion({String? jobDescription, String? role}) async {
    final prompt = """
      You are an expert interviewer. 
      ${jobDescription != null ? "Based on this job description: $jobDescription" : ""}
      ${role != null ? "For the role of: $role" : ""}
      Generate one challenging, realistic interview question.
      Return ONLY the question text.
    """;

    try {
      final content = [Content.text(prompt)];
      return await _retryWithBackoff(() async {
        final response = await _model.generateContent(content);
        return response.text?.trim() ?? "Tell me about a difficult challenge you faced and how you handled it.";
      });
    } catch (e) {
      print('Error generating question: $e');
      return "Tell me about yourself and your background.";
    }
  }

  static Future<MockSession> analyzeVideo(File videoFile, int durationSeconds, {String? questionAsked}) async {
    return _analyzeVideoInternal(videoFile, durationSeconds, questionAsked: questionAsked);
  }

  static Future<MockSession> analyzeUploadedVideo(File videoFile, int durationSeconds, {String? questionAsked}) async {
    return _analyzeVideoInternal(videoFile, durationSeconds, questionAsked: questionAsked);
  }

  static Future<MockSession> _analyzeVideoInternal(File videoFile, int durationSeconds, {String? questionAsked}) async {
    final fileSize = await videoFile.length();
    print('📂 Reading video file: ${videoFile.path} (${(fileSize / 1024 / 1024).toStringAsFixed(2)} MB)');
    final videoBytes = await videoFile.readAsBytes();
    
    final prompt = [
      Content.multi([
        TextPart("""
          You are a professional interview coach. Analyze this mock interview video.
          ${questionAsked != null ? "The user was answering this question: $questionAsked" : ""}
          
          Evaluate the user's performance on the following criteria on a scale of 0-100:
          1. Eye Contact (Did they look at the camera?)
          2. Face Presence (Was their face clear and centered?)
          3. Smile & Expression (Did they look friendly and professional?)
          4. Confidence (Head stability and tone)
          5. Content Quality (Did they answer effectively?)

          Also provide:
          - A full transcript of what they said.
          - The number of filler words used (um, uh, like, etc.).
          - A brief sentiment analysis of their tone (e.g., Confident, Hesitant, Enthusiastic, Monotone).

          Return ONLY a JSON object with these keys:
          - totalScore (average of all criteria)
          - eyeContactPct
          - facePresencePct
          - smilePct
          - headStability (meaning confidence/professionalism)
          - tips (provide exactly 5 specific, high-quality coaching tips)
          - transcript (full text)
          - fillerWordsCount (integer)
          - sentiment (1-2 words describing tone)
        """),
        DataPart('video/mp4', videoBytes),
      ]),
    ];

    try {
      print('🚀 Sending video to Gemini...');
      
      return await _retryWithBackoff(() async {
        final response = await _model.generateContent(prompt).timeout(
          const Duration(seconds: 300),
          onTimeout: () => throw Exception('Gemini analysis timed out after 5 minutes.'),
        );
        
        final text = response.text;
        if (text == null) throw Exception('Empty response from Gemini');
        
        final jsonString = _extractJson(text);
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
          transcript: data['transcript'],
          fillerWordsCount: data['fillerWordsCount'],
          sentiment: data['sentiment'],
          questionAsked: questionAsked,
        );
      });
    } catch (e) {
      print('❌ ERROR in GeminiService: $e');
      rethrow;
    }
  }

  static Future<List<String>> generateQuestionsFromCV(File cvFile) async {
    try {
      print('📄 Reading CV file: ${cvFile.path}');
      final cvBytes = await cvFile.readAsBytes();
      final fileExtension = cvFile.path.split('.').last.toLowerCase();
      
      String mimeType;
      if (fileExtension == 'pdf') {
        mimeType = 'application/pdf';
      } else if (fileExtension == 'txt') {
        mimeType = 'text/plain';
      } else if (fileExtension == 'doc' || fileExtension == 'docx') {
        mimeType = 'application/vnd.openxmlformats-officedocument.wordprocessingml.document';
      } else {
        throw Exception('Unsupported file format: $fileExtension');
      }

      final prompt = [
        Content.multi([
          TextPart("""
            You are an expert technical interviewer. Analyze this CV/Resume and generate 5 challenging, 
            role-specific interview questions based on the candidate's experience, skills, and background.
            
            The questions should:
            1. Be specific to their listed experience and projects
            2. Test both technical depth and practical application
            3. Be realistic questions an interviewer would actually ask
            4. Cover different aspects (technical skills, past projects, problem-solving, etc.)
            
            Return ONLY a JSON object with this structure:
            {
              "questions": ["question 1", "question 2", "question 3", "question 4", "question 5"]
            }
          """),
          DataPart(mimeType, cvBytes),
        ]),
      ];

      print('🚀 Sending CV to Gemini for question generation...');
      return await _retryWithBackoff(() async {
        final response = await _model.generateContent(prompt).timeout(
          const Duration(seconds: 60),
          onTimeout: () => throw Exception('CV analysis timed out'),
        );

        final text = response.text;
        if (text == null) throw Exception('Empty response from Gemini');

        final jsonString = _extractJson(text);
        final Map<String, dynamic> data = jsonDecode(jsonString);
        
        return List<String>.from(data['questions'] ?? []);
      });
    } catch (e) {
      print('❌ ERROR generating questions from CV: $e');
      rethrow;
    }
  }

  static String _extractJson(String text) {
    final codeBlockMatch = RegExp(r'```json\s*([\s\S]*?)\s*```').firstMatch(text);
    if (codeBlockMatch != null) return codeBlockMatch.group(1)!;
    
    final start = text.indexOf('{');
    final end = text.lastIndexOf('}');
    if (start == -1 || end == -1) return text;
    return text.substring(start, end + 1);
  }
}
