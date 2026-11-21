import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mi_reparto/main.dart';
import 'package:mi_reparto/negocio.dart';
import 'package:mi_reparto/pantallas.dart';

void main() {
  setUpAll(() async {
    for (final f in ['Figtree', 'MaterialIcons']) {
      final loader = FontLoader(f)
        ..addFont(
          rootBundle.load(
            f == 'Figtree'
                ? 'fonts/Figtree-Regular.ttf'
                : 'fonts/MaterialIcons-Regular.otf',
          ),
        );
      await loader.load();
    }
  });
  Future<Negocio> datos() async {
    final n = Negocio();
    await n.guardarCliente(
      Cliente(
        id: 'demo',
        nombre: 'Cliente de prueba',
        direccion: 'Dirección de ejemplo',
        dia: DateTime.now().weekday,
        pedido: 2,
      ),
    );
    await n.registrarStock(
      'Ingreso',
      llenos: 15,
      vacios: 10,
      costo: 0,
      nota: 'Stock inicial',
    );
    return n;
  }

  Future<void> captura(WidgetTester tester, String nombre) async {
    if (!const bool.fromEnvironment('CAPTURAS')) return;
    await tester.runAsync(() async {
      final b = tester.firstRenderObject<RenderRepaintBoundary>(
        find.byKey(const ValueKey('captura')),
      );
      final img = await b.toImage(pixelRatio: 2);
      final bytes = await img.toByteData(format: ui.ImageByteFormat.png);
      await File(
        '/workspace/artifacts/agua-$nombre.png',
      ).writeAsBytes(bytes!.buffer.asUint8List());
      img.dispose();
    });
  }

  for (final size in [
    const Size(390, 844),
    const Size(360, 780),
    const Size(844, 390),
  ]) {
    testWidgets('navegación y formularios simples en $size', (tester) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final n = await datos();
      await tester.pumpWidget(
        RepaintBoundary(
          key: const ValueKey('captura'),
          child: RepartoApp(negocio: n),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      if (size.width == 390) await captura(tester, 'reparto');
      await tester.tap(find.text('Clientes'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Nuevo cliente'));
      await tester.pumpAndSettle();
      expect(find.byType(TextField), findsNWidgets(2));
      if (size.width == 390) await captura(tester, 'alta');
      expect(tester.takeException(), isNull);
    });
  }
  testWidgets('entrega y cobro actualizan cuenta y envases', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final n = await datos();
    await tester.pumpWidget(
      RepaintBoundary(
        key: const ValueKey('captura'),
        child: RepartoApp(negocio: n),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cliente de prueba'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Registrar entrega'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Sumar Vacíos que retirás'));
    await tester.pumpAndSettle();
    if (const bool.fromEnvironment('CAPTURAS')) {
      await captura(tester, 'entrega');
    }
    await tester.tap(find.text('Guardar entrega'));
    await tester.pumpAndSettle();
    expect(n.saldo('demo'), 1500000);
    expect(n.envases('demo'), 1);
    await tester.tap(find.text('Registrar pago'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, '7500');
    await tester.tap(find.text('Guardar pago'));
    await tester.pumpAndSettle();
    expect(n.saldo('demo'), 750000);
    expect(n.envases('demo'), 1);
    expect(tester.takeException(), isNull);
    await captura(tester, 'cuenta');
  });
  testWidgets(
    'texto grande y movimiento reducido mantienen acciones accesibles',
    (tester) async {
      tester.view.physicalSize = const Size(360, 780);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final n = await datos();
      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: const MediaQueryData(
              size: Size(360, 780),
              textScaler: TextScaler.linear(1.6),
              disableAnimations: true,
            ),
            child: Inicio(negocio: n),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Clientes'));
      await tester.pumpAndSettle();
      expect(find.text('Nuevo cliente'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
