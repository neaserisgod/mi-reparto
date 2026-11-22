import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mi_reparto/actualizaciones.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  const path = '/cache/updates/mi-reparto-1010.apk';
  tearDown(() => messenger.setMockMethodCallHandler(canalNativo, null));

  Future<void> abrir(WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: FilledButton(
              onPressed: () => unawaited(
                Actualizador.instalarDescargada(context, File(path)),
              ),
              child: const Text('Instalar prueba'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Instalar prueba'));
    await tester.pumpAndSettle();
  }

  testWidgets(
    'un rechazo de firma siempre se muestra, sin depender de búsqueda manual',
    (tester) async {
      messenger.setMockMethodCallHandler(canalNativo, (call) async {
        expect(call.method, 'instalar');
        expect(call.arguments['path'], path);
        throw PlatformException(
          code: 'actualizacion',
          message:
              'La firma no coincide. Conservá un respaldo antes de cambiar de instalación.',
        );
      });
      await abrir(tester);
      expect(find.text('La firma del APK es diferente'), findsOneWidget);
      expect(find.textContaining('La firma no coincide'), findsOneWidget);
      await tester.tap(find.text('Entendido'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'después del permiso se reintenta el mismo archivo, sin volver a descargar',
    (tester) async {
      var intentos = 0;
      messenger.setMockMethodCallHandler(canalNativo, (call) async {
        expect(call.arguments['path'], path);
        return ++intentos == 1 ? 'permiso' : 'instalador';
      });
      await abrir(tester);
      expect(find.text('Permitir la instalación'), findsOneWidget);
      await tester.tap(find.text('Continuar'));
      await tester.pumpAndSettle();
      expect(intentos, 2);
      expect(find.byType(AlertDialog), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('no interpreta una respuesta vacía como instalación iniciada', (
    tester,
  ) async {
    messenger.setMockMethodCallHandler(canalNativo, (_) async => null);
    await abrir(tester);
    expect(find.text('No se pudo abrir el instalador'), findsOneWidget);
    expect(find.textContaining('Android no confirmó'), findsOneWidget);
  });
}
