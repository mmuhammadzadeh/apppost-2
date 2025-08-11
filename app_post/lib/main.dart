import 'package:flutter/material.dart';
import 'user.dart';
import 'login_page.dart';
import 'user_panel.dart';
import 'admin_panel.dart';
import 'session_manager.dart';

User? currentUser;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
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
        brightness: Brightness.dark,
        primaryColor: const Color(0xFFFBC02D), // Golden Yellow
        scaffoldBackgroundColor: const Color(0xFF121212), // Almost Black
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFFFBC02D),       // Golden Yellow
          secondary: Color(0xFFFBC02D),     // Golden Yellow
          surface: Color(0xFF1E1E1E),     // Dark Grey for surfaces like cards
          background: Color(0xFF121212),   // Almost Black
          onPrimary: Colors.black,          // Text on Golden Yellow buttons
          onSecondary: Colors.black,
          onSurface: Colors.white,
          onBackground: Colors.white,
        ),

        cardTheme: CardTheme(
          color: const Color(0xFF1E1E1E),
          elevation: 8.0,
          shadowColor: Colors.black.withOpacity(0.5),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16.0),
          ),
        ),

        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF1E1E1E),
          elevation: 0,
          foregroundColor: Colors.white,
        ),

        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFFFBC02D), // Golden
            foregroundColor: Colors.black, // Black text
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          ),
        ),

        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: const Color(0xFF2A2A2A),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.grey[800]!),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Color(0xFFFBC02D), width: 2),
          ),
        ),

        dialogTheme: DialogTheme(
          backgroundColor: const Color(0xFF1E1E1E),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),

        tabBarTheme: const TabBarTheme(
          labelColor: Color(0xFFFBC02D),
          unselectedLabelColor: Colors.grey,
          indicatorColor: Color(0xFFFBC02D),
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
