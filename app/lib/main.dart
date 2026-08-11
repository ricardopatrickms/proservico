import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'screens/auth/welcome_screen.dart';
import 'services/session_expiry.dart';
import 'services/session_store.dart';
import 'theme/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: '.env');
  await initializeDateFormatting('pt_BR');
  await SessionStore.instance.load();
  runApp(const ProServicoApp());
}

class ProServicoApp extends StatelessWidget {
  const ProServicoApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ProServico',
      debugShowCheckedModeBanner: false,
      navigatorKey: SessionExpiry.navigatorKey,
      theme: AppTheme.light,
      locale: const Locale('pt', 'BR'),
      supportedLocales: const [Locale('pt', 'BR')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: const WelcomeScreen(),
    );
  }
}
