import 'package:flutter/material.dart';
import 'user.dart';
import 'login_page.dart';
import 'user_panel.dart';
import 'admin_panel.dart';
import 'session_manager.dart';

User? currentUser;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // تنظیم error handling برای جلوگیری از خطاهای development
  FlutterError.onError = (FlutterErrorDetails details) {
    if (details.exception.toString().contains('Not connected to an application')) {
      // نادیده گرفتن خطاهای development
      return;
    }
    FlutterError.presentError(details);
  };
  
  currentUser = await SessionManager.restoreSession();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'App Post',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF6750A4), // رنگ بنفش زیبا
          brightness: Brightness.light,
        ),
        // تنظیمات پس زمینه
        scaffoldBackgroundColor: const Color(0xFFF8F9FF), // پس زمینه آبی روشن
        // تنظیمات فونت
        fontFamily: 'Vazirmatn', // فونت فارسی
        textTheme: const TextTheme(
          headlineLarge: TextStyle(fontWeight: FontWeight.bold, fontSize: 32),
          headlineMedium: TextStyle(fontWeight: FontWeight.w600, fontSize: 24),
          titleLarge: TextStyle(fontWeight: FontWeight.w600, fontSize: 20),
          titleMedium: TextStyle(fontWeight: FontWeight.w500, fontSize: 16),
        ),
        // تنظیمات Card
        cardTheme: const CardThemeData(
          elevation: 4,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(16)),
          ),
        ),
        // تنظیمات ElevatedButton
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            elevation: 2,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          ),
        ),
        // تنظیمات InputDecoration
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: Colors.grey[50],
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.grey[300]!),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Color(0xFF6750A4), width: 2),
          ),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 16,
          ),
        ),
        // تنظیمات AppBar
        appBarTheme: const AppBarTheme(
          elevation: 0,
          centerTitle: true,
          backgroundColor: Colors.transparent,
          foregroundColor: Color(0xFF6750A4),
        ),
      ),
      home: AuthWrapper(),
    );
  }
}

class AuthWrapper extends StatefulWidget {
  const AuthWrapper({super.key});

  @override
  State<AuthWrapper> createState() => _AuthWrapperState();
}

class _AuthWrapperState extends State<AuthWrapper> {
  @override
  Widget build(BuildContext context) {
    if (currentUser == null) {
      return LoginPage(
        onLogin: (user) {
          setState(() {
            currentUser = user;
          });
          SessionManager.saveSession(user);
        },
      );
    } else if (currentUser!.role == 'admin') {
      return AdminPanel(
        currentUser: currentUser!,
        onLogout: () async {
          await SessionManager.clearSession(currentUser!);
          setState(() {
            currentUser = null;
          });
        },
      );
    } else {
      return UserPanel(
        currentUser: currentUser!,
        onLogout: () async {
          await SessionManager.clearSession(currentUser!);
          setState(() {
            currentUser = null;
          });
        },
      );
    }
  }
}
