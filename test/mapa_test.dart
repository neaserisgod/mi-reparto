import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:latlong2/latlong.dart';
import 'package:mi_reparto/mapa.dart';
import 'package:mi_reparto/negocio.dart';

void main() {
  test(
    'busca dirección cerca del GPS y devuelve un destino verificable',
    () async {
      final s = ServicioMapa(
        client: MockClient((r) async {
          expect(r.url.host, 'nominatim.openstreetmap.org');
          expect(r.url.queryParameters['viewbox'], isNotNull);
          expect(r.headers['User-Agent'], contains('MiReparto'));
          return http.Response(
            jsonEncode([
              {
                'lat': '-34.5',
                'lon': '-58.7',
                'display_name': 'Dirección de prueba',
              },
            ]),
            200,
          );
        }),
      );
      addTearDown(s.cerrar);
      final ds = await s.buscar(
        'Dirección de prueba',
        const LatLng(-34.4, -58.6),
      );
      expect(ds.single.punto.latitude, -34.5);
    },
  );
  test(
    'ruta real transforma coordenadas GeoJSON sin invertir latitud',
    () async {
      final s = ServicioMapa(
        client: MockClient(
          (r) async => http.Response(
            jsonEncode({
              'code': 'Ok',
              'routes': [
                {
                  'distance': 1200,
                  'duration': 180,
                  'geometry': {
                    'coordinates': [
                      [-58.6, -34.4],
                      [-58.7, -34.5],
                    ],
                  },
                  'legs': [
                    {
                      'steps': [
                        {
                          'name': 'Calle de prueba',
                          'maneuver': {'type': 'turn', 'modifier': 'right'},
                        },
                      ],
                    },
                  ],
                },
              ],
            }),
            200,
          ),
        ),
      );
      addTearDown(s.cerrar);
      final ruta = await s.trazar(
        const LatLng(-34.4, -58.6),
        const LatLng(-34.5, -58.7),
      );
      expect(ruta.puntos.last.latitude, -34.5);
      expect(ruta.metros, 1200);
      expect(ruta.indicaciones.single, contains('derecha'));
    },
  );
  test('un error de rutas no inventa un recorrido', () async {
    final s = ServicioMapa(
      client: MockClient(
        (_) async => http.Response('{"code":"NoRoute","routes":[]}', 200),
      ),
    );
    addTearDown(s.cerrar);
    await expectLater(
      s.trazar(const LatLng(0, 0), const LatLng(1, 1)),
      throwsFormatException,
    );
  });
  test('pin persiste al programar pedidos y en el respaldo', () async {
    final n = Negocio();
    await n.guardarCliente(const Cliente(id: 'c', nombre: 'Prueba'));
    await n.fijarUbicacion('c', -34.5, -58.7);
    await n.guardarCliente(n.clientes.single.conPedido(2));
    final restaurado = Negocio.decodificar(n.exportar());
    expect(restaurado.clientes.single.latitud, -34.5);
    expect(restaurado.clientes.single.pedido, 2);
    await expectLater(n.fijarUbicacion('c', 100, 0), throwsFormatException);
    expect(n.clientes.single.latitud, -34.5);
  });
}
