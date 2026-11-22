import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

class ApiService {
  // Candidate backend API URLs in optimal priority order:
  // 1. USB ADB Reverse (Fastest: < 20ms)
  // 2. Direct Wi-Fi IP
  // 3. HuggingFace Cloud API
  // 4. Android Emulator loopback
  static const List<String> _backendUrls = [
    'http://127.0.0.1:8000',     // Local USB / ADB reverse connection
    'http://10.45.189.136:8000', // Wi-Fi LAN direct IP
    'https://srihari2479-college-rag-api.hf.space', // HuggingFace Production Cloud API
    'http://10.0.2.2:8000',      // Android Emulator local loopback
  ];

  static String? _cachedWorkingUrl;

  static const String _supabaseUrl = 'https://eickqdvfzwjthuazdvnu.supabase.co';
  static const String _supabaseAnonKey = 'sb_publishable_hB9k_qM0C79H3VVHJALg4g_SQwSEZxa';

  /// Sends student query with fast cached connection, conversation history, and intelligent fallback
  Future<Map<String, dynamic>> sendQuery({
    required String query,
    List<Map<String, String>>? history,
    String? courseId,
    String? docType,
  }) async {
    final payload = {
      'query': query,
      if (history != null && history.isNotEmpty) 'history': history,
      'course_id': courseId,
      'doc_type': docType,
      'limit': 4,
    };

    // 1. If we already know the working backend URL, try it directly
    if (_cachedWorkingUrl != null) {
      try {
        final response = await http.post(
          Uri.parse('$_cachedWorkingUrl/api/rag/query'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode(payload),
        ).timeout(const Duration(seconds: 8));

        if (response.statusCode == 200) {
          return jsonDecode(response.body) as Map<String, dynamic>;
        }
      } catch (e) {
        debugPrint('Cached backend $_cachedWorkingUrl failed, discovering candidates: $e');
        _cachedWorkingUrl = null;
      }
    }

    // 2. Try candidate backends with fast timeouts
    for (final baseUrl in _backendUrls) {
      try {
        final timeoutDuration = baseUrl.contains('127.0.0.1') || baseUrl.contains('10.')
            ? const Duration(milliseconds: 2800)
            : const Duration(seconds: 6);

        final response = await http.post(
          Uri.parse('$baseUrl/api/rag/query'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode(payload),
        ).timeout(timeoutDuration);

        if (response.statusCode == 200) {
          _cachedWorkingUrl = baseUrl;
          debugPrint('Connected to working backend: $baseUrl');
          return jsonDecode(response.body) as Map<String, dynamic>;
        }
      } catch (e) {
        debugPrint('Backend $baseUrl unreachable: $e');
      }
    }

    // 3. Fallback: Query Supabase REST API directly if backend unreachable
    try {
      debugPrint('All backend servers unreachable, falling back to direct Supabase REST API...');
      return await _queryDirectSupabase(query);
    } catch (e) {
      debugPrint('Supabase Direct Fallback error: $e');
      rethrow;
    }
  }

  /// Direct fallback to Supabase REST API for event/course inquiries
  Future<Map<String, dynamic>> _queryDirectSupabase(String query) async {
    final lowerQ = query.toLowerCase().trim();
    final stripped = lowerQ.replaceAll(RegExp(r'[^\w\s]'), '').trim();

    // 1. Gratitude / Thanks
    final thanksPat = RegExp(r'^(?:(?:ok|okay|alright|yes|sure|cool|yeah)\s+)?(?:tq|ty|thanks|thank\s*you|thank\s*u|thanku|tysm|thx|much\s*appreciated|dhanyavadalu|danyavadalu)(?:\s+(?:so\s*much|a\s*lot|very\s*much|bro|bhai|sir|mam|madam|buddy|ai|assistant))?$');
    if (thanksPat.hasMatch(stripped) || {'tq', 'ty', 'thanks', 'thank you', 'okay tq', 'ok tq', 'thx', 'tysm'}.contains(stripped)) {
      return {
        'answer': "You're very welcome! 😊 Glad I could help. Let me know if you need any assistance with your courses, notes, syllabus, or campus events!",
        'relevant_sources': ['DIET AI Assistant'],
      };
    }

    // 2. Greetings
    final greetings = {'hi', 'hello', 'hey', 'heyy', 'hola', 'good morning', 'good afternoon', 'good evening', 'gm', 'namaste', 'namaskaram', 'vanakkam', 'whats up', "what's up", 'yo', 'howdy'};
    if (greetings.contains(stripped) || stripped.startsWith('hi ') || stripped.startsWith('hello ') || stripped.startsWith('hey ')) {
      return {
        'answer': "Hello! 👋 How can I help you today? You can ask me about your course syllabus, lecture notes, campus events, or exam preparation!",
        'relevant_sources': ['DIET AI Assistant'],
      };
    }

    // 3. Acknowledgments
    final acks = {'ok', 'okay', 'k', 'kk', 'cool', 'got it', 'noted', 'sure', 'alright', 'fine', 'understood', 'great', 'awesome', 'super', 'nice', 'perfect', 'done', 'sare', 'bagundi'};
    if (acks.contains(stripped) || stripped.startsWith('ok got it') || stripped.startsWith('okay got it')) {
      return {
        'answer': "Awesome! 👍 Feel free to ask anytime if you want to explore any subject topics, lecture notes, or upcoming campus events.",
        'relevant_sources': ['DIET AI Assistant'],
      };
    }

    // 4. Farewells
    final byes = {'bye', 'goodbye', 'cya', 'see you', 'see ya', 'take care', 'good night', 'gn', 'bye bye'};
    if (byes.contains(stripped)) {
      return {
        'answer': "Goodbye! 👋 Have a wonderful day and all the best with your studies! Feel free to reach out whenever you need help.",
        'relevant_sources': ['DIET AI Assistant'],
      };
    }

    // 5. Bot Identity
    if (RegExp(r'^(?:who|what)\s+(?:are\s+you|is\s+your\s+name|can\s+you\s+do)|how\s+can\s+you\s+help|help\s*me|help$').hasMatch(stripped)) {
      return {
        'answer': "I am the **DIET Campus AI Assistant** 🎓!\n\nI can help you with:\n• **Course Notes & Study Materials**: Lecture notes and concept reviews.\n• **Syllabus Inquiries**: Search topics, units, and subject outlines.\n• **Campus Events**: Stay updated with upcoming fests, workshops, and schedules.\n\nHow can I help you today?",
        'relevant_sources': ['DIET AI Assistant'],
      };
    }

    // 6. Casual Small Talk
    if ({'how are you', 'how are u', 'how r u', 'how do you do', 'hows it going', 'how is it going'}.contains(stripped)) {
      return {
        'answer': "I'm doing great, thank you for asking! 😊 Ready to help you with your subjects, syllabus, notes, or upcoming campus events. What would you like to explore today?",
        'relevant_sources': ['DIET AI Assistant'],
      };
    }

    // Check if query is about events
    if (lowerQ.contains('event') || lowerQ.contains('fest') || lowerQ.contains('workshop') || lowerQ.contains('hackathon') || lowerQ.contains('upcoming')) {
      final response = await http.get(
        Uri.parse('$_supabaseUrl/rest/v1/events?select=id,title,description,event_date,venue,image_url,departments(code)&order=event_date.asc'),
        headers: {
          'apikey': _supabaseAnonKey,
          'Authorization': 'Bearer $_supabaseAnonKey',
        },
      ).timeout(const Duration(seconds: 6));

      if (response.statusCode == 200) {
        final List<dynamic> events = jsonDecode(response.body);
        if (events.isNotEmpty) {
          final firstEvt = events.first as Map<String, dynamic>;
          final buffer = StringBuffer();
          buffer.writeln('### 📅 Upcoming Campus Events\n');
          for (var evt in events) {
            final title = evt['title'] ?? 'Event';
            final venue = evt['venue'] ?? 'Campus';
            final rawDate = evt['event_date'] ?? '';
            final dateStr = rawDate.toString().split('T').first;
            final desc = (evt['description'] as String?)?.trim();
            
            buffer.writeln('### $title');
            buffer.writeln('📍 **Venue:** $venue  ');
            if (dateStr.isNotEmpty) buffer.writeln('🗓️ **Date:** $dateStr  ');
            if (desc != null && desc.isNotEmpty && desc != 'null') buffer.writeln('📝 **Details:** $desc  ');
            buffer.writeln('');
          }
          
          return {
            'answer': buffer.toString().trim(),
            'matched_event_image_url': firstEvt['image_url'],
            'relevant_sources': ['Campus Events Database'],
          };
        }
      }
    }

    // Default friendly response when offline
    return {
      'answer': 'I am DIET Assistant. I can help answer questions about your syllabus, lecture notes, campus events, and academic notices.',
      'relevant_sources': ['DIET Knowledge Portal'],
    };
  }

  /// Fetches events with multi-endpoint fallback
  static Future<List<dynamic>> fetchEvents() async {
    // 1. Try cached backend URL first
    if (_cachedWorkingUrl != null) {
      try {
        final response = await http
            .get(Uri.parse('$_cachedWorkingUrl/api/rag/events'))
            .timeout(const Duration(seconds: 4));

        if (response.statusCode == 200) {
          return jsonDecode(response.body) as List<dynamic>;
        }
      } catch (_) {
        _cachedWorkingUrl = null;
      }
    }

    // 2. Try candidate endpoints with fast timeout
    for (final baseUrl in _backendUrls) {
      try {
        final timeoutDuration = baseUrl.contains('127.0.0.1') || baseUrl.contains('10.')
            ? const Duration(milliseconds: 2500)
            : const Duration(seconds: 5);

        final response = await http
            .get(Uri.parse('$baseUrl/api/rag/events'))
            .timeout(timeoutDuration);

        if (response.statusCode == 200) {
          _cachedWorkingUrl = baseUrl;
          return jsonDecode(response.body) as List<dynamic>;
        }
      } catch (_) {
        // Try next candidate
      }
    }

    // 2. Direct Supabase REST API fallback
    final response = await http.get(
      Uri.parse('$_supabaseUrl/rest/v1/events?select=id,title,description,event_date,venue,image_url,departments(code)&order=event_date.asc'),
      headers: {
        'apikey': _supabaseAnonKey,
        'Authorization': 'Bearer $_supabaseAnonKey',
        'Content-Type': 'application/json',
      },
    ).timeout(const Duration(seconds: 10));

    if (response.statusCode == 200) {
      final List<dynamic> data = jsonDecode(response.body);
      return data.map((e) {
        final json = e as Map<String, dynamic>;
        final deptCode = (json['departments'] as Map<String, dynamic>?)?['code'] ?? 'GENERIC';
        return {
          'id': json['id']?.toString() ?? '',
          'title': json['title'] ?? 'Untitled Event',
          'description': json['description'] ?? '',
          'event_date': json['event_date'] ?? '',
          'venue': json['venue'] ?? '',
          'department_code': deptCode,
          'image_url': json['image_url'],
        };
      }).toList();
    }

    throw Exception('Failed to fetch events from all endpoints.');
  }

  /// Log in student with @diet.edu.in email address
  static Future<Map<String, dynamic>> login({
    required String email,
    required String password,
  }) async {
    final payload = {
      'email': email,
      'password': password,
    };

    String lastErrorMsg = 'Login failed. Please check your credentials.';

    for (final baseUrl in _backendUrls) {
      try {
        final response = await http.post(
          Uri.parse('$baseUrl/api/rag/auth/login'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode(payload),
        ).timeout(const Duration(seconds: 10));

        if (response.statusCode == 404) {
          debugPrint('Auth endpoint 404 on $baseUrl, trying next candidate...');
          continue;
        }

        final data = jsonDecode(response.body) as Map<String, dynamic>;
        if (response.statusCode == 200) {
          return data;
        } else if (response.statusCode == 400 || response.statusCode == 401 || response.statusCode == 403) {
          lastErrorMsg = data['detail']?.toString() ?? lastErrorMsg;
          throw Exception(lastErrorMsg);
        }
      } catch (e) {
        if (e is Exception && (
            e.toString().contains('Incorrect password') ||
            e.toString().contains('pending admin approval') ||
            e.toString().contains('declined') ||
            e.toString().contains('not found') ||
            e.toString().contains('@diet.edu.in') ||
            e.toString().contains('Please try again'))) {
          rethrow;
        }
        debugPrint('Backend $baseUrl unreachable for login: $e');
      }
    }

    throw Exception(lastErrorMsg);
  }

  /// Sign up new student with @diet.edu.in email address
  static Future<Map<String, dynamic>> signup({
    required String email,
    required String password,
    required String confirmPassword,
    String? fullName,
  }) async {
    final payload = {
      'email': email,
      'password': password,
      'confirm_password': confirmPassword,
      'full_name': fullName,
    };

    String lastErrorMsg = 'Registration failed. Please check your details.';

    for (final baseUrl in _backendUrls) {
      try {
        final response = await http.post(
          Uri.parse('$baseUrl/api/rag/auth/signup'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode(payload),
        ).timeout(const Duration(seconds: 10));

        if (response.statusCode == 404) {
          debugPrint('Auth signup endpoint 404 on $baseUrl, trying next candidate...');
          continue;
        }

        final data = jsonDecode(response.body) as Map<String, dynamic>;
        if (response.statusCode == 200) {
          return data;
        } else if (response.statusCode == 400) {
          lastErrorMsg = data['detail']?.toString() ?? lastErrorMsg;
          throw Exception(lastErrorMsg);
        }
      } catch (e) {
        if (e is Exception && (
            e.toString().contains('Account already exists') ||
            e.toString().contains('Passwords do not match') ||
            e.toString().contains('@diet.edu.in'))) {
          rethrow;
        }
        debugPrint('Backend $baseUrl unreachable for signup: $e');
      }
    }

    throw Exception(lastErrorMsg);
  }
}

