import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:image_picker_android/image_picker_android.dart';
import 'package:image_picker_platform_interface/image_picker_platform_interface.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'config/api_config.dart';
import 'screens/auth/bootstrap_screen.dart';
import 'services/session_expiry.dart';
import 'services/session_store.dart';
import 'theme/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: '.env');
  debugPrint('[boot] API_BASE_URL=${ApiConfig.baseUrl}');
  await initializeDateFormatting('pt_BR');
  await SessionStore.instance.load();

  final imagePickerImplementation = ImagePickerPlatform.instance;
  if (imagePickerImplementation is ImagePickerAndroid) {
    // Galeria com permissão explícita (estilo Telegram), não o seletor sem permissão.
    imagePickerImplementation.useAndroidPhotoPicker = false;
  }

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
      home: const BootstrapScreen(),
    );
  }
}
