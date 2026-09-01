import 'package:flutter/material.dart';

import '../data/client_requests_store.dart';
import '../screens/auth/welcome_screen.dart';
import 'session_store.dart';

/// Trata 401/conta inativa em rotas autenticadas: limpa sessão e volta ao início.
class SessionExpiry {
  SessionExpiry._();

  static final GlobalKey<NavigatorState> navigatorKey =
      GlobalKey<NavigatorState>();

  static const sessionExpiredMessage = 'Sessão expirada. Faça login novamente.';
  static const accountInactiveMessage = 'Sua conta foi inativada.';

  static bool _handling = false;
  static bool get isHandling => _handling;

  static Future<void> handleUnauthorized({String? message}) async {
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

      final text = (message != null && message.trim().isNotEmpty)
          ? message.trim()
          : sessionExpiredMessage;

      WidgetsBinding.instance.addPostFrameCallback((_) {
        final ctx = navigatorKey.currentContext;
        if (ctx == null) return;
        ScaffoldMessenger.of(ctx).showSnackBar(
          SnackBar(
            content: Text(text),
            behavior: SnackBarBehavior.floating,
          ),
        );
      });
    } finally {
      _handling = false;
    }
  }
}
