import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'features/garden/garden_page.dart';
import 'features/mascot/mascot_preview_page.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  const demo = bool.fromEnvironment('DEMO_MODE');
  if (demo) {
    if (kDebugMode) {
      debugPrint('[Supabase] Modo DEMO: no consulta datos reales.');
    }
    runApp(
      const MaterialApp(
        debugShowCheckedModeBanner: false,
        home: MascotPreviewPage(),
      ),
    );
    return;
  }
  final config = _parseEnv(await rootBundle.loadString('.env'));
  final url = config['SUPABASE_URL'];
  final key = config['SUPABASE_PUBLISHABLE_KEY'];
  if (url == null || url.isEmpty || key == null || key.isEmpty) {
    throw StateError(
      'Configura SUPABASE_URL y SUPABASE_PUBLISHABLE_KEY en flutter/.env',
    );
  }
  if (!key.startsWith('sb_publishable_')) {
    throw StateError(
      'Flutter requiere una clave publicable de Supabase. Nunca uses una clave privada.',
    );
  }
  if (kDebugMode) {
    debugPrint('[Supabase] Inicializando cliente: ${Uri.parse(url).host}');
  }
  try {
    await Supabase.initialize(url: url, publishableKey: key);
    if (kDebugMode) {
      debugPrint(
        '[Supabase] Cliente listo; falta confirmar la consulta de lecturas.',
      );
    }
  } catch (error, stack) {
    if (kDebugMode) {
      debugPrint('[Supabase] ERROR al inicializar: $error');
      debugPrintStack(stackTrace: stack);
    }
    rethrow;
  }
  runApp(const GardenApp());
}

Map<String, String> _parseEnv(String content) {
  final values = <String, String>{};
  for (final line in content.split('\n')) {
    final trimmed = line.trim();
    if (trimmed.isEmpty || trimmed.startsWith('#')) continue;
    final separator = trimmed.indexOf('=');
    if (separator <= 0) continue;
    values[trimmed.substring(0, separator).trim()] = trimmed
        .substring(separator + 1)
        .trim();
  }
  return values;
}

class GardenApp extends StatelessWidget {
  const GardenApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Mi jardín',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF447A51)),
        scaffoldBackgroundColor: const Color(0xFFF6F7F0),
        useMaterial3: true,
      ),
      home: const GardenPage(),
    );
  }
}
