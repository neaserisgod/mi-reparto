import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mi_reparto/diseno.dart';
import 'package:mi_reparto/navegacion_ui.dart';

void main() {
  for (final ancho in [320.0, 390.0]) {
    for (final escala in [1.0, 1.6]) {
      testWidgets('Paneles a $ancho y texto $escala sin desbordar', (t) async {
        t.view.physicalSize = Size(ancho, 900);
        t.view.devicePixelRatio = 1;
        addTearDown(t.view.resetPhysicalSize);
        addTearDown(t.view.resetDevicePixelRatio);
        var entregas = 0;
        await t.pumpWidget(
          MaterialApp(
            theme: tema(),
            home: MediaQuery(
              data: MediaQueryData(textScaler: TextScaler.linear(escala)),
              child: Scaffold(
                body: SingleChildScrollView(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        IndicacionNavegacion(
                          texto: 'Doblá a la derecha por Avenida de prueba',
                          distancia: 'En 120 m',
                          estado: 'GPS en vivo',
                          icono: Icons.turn_right_rounded,
                          volver: () {},
                        ),
                        const SizedBox(height: 16),
                        FichaDestinoNavegacion(
                          nombre: 'Cliente de prueba con nombre largo',
                          direccion: 'Avenida de prueba 123, Buenos Aires',
                          estado: 'Llegada estimada · sin tránsito en vivo',
                          eta: '12 min',
                          distancia: '3.2 km',
                          pedido: 3,
                          textoAccion: 'Registrar entrega',
                          accionPrincipal: () async {
                            entregas++;
                          },
                          cobrar: () {},
                          opciones: const Icon(Icons.more_vert),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
        expect(t.takeException(), isNull);
        await t.ensureVisible(find.text('Registrar entrega'));
        await t.tap(find.text('Registrar entrega'));
        await t.pumpAndSettle();
        expect(entregas, 1);
        expect(t.takeException(), isNull);
      });
    }
  }
}
