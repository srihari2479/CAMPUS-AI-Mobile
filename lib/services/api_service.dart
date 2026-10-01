import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

class ApiService {
  // Candidate backend API URLs in priority order
  static const List<String> _backendUrls = [
    'https://srihari2479-college-rag-api.hf.space', // HuggingFace Production Cloud API
    'http://127.0.0.1:8000',     // Local USB / ADB reverse connection
    'http://10.24.250.136:8000', // Wi-Fi LAN direct IP
    'http://10.0.2.2:8000',      // Android Emulator local loopback
  ];

  static const String _supabaseUrl = 'https://eickqdvfzwjthuazdvnu.supabase.co';
  static const String _supabaseAnonKey = 'sb_publishable_hB9k_qM0C79H3VVHJALg4g_SQwSEZxa';

  /// Sends student query with automatic multi-endpoint fallback
  Future<Map<String, dynamic>> sendQuery({
    required String query,
    String? courseId,
    String? docType,
  }) async {
    final payload = {
      'query': query,
      'course_id': courseId,
      'doc_type': docType,
      'limit': 4,
    };

    // Try backend servers first
    for (final baseUrl in _backendUrls) {
      try {
        final response = await http.post(
          Uri.parse('$baseUrl/api/rag/query'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode(payload),
        ).timeout(const Duration(seconds: 15));

        if (response.statusCode == 200) {
          return jsonDecode(response.body) as Map<String, dynamic>;
        }
      } catch (e) {
        debugPrint('Backend $baseUrl unreachable, trying next fallback...');
      }
    }

    // Fallback: Query Supabase REST API directly if backend unreachable
    try {
      return await _queryDirectSupabase(query);
    } catch (e) {
      debugPrint('Supabase Direct Fallback error: $e');
      rethrow;
    }
  }

  /// Direct fallback to Supabase REST API for event/course inquiries
  Future<Map<String, dynamic>> _queryDirectSupabase(String query) async {
    final lowerQ = query.toLowerCase();
    
    // Check if query is about events
    if (lowerQ.contains('event') || lowerQ.contains('fest') || lowerQ.contains('workshop') || lowerQ.contains('hackathon') || lowerQ.contains('upcoming')) {
      final response = await http.get(
        Uri.parse('$_supabaseUrl/rest/v1/events?select=id,title,description,event_date,venue,image_url,departments(code)&order=event_date.asc'),
        headers: {
          'apikey': _supabaseAnonKey,
          'Authorization': 'Bearer $_supabaseAnonKey',
        },
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final List<dynamic> events = jsonDecode(response.body);
        if (events.isNotEmpty) {
          final firstEvt = events.first as Map<String, dynamic>;
          final buffer = StringBuffer();
          buffer.writeln('Here are the upcoming campus events:\n');
          for (var evt in events) {
            final title = evt['title'] ?? 'Event';
            final venue = evt['venue'] ?? 'Campus';
            final date = evt['event_date'] ?? '';
            buffer.writeln('• **$title** at $venue on ${date.toString().split('T').first}');
          }
          
          return {
            'answer': buffer.toString(),
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
    // 1. Try local & cloud backend endpoints
    for (final baseUrl in _backendUrls) {
      try {
        final response = await http
            .get(Uri.parse('$baseUrl/api/rag/events'))
            .timeout(const Duration(seconds: 8));

        if (response.statusCode == 200) {
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

