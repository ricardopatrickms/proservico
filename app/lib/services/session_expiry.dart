import 'package:flutter/material.dart';

import '../data/client_requests_store.dart';
import '../screens/auth/welcome_screen.dart';
import 'session_store.dart';

/// Trata 401 em rotas autenticadas: limpa sessão e volta ao início.
class SessionExpiry {
  SessionExpiry._();

  static final GlobalKey<NavigatorState> navigatorKey =
      GlobalKey<NavigatorState>();

  static bool _handling = false;

  static Future<void> handleUnauthorized() async {
    if (_handling) return;
    if (SessionStore.instance.accessToken == null) return;

    _handling = true;
    try {
      await SessionStore.instance.clear();
      ClientRequestsStore.instance.clear();

      final nav = navigatorKey.currentState;
      if (nav == null) return;

      nav.pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const WelcomeScreen()),
        (_) => false,
      );

      WidgetsBinding.instance.addPostFrameCallback((_) {
        final ctx = navigatorKey.currentContext;
        if (ctx == null) return;
        ScaffoldMessenger.of(ctx).showSnackBar(
          const SnackBar(
            content: Text('Sessão expirada. Faça login novamente.'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      });
    } finally {
      _handling = false;
    }
  }
}
