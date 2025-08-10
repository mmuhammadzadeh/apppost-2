import 'dart:async';
import 'package:flutter/material.dart';
import 'api_service.dart';
import 'user.dart';

class UserPanel extends StatefulWidget {
  final User currentUser;
  final VoidCallback onLogout;
  const UserPanel({
    required this.currentUser,
    required this.onLogout,
    super.key,
  });

  @override
  State<UserPanel> createState() => _UserPanelState();
}

class _UserPanelState extends State<UserPanel> {
  Timer? _heartbeatTimer;

  @override
  void initState() {
    super.initState();
    _startHeartbeat();
  }

  void _startHeartbeat() {
    // Ping immediately and then every 3 minutes
    _sendHeartbeat();
    _heartbeatTimer = Timer.periodic(const Duration(minutes: 3), (timer) {
      _sendHeartbeat();
    });
  }

  void _sendHeartbeat() {
    if (widget.currentUser.token == null) return;
    ApiService.pingPresence(
      token: widget.currentUser.token!,
      userId: widget.currentUser.id,
    ).catchError((e) {
      // Log error, but don't bother the user with a snackbar
      print('Heartbeat Error: $e');
    });
  }

  @override
  void dispose() {
    _heartbeatTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('پنل کاربر: ${widget.currentUser.username}'),
        actions: [
          IconButton(icon: const Icon(Icons.logout), onPressed: widget.onLogout),
        ],
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.waving_hand,
              size: 60,
              color: Theme.of(context).primaryColor,
            ),
            const SizedBox(height: 24),
            Text(
              'خوش آمدید',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              widget.currentUser.fullName.isNotEmpty
                  ? widget.currentUser.fullName
                  : widget.currentUser.username,
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).primaryColor,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}
