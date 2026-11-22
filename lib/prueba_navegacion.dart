// Punto de entrada exclusivo del APK de pruebas del emulador.
// No se utiliza en el APK publicado y no contiene clientes reales.
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'diseno.dart';
import 'mapa.dart';
import 'negocio.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final negocio = Negocio();
  await negocio.guardarCliente(
    const Cliente(
      id: 'prueba',
      nombre: 'Entrega de prueba',
      direccion: 'Av. Santa Fe, Buenos Aires',
      pedido: 3,
      latitud: -34.5952,
      longitud: -58.3974,
    ),
  );
  runApp(
    MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: tema(),
      locale: const Locale('es', 'AR'),
      supportedLocales: const [Locale('es', 'AR')],
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      home: MapaReparto(negocio: negocio, clienteId: 'prueba'),
    ),
  );
}
