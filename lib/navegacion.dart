import 'dart:math' as math;
import 'package:latlong2/latlong.dart';

class DestinoMapa {
  const DestinoMapa(this.punto, this.nombre);
  final LatLng punto;
  final String nombre;
}

class PasoRuta {
  const PasoRuta({
    required this.punto,
    required this.texto,
    this.tipo = 'continue',
    this.giro = 'straight',
  });
  final LatLng punto;
  final String texto, tipo, giro;
}

class RecorridoMapa {
  const RecorridoMapa(
    this.puntos,
    this.metros,
    this.segundos,
    this.indicaciones, {
    this.pasos = const [],
  });
  final List<LatLng> puntos;
  final double metros, segundos;
  final List<String> indicaciones;
  final List<PasoRuta> pasos;
}

class ProgresoRuta {
  const ProgresoRuta({
    required this.recorridos,
    required this.restantes,
    required this.segundosRestantes,
    required this.desvio,
    required this.proyeccion,
    required this.segmento,
    required this.paso,
    required this.hastaPaso,
    required this.llegado,
    required this.recalcular,
  });
  final double recorridos, restantes, segundosRestantes, desvio, hastaPaso;
  final LatLng proyeccion;
  final int segmento;
  final PasoRuta? paso;
  final bool llegado, recalcular;
}

class _Proyeccion {
  const _Proyeccion(this.punto, this.distancia, this.recorridos, this.segmento);
  final LatLng punto;
  final double distancia, recorridos;
  final int segmento;
}

/// Avance sobre la geometría, no distancia en línea recta. No usa Google.
class SeguimientoRuta {
  SeguimientoRuta(this.ruta) {
    if (ruta.puntos.length < 2) {
      throw ArgumentError('El recorrido necesita al menos dos puntos.');
    }
    acumuladas = [0];
    for (var i = 1; i < ruta.puntos.length; i++) {
      acumuladas.add(
        acumuladas.last + _distancia(ruta.puntos[i - 1], ruta.puntos[i]),
      );
    }
    var minimo = 0.0;
    for (final p in ruta.pasos) {
      final q = _proyectar(p.punto, minimo: minimo - 5);
      final marca = math.max(minimo, q.recorridos);
      marcas.add(marca);
      minimo = marca;
    }
  }
  final RecorridoMapa ruta;
  late final List<double> acumuladas;
  final List<double> marcas = [];
  static const _distancia = Distance();
  double _avance = 0;
  int _fuera = 0, _cerca = 0;
  DateTime? _ultimoRecalculo, _ultimaLectura;
  ProgresoRuta? ultimo;
  double get longitud => acumuladas.last;

  _Proyeccion _proyectar(LatLng p, {double minimo = 0}) {
    _Proyeccion? mejor;
    for (var i = 0; i < ruta.puntos.length - 1; i++) {
      if (acumuladas[i + 1] < minimo) continue;
      final a = ruta.puntos[i], b = ruta.puntos[i + 1];
      final coseno = math.cos(
        (a.latitude + b.latitude + p.latitude) / 3 * math.pi / 180,
      );
      final dx = (b.longitude - a.longitude) * coseno,
          dy = b.latitude - a.latitude;
      final px = (p.longitude - a.longitude) * coseno,
          py = p.latitude - a.latitude;
      final largo = dx * dx + dy * dy;
      final t = largo == 0
          ? 0.0
          : ((px * dx + py * dy) / largo).clamp(0.0, 1.0);
      final q = LatLng(
        a.latitude + (b.latitude - a.latitude) * t,
        a.longitude + (b.longitude - a.longitude) * t,
      );
      final distancia = _distancia(p, q);
      final recorridos =
          acumuladas[i] + (acumuladas[i + 1] - acumuladas[i]) * t;
      if (mejor == null || distancia < mejor.distancia - .2) {
        mejor = _Proyeccion(q, distancia, recorridos, i);
      }
    }
    return mejor ??
        _Proyeccion(
          ruta.puntos.last,
          _distancia(p, ruta.puntos.last),
          longitud,
          ruta.puntos.length - 2,
        );
  }

  ProgresoRuta actualizar(
    LatLng posicion, {
    required double precision,
    required DateTime fecha,
  }) {
    if (_ultimaLectura != null &&
        !fecha.isAfter(_ultimaLectura!) &&
        ultimo != null) {
      return ultimo!;
    }
    _ultimaLectura = fecha;
    final q = _proyectar(posicion, minimo: _avance - 25);
    final preciso = precision.isFinite && precision >= 0 && precision <= 35;
    final lejos = q.distancia > math.max(40, precision * 1.5);
    _fuera = preciso && lejos ? _fuera + 1 : 0;
    final recalcular =
        _fuera >= 2 &&
        (_ultimoRecalculo == null ||
            fecha.difference(_ultimoRecalculo!) >= const Duration(seconds: 20));
    if (recalcular) _ultimoRecalculo = fecha;
    if (preciso && !lejos) _avance = math.max(_avance, q.recorridos);
    final cerca =
        _distancia(posicion, ruta.puntos.last) <= 25 &&
        precision >= 0 &&
        precision <= 25;
    _cerca = cerca ? _cerca + 1 : 0;
    final llegado = _cerca >= 2;
    final restantes = llegado ? 0.0 : (longitud - _avance).clamp(0.0, longitud);
    PasoRuta? paso;
    var hasta = restantes;
    for (var i = 0; i < marcas.length; i++) {
      if (marcas[i] > _avance + 10 || i == marcas.length - 1) {
        paso = ruta.pasos[i];
        hasta = math.max(0, marcas[i] - _avance);
        break;
      }
    }
    final progreso = ProgresoRuta(
      recorridos: _avance,
      restantes: restantes,
      segundosRestantes: longitud > 0
          ? ruta.segundos * restantes / longitud
          : 0,
      desvio: q.distancia,
      proyeccion: q.punto,
      segmento: q.segmento,
      paso: paso,
      hastaPaso: hasta,
      llegado: llegado,
      recalcular: recalcular,
    );
    ultimo = progreso;
    return progreso;
  }

  List<LatLng> pendientes(ProgresoRuta? p) => p == null
      ? ruta.puntos
      : [p.proyeccion, ...ruta.puntos.skip(p.segmento + 1)];
}

String distanciaNavegacion(double metros) => metros >= 1000
    ? '${(metros / 1000).toStringAsFixed(1)} km'
    : '${(metros / 10).round() * 10} m';
