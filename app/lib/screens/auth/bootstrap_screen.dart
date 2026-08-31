import 'package:flutter/material.dart';

import '../../services/api_exception.dart';
import '../../services/auth_navigation.dart';
import '../../services/auth_service.dart';
import '../../services/session_store.dart';
import '../../theme/app_theme.dart';
import 'welcome_screen.dart';

/// Restaura a sessão salva ao abrir o app.
class BootstrapScreen extends StatefulWidget {
  const BootstrapScreen({super.key});

  @override
  State<BootstrapScreen> createState() => _BootstrapScreenState();
}

class _BootstrapScreenState extends State<BootstrapScreen> {
  Widget? _screen;

  @override
  void initState() {
    super.initState();
    _restore();
  }

  Future<void> _restore() async {
    final store = SessionStore.instance;

    if (!store.isLoggedIn) {
      _show(const WelcomeScreen());
      return;
    }

    try {
      final user = await AuthService.instance.fetchMe();
      _show(homeForUser(user));
    } on ApiException catch (e) {
      if (e.statusCode == 401 || e.isSessionExpired) {
        await SessionStore.instance.clear();
        _show(const WelcomeScreen());
        return;
      }

      final cached = SessionStore.instance.currentUser;
      _show(cached != null ? homeForUser(cached) : const WelcomeScreen());
    } catch (_) {
      final cached = SessionStore.instance.currentUser;
      _show(cached != null ? homeForUser(cached) : const WelcomeScreen());
    }
  }

  void _show(Widget screen) {
    if (!mounted) return;
    setState(() => _screen = screen);
  }

  @override
  Widget build(BuildContext context) {
    final screen = _screen;
    if (screen != null) return screen;

    return const Scaffold(
      backgroundColor: AppColors.background,
      body: Center(
        child: CircularProgressIndicator(),
      ),
    );
  }
}
