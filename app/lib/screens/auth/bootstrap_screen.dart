import 'package:flutter/material.dart';

import '../../services/api_exception.dart';
import '../../services/auth_navigation.dart';
import '../../services/auth_service.dart';
import '../../services/session_store.dart';
import '../../theme/app_theme.dart';
import 'login_screen.dart';

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
      _show(const LoginScreen());
      return;
    }

    try {
      final user = await AuthService.instance.fetchMe();
      _show(homeForUser(user));
    } on ApiException catch (e) {
      if (e.statusCode == 401 || e.isSessionExpired || e.isAccountInactive) {
        await SessionStore.instance.clear();
        _show(const LoginScreen());
        return;
      }

      final cached = SessionStore.instance.currentUser;
      _show(cached != null ? homeForUser(cached) : const LoginScreen());
    } catch (_) {
      final cached = SessionStore.instance.currentUser;
      _show(cached != null ? homeForUser(cached) : const LoginScreen());
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
      backgroundColor: AppColors.navy,
      body: Center(
        child: CircularProgressIndicator(color: Colors.white),
      ),
    );
  }
}
