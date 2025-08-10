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
    return MaterialApp(title: 'App Post', debugShowCheckedModeBanner: false, home: AuthWrapper());
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
