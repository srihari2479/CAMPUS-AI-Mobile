import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'services/chat_provider.dart';
import 'services/auth_service.dart';
import 'views/chat_screen.dart';
import 'views/auth_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      systemNavigationBarColor: Color(0xFF000000),
      systemNavigationBarIconBrightness: Brightness.light,
    ),
  );

  final userSession = await AuthService.getUserSession();

  runApp(
    ChangeNotifierProvider(
      create: (_) => ChatProvider(),
      child: MyApp(isLoggedIn: userSession != null),
    ),
  );
}

class MyApp extends StatelessWidget {
  final bool isLoggedIn;
  const MyApp({super.key, this.isLoggedIn = false});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'DIET AI Assistant',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: const Color(0xFF000000), // Pitch Black ChatGPT Style
        colorScheme: const ColorScheme.dark().copyWith(
          primary: const Color(0xFF10B981), // ChatGPT Green Accent
          secondary: const Color(0xFF059669),
          surface: const Color(0xFF121212),
        ),
      ),
      home: isLoggedIn ? const ChatScreen() : const AuthScreen(),
    );
  }
}
