import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:mi_reparto/navegacion.dart';

void main() {
  const ruta = RecorridoMapa(
    [LatLng(0, 0), LatLng(0, .001), LatLng(.001, .001), LatLng(.001, .002)],
    333,
    120,
    ['Derecha', 'Destino'],
    pasos: [
      PasoRuta(
        punto: LatLng(0, .001),
        texto: 'Doblá a la izquierda',
        giro: 'left',
      ),
      PasoRuta(
        punto: LatLng(.001, .002),
        texto: 'Seguí hasta el destino',
        tipo: 'arrive',
      ),
    ],
  );
  final inicio = DateTime.utc(2026, 11, 21);
  test('el avance GPS reduce distancia, tiempo y distancia hasta el giro', () {
    final n = SeguimientoRuta(ruta);
    final a = n.actualizar(const LatLng(0, .0002), precision: 5, fecha: inicio);
    final b = n.actualizar(
      const LatLng(0, .0008),
      precision: 5,
      fecha: inicio.add(const Duration(seconds: 2)),
    );
    expect(b.restantes, lessThan(a.restantes));
    expect(b.segundosRestantes, lessThan(a.segundosRestantes));
    expect(b.hastaPaso, lessThan(a.hastaPaso));
    expect(b.paso!.giro, 'left');
    expect(n.pendientes(b).first, b.proyeccion);
  });
  test('un pequeño retroceso por ruido no hace retroceder el recorrido', () {
    final n = SeguimientoRuta(ruta);
    final a = n.actualizar(const LatLng(0, .0008), precision: 5, fecha: inicio);
    final b = n.actualizar(
      const LatLng(0, .00075),
      precision: 5,
      fecha: inicio.add(const Duration(seconds: 1)),
    );
    expect(b.recorridos, a.recorridos);
  });
  test(
    'recalcula con dos lecturas fuera del recorrido y limita reintentos',
    () {
      final n = SeguimientoRuta(ruta);
      const fuera = LatLng(.001, 0);
      expect(
        n.actualizar(fuera, precision: 5, fecha: inicio).recalcular,
        isFalse,
      );
      expect(
        n
            .actualizar(
              fuera,
              precision: 5,
              fecha: inicio.add(const Duration(seconds: 1)),
            )
            .recalcular,
        isTrue,
      );
      expect(
        n
            .actualizar(
              fuera,
              precision: 5,
              fecha: inicio.add(const Duration(seconds: 2)),
            )
            .recalcular,
        isFalse,
      );
      expect(
        n
            .actualizar(
              fuera,
              precision: 5,
              fecha: inicio.add(const Duration(seconds: 22)),
            )
            .recalcular,
        isTrue,
      );
    },
  );
  test('una lectura imprecisa no dispara recálculos ni falsas llegadas', () {
    final n = SeguimientoRuta(ruta);
    for (var i = 0; i < 4; i++) {
      final p = n.actualizar(
        const LatLng(.001, .002),
        precision: 100,
        fecha: inicio.add(Duration(seconds: i)),
      );
      expect(p.recalcular, isFalse);
      expect(p.llegado, isFalse);
    }
  });
  test('la llegada requiere dos lecturas recientes y precisas', () {
    final n = SeguimientoRuta(ruta);
    const fin = LatLng(.001, .002);
    final a = n.actualizar(fin, precision: 5, fecha: inicio);
    expect(a.llegado, isFalse);
    expect(n.actualizar(fin, precision: 5, fecha: inicio).llegado, isFalse);
    final b = n.actualizar(
      fin,
      precision: 5,
      fecha: inicio.add(const Duration(seconds: 1)),
    );
    expect(b.llegado, isTrue);
    expect(b.restantes, 0);
  });
  test('el próximo giro cambia después de pasar la maniobra', () {
    final n = SeguimientoRuta(ruta);
    n.actualizar(const LatLng(0, .0009), precision: 5, fecha: inicio);
    final p = n.actualizar(
      const LatLng(.0003, .001),
      precision: 5,
      fecha: inicio.add(const Duration(seconds: 5)),
    );
    expect(p.paso!.tipo, 'arrive');
  });
}
