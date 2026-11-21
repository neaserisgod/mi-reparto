import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:path_provider/path_provider.dart';
import 'negocio.dart';
import 'diseno.dart';
import 'pantallas.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    final dir = await getApplicationDocumentsDirectory();
    final negocio = Negocio(archivo: File('${dir.path}/mi-reparto.json'));
    await negocio.cargar();
    runApp(RepartoApp(negocio: negocio));
  } catch (_) {
    runApp(
      MaterialApp(
        theme: tema(),
        home: Scaffold(
          appBar: AppBar(title: const Text('Mi Reparto')),
          body: const Padding(
            padding: EdgeInsets.all(24),
            child: Text(
              'No se pudieron abrir los datos. No se borró nada. Cerrá la app y volvé a intentar. Si continúa, conservá los archivos del celular antes de reinstalar.',
            ),
          ),
        ),
      ),
    );
  }
}

class RepartoApp extends StatelessWidget {
  const RepartoApp({super.key, required this.negocio});
  final Negocio negocio;
  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'Mi Reparto',
    debugShowCheckedModeBanner: false,
    theme: tema(),
    locale: const Locale('es', 'AR'),
    supportedLocales: const [Locale('es', 'AR')],
    localizationsDelegates: GlobalMaterialLocalizations.delegates,
    home: Inicio(negocio: negocio),
  );
}
