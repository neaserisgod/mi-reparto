import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:maplibre_gl/maplibre_gl.dart' as ml;
import 'actualizaciones.dart' show canalNativo;
import 'navegacion_ui.dart';
import 'navegacion.dart';
export 'navegacion.dart' show DestinoMapa, RecorridoMapa;
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';
import 'diseno.dart';
import 'negocio.dart';
import 'pantallas.dart' show Entrega, Cobro, abrir;

class ServicioMapa {
  ServicioMapa({http.Client? client}) : _client = client ?? http.Client();
  final http.Client _client;
  static DateTime _ultima = DateTime.fromMillisecondsSinceEpoch(0);
  void cerrar() => _client.close();
  Future<List<DestinoMapa>> buscar(String direccion, LatLng? origen) async {
    if (direccion.trim().isEmpty) {
      throw const FormatException(
        'El cliente no tiene dirección. Podés elegir el destino tocando el mapa.',
      );
    }
    final espera = 1100 - DateTime.now().difference(_ultima).inMilliseconds;
    if (espera > 0) await Future<void>.delayed(Duration(milliseconds: espera));
    _ultima = DateTime.now();
    final q = <String, String>{
      'q': direccion,
      'format': 'json',
      'limit': '4',
      'addressdetails': '1',
      'countrycodes': 'ar',
    };
    if (origen != null) {
      q['viewbox'] =
          '${origen.longitude - .25},${origen.latitude + .25},${origen.longitude + .25},${origen.latitude - .25}';
    }
    final r = await _client
        .get(
          Uri.https('nominatim.openstreetmap.org', '/search', q),
          headers: {
            'User-Agent':
                'MiReparto/0.3 (https://github.com/neaserisgod/mi-reparto)',
            'Accept-Language': 'es',
          },
        )
        .timeout(const Duration(seconds: 15));
    if (r.statusCode != 200) {
      throw const FormatException(
        'No se pudo buscar la dirección. Podés elegir el destino en el mapa.',
      );
    }
    final lista = jsonDecode(r.body) as List;
    return lista.map((j) {
      final lat = double.parse(j['lat'] as String),
          lon = double.parse(j['lon'] as String);
      if (!lat.isFinite || !lon.isFinite || lat.abs() > 90 || lon.abs() > 180) {
        throw const FormatException(
          'La dirección devolvió una ubicación inválida.',
        );
      }
      return DestinoMapa(LatLng(lat, lon), j['display_name'] as String);
    }).toList();
  }

  Future<RecorridoMapa> trazar(LatLng origen, LatLng destino) async {
    final r = await _client
        .get(
          Uri.https(
            'routing.openstreetmap.de',
            '/routed-car/route/v1/driving/${origen.longitude},${origen.latitude};${destino.longitude},${destino.latitude}',
            {'overview': 'full', 'geometries': 'geojson', 'steps': 'true'},
          ),
          headers: {'User-Agent': 'MiReparto/0.3'},
        )
        .timeout(const Duration(seconds: 20));
    if (r.statusCode != 200) {
      throw const FormatException(
        'No se pudo calcular el recorrido. Probá nuevamente o usá el GPS externo.',
      );
    }
    final j = jsonDecode(r.body) as Map<String, dynamic>;
    if (j['code'] != 'Ok' || (j['routes'] as List).isEmpty) {
      throw const FormatException(
        'No se encontró un recorrido para este destino.',
      );
    }
    final ruta = j['routes'][0] as Map<String, dynamic>;
    final puntos = (ruta['geometry']['coordinates'] as List)
        .map((c) => LatLng((c[1] as num).toDouble(), (c[0] as num).toDouble()))
        .toList();
    final pasos = <String>[];
    final maniobras = <PasoRuta>[];
    for (final leg in ruta['legs'] as List) {
      for (final step in leg['steps'] as List) {
        final m = step['maneuver'];
        final tipo = m['type'];
        final mod = m['modifier'] ?? '';
        final lado = mod.toString().contains('left')
            ? 'a la izquierda'
            : mod.toString().contains('right')
            ? 'a la derecha'
            : 'derecho';
        final calle = (step['name'] as String?) ?? '';
        final texto = switch (tipo) {
          'depart' => 'Iniciá el recorrido',
          'arrive' => 'Seguí hasta el destino',
          'roundabout' || 'rotary' =>
            m['exit'] is num
                ? 'Tomá la salida ${m['exit']} de la rotonda'
                : 'Tomá la rotonda',
          'turn' => mod == 'uturn' ? 'Hacé un giro en U' : 'Doblá $lado',
          'end of road' => 'Al final de la calle, doblá $lado',
          'off ramp' || 'on ramp' => 'Tomá la salida $lado',
          'fork' => 'Mantenete $lado',
          'merge' => 'Incorporate $lado',
          _ => 'Continuá $lado',
        };
        final instruccion = '$texto${calle.isEmpty ? '' : ' por $calle'}';
        pasos.add(instruccion);
        final loc = m['location'];
        if (loc is List && loc.length >= 2) {
          maniobras.add(
            PasoRuta(
              punto: LatLng(
                (loc[1] as num).toDouble(),
                (loc[0] as num).toDouble(),
              ),
              texto: instruccion,
              tipo: tipo as String,
              giro: mod as String,
            ),
          );
        }
      }
    }
    return RecorridoMapa(
      puntos,
      (ruta['distance'] as num).toDouble(),
      (ruta['duration'] as num).toDouble(),
      pasos,
      pasos: maniobras,
    );
  }
}

class MapaReparto extends StatefulWidget {
  const MapaReparto({
    super.key,
    required this.negocio,
    required this.clienteId,
  });
  final Negocio negocio;
  final String clienteId;

  @override
  State<MapaReparto> createState() => _MapaRepartoState();
}

class _MapaRepartoState extends State<MapaReparto> with WidgetsBindingObserver {
  ml.MapLibreMapController? mapa;
  final servicio = ServicioMapa();
  StreamSubscription<Position>? ubicacion;
  Timer? reloj;
  LatLng? origen, destino;
  Position? ultimaPosicion;
  RecorridoMapa? ruta;
  SeguimientoRuta? seguimiento;
  ProgresoRuta? progreso;
  String? error, nombreDestino;
  bool iniciando = true,
      trazando = false,
      confirmado = false,
      listo = false,
      seguir = true,
      obteniendoGps = false;
  int generacion = 0;
  DateTime? ultimaSolicitudRuta;
  double rumbo = 0;
  bool _vivo = false;
  Cliente get cliente =>
      widget.negocio.clientes.firstWhere((c) => c.id == widget.clienteId);
  bool get gpsVivo =>
      ultimaPosicion != null &&
      DateTime.now().difference(ultimaPosicion!.timestamp) <
          const Duration(seconds: 12);
  ml.LatLng punto(LatLng p) => ml.LatLng(p.latitude, p.longitude);
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    final c = cliente;
    if (c.latitud != null) {
      destino = LatLng(c.latitud!, c.longitud!);
      confirmado = true;
      nombreDestino = c.direccion;
    }
    unawaited(iniciar());
    reloj = Timer.periodic(const Duration(seconds: 2), (_) {
      if (mounted && _vivo != gpsVivo) setState(() => _vivo = gpsVivo);
    });
    unawaited(
      canalNativo
          .invokeMethod<void>('pantallaNavegacion', {'activa': true})
          .catchError((Object _) {}),
    );
  }

  @override
  void dispose() {
    generacion++;
    WidgetsBinding.instance.removeObserver(this);
    reloj?.cancel();
    ubicacion?.cancel();
    servicio.cerrar();
    unawaited(
      canalNativo
          .invokeMethod<void>('pantallaNavegacion', {'activa': false})
          .catchError((Object _) {}),
    );
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) {
      enPrimerPlano = false;
      reanudarGpsPendiente = false;
      ubicacion?.cancel();
      ubicacion = null;
    } else if (state == AppLifecycleState.resumed) {
      enPrimerPlano = true;
      if (ubicacion == null) {
        if (obteniendoGps) {
          reanudarGpsPendiente = true;
        } else {
          unawaited(activarGps());
        }
      }
    }
  }

  bool enPrimerPlano = true;
  bool reanudarGpsPendiente = false;

  LocationSettings get ajustesGps => AndroidSettings(
    accuracy: LocationAccuracy.bestForNavigation,
    distanceFilter: 0,
    intervalDuration: const Duration(seconds: 1),
    maxUpdateAge: Duration.zero,
    forceLocationManager: true,
  );
  Future<void> activarGps() async {
    if (obteniendoGps || !mounted || !enPrimerPlano) return;
    obteniendoGps = true;
    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        throw const FormatException(
          'Activá el GPS del celular para iniciar la navegación.',
        );
      }
      var permiso = await Geolocator.checkPermission();
      if (permiso == LocationPermission.denied) {
        permiso = await Geolocator.requestPermission();
      }
      if (permiso == LocationPermission.denied ||
          permiso == LocationPermission.deniedForever) {
        throw const FormatException(
          'Permití la ubicación precisa para seguir el recorrido en vivo.',
        );
      }
      if (!mounted || !enPrimerPlano) return;
      await ubicacion?.cancel();
      if (!mounted || !enPrimerPlano) return;
      ubicacion = Geolocator.getPositionStream(locationSettings: ajustesGps).listen(
        recibirPosicion,
        onError: (_) {
          if (mounted) {
            setState(
              () => error =
                  'Se perdió la señal GPS. La posición no se está actualizando.',
            );
          }
        },
      );
      try {
        final p = await Geolocator.getCurrentPosition(
          locationSettings: AndroidSettings(
            accuracy: LocationAccuracy.bestForNavigation,
            forceLocationManager: true,
            timeLimit: const Duration(seconds: 15),
          ),
        );
        recibirPosicion(p);
      } on TimeoutException {
        if (mounted && origen == null) {
          setState(
            () => error =
                'Esperando una posición GPS. Probá acercarte a una ventana o salir al exterior.',
          );
        }
      }
    } catch (e) {
      if (mounted) {
        setState(
          () => error = e is FormatException
              ? e.message
              : 'No se pudo activar el GPS. Podés elegir el destino en el mapa.',
        );
      }
    } finally {
      obteniendoGps = false;
      final reanudar = reanudarGpsPendiente;
      reanudarGpsPendiente = false;
      if (reanudar && mounted && enPrimerPlano && ubicacion == null) {
        unawaited(activarGps());
      }
    }
  }

  void recibirPosicion(Position p) {
    if (!mounted ||
        !p.latitude.isFinite ||
        !p.longitude.isFinite ||
        p.latitude.abs() > 90 ||
        p.longitude.abs() > 180) {
      return;
    }
    if (ultimaPosicion != null &&
        !p.timestamp.isAfter(ultimaPosicion!.timestamp)) {
      return;
    }
    if (DateTime.now().difference(p.timestamp) > const Duration(seconds: 15)) {
      return;
    }
    final nuevo = LatLng(p.latitude, p.longitude);
    if (p.speed >= .8 &&
        p.heading.isFinite &&
        p.heading >= 0 &&
        p.heading < 360) {
      rumbo = p.heading;
    }
    setState(() {
      origen = nuevo;
      ultimaPosicion = p;
      _vivo = gpsVivo;
      if (seguimiento != null) {
        progreso = seguimiento!.actualizar(
          nuevo,
          precision: p.accuracy,
          fecha: p.timestamp,
        );
      }
    });
    if (listo) {
      unawaited(pintarPosicion());
      if (seguir) unawaited(centrar());
      if (ruta != null) unawaited(pintarRuta());
    }
    if (confirmado && ruta == null && !trazando && !iniciando) {
      unawaited(trazar());
    }
    if (progreso?.recalcular == true && !trazando) unawaited(trazar());
  }

  Future<void> iniciar() async {
    await activarGps();
    if (!mounted) return;
    if (destino == null && cliente.direccion.isNotEmpty) {
      final consulta = generacion;
      try {
        final ds = await servicio.buscar(cliente.direccion, origen);
        if (!mounted || consulta != generacion) return;
        if (ds.isNotEmpty) {
          setState(() {
            destino = ds.first.punto;
            nombreDestino = ds.first.nombre;
          });
        } else {
          setState(
            () => error =
                'No encontramos esa dirección. Mantené presionado el punto correcto en el mapa.',
          );
        }
      } catch (e) {
        if (mounted && consulta == generacion) {
          setState(
            () => error = e is FormatException
                ? e.message
                : 'No se pudo ubicar la dirección. Elegí el destino en el mapa.',
          );
        }
      }
    }
    if (!mounted) return;
    setState(() => iniciando = false);
    await pintarDestino();
    if (confirmado && origen != null) {
      await trazar();
    } else {
      await verRecorrido();
    }
  }

  Future<void> cargarEstilo() async {
    if (mapa == null || !mounted) return;
    try {
      await mapa!.addGeoJsonSource('ruta-completa', _linea(const []));
      await mapa!.addLineLayer(
        'ruta-completa',
        'ruta-pasada',
        const ml.LineLayerProperties(
          lineColor: '#B2C3BF',
          lineWidth: 7,
          lineCap: 'round',
          lineJoin: 'round',
        ),
      );
      await mapa!.addGeoJsonSource('ruta-pendiente', _linea(const []));
      await mapa!.addLineLayer(
        'ruta-pendiente',
        'ruta-borde',
        const ml.LineLayerProperties(
          lineColor: '#FFFFFF',
          lineWidth: 11,
          lineCap: 'round',
          lineJoin: 'round',
        ),
      );
      await mapa!.addLineLayer(
        'ruta-pendiente',
        'ruta-activa',
        const ml.LineLayerProperties(
          lineColor: '#007A73',
          lineWidth: 7,
          lineCap: 'round',
          lineJoin: 'round',
        ),
      );
      await mapa!.addGeoJsonSource('destino', _punto(null));
      await mapa!.addCircleLayer(
        'destino',
        'destino-halo',
        const ml.CircleLayerProperties(
          circleColor: '#FFFFFF',
          circleRadius: 14,
          circleStrokeColor: '#12374B',
          circleStrokeWidth: 2,
        ),
      );
      await mapa!.addCircleLayer(
        'destino',
        'destino-centro',
        const ml.CircleLayerProperties(circleColor: '#007A73', circleRadius: 7),
      );
      if (!mounted) return;
      setState(() => listo = true);
      await pintarDestino();
      await pintarRuta();
      await pintarPosicion();
      if (origen != null && seguir) {
        await centrar();
      } else {
        await verRecorrido();
      }
    } catch (_) {
      if (mounted) {
        setState(
          () => error =
              'No se pudo preparar el mapa. Probá volver a abrirlo con conexión.',
        );
      }
    }
  }

  Map<String, dynamic> _linea(List<LatLng> ps) => {
    'type': 'FeatureCollection',
    'features': ps.length < 2
        ? []
        : [
            {
              'type': 'Feature',
              'properties': <String, dynamic>{},
              'geometry': {
                'type': 'LineString',
                'coordinates': ps
                    .map((p) => [p.longitude, p.latitude])
                    .toList(),
              },
            },
          ],
  };
  Map<String, dynamic> _punto(LatLng? p) => {
    'type': 'FeatureCollection',
    'features': p == null
        ? []
        : [
            {
              'type': 'Feature',
              'properties': <String, dynamic>{},
              'geometry': {
                'type': 'Point',
                'coordinates': [p.longitude, p.latitude],
              },
            },
          ],
  };
  Future<void> pintarDestino() async {
    if (listo && mapa != null) {
      try {
        await mapa!.setGeoJsonSource('destino', _punto(destino));
      } catch (_) {}
    }
  }

  Future<void> pintarRuta() async {
    if (!listo || mapa == null) return;
    try {
      await mapa!.setGeoJsonSource('ruta-completa', _linea(ruta?.puntos ?? []));
      await mapa!.setGeoJsonSource(
        'ruta-pendiente',
        _linea(seguimiento?.pendientes(progreso) ?? ruta?.puntos ?? []),
      );
    } catch (_) {}
  }

  Future<void> pintarPosicion() async {
    final p = ultimaPosicion;
    if (!listo || mapa == null || p == null) return;
    try {
      await mapa!.updateManualLocation(
        ml.ManualLocationUpdate(
          target: ml.LatLng(p.latitude, p.longitude),
          horizontalAccuracy: p.accuracy,
          bearing: rumbo,
          speed: p.speed.isFinite ? math.max(0, p.speed) : 0,
          timestamp: p.timestamp,
        ),
      );
    } catch (_) {}
  }

  Future<void> centrar() async {
    if (!listo || mapa == null || origen == null || !mounted) return;
    try {
      final navegando = confirmado && ruta != null;
      final camera = ml.CameraUpdate.newCameraPosition(
        ml.CameraPosition(
          target: punto(origen!),
          zoom: navegando ? 17 : 15.5,
          bearing: navegando ? rumbo : 0,
          tilt: navegando ? 40 : 0,
        ),
      );
      if (MediaQuery.disableAnimationsOf(context)) {
        await mapa!.moveCamera(camera);
      } else {
        await mapa!.animateCamera(
          camera,
          duration: const Duration(milliseconds: 850),
        );
      }
    } catch (_) {}
  }

  Future<void> verRecorrido() async {
    if (!listo || mapa == null) return;
    final ps = ruta?.puntos ?? [?origen, ?destino];
    if (ps.isEmpty) return;
    setState(() => seguir = false);
    final duracion = movimiento(context, 500);
    try {
      if (ps.length < 2) {
        await mapa!.animateCamera(
          ml.CameraUpdate.newLatLngZoom(punto(ps.first), 15),
        );
        return;
      }
      var sur = ps.first.latitude,
          norte = sur,
          oeste = ps.first.longitude,
          este = oeste;
      for (final p in ps) {
        sur = math.min(sur, p.latitude);
        norte = math.max(norte, p.latitude);
        oeste = math.min(oeste, p.longitude);
        este = math.max(este, p.longitude);
      }
      if (norte - sur < .0001) norte = sur + .0001;
      if (este - oeste < .0001) este = oeste + .0001;
      await mapa!.moveCamera(
        ml.CameraUpdate.newCameraPosition(
          ml.CameraPosition(target: punto(ps.first), zoom: 14),
        ),
      );
      await mapa!.animateCamera(
        ml.CameraUpdate.newLatLngBounds(
          ml.LatLngBounds(
            southwest: ml.LatLng(sur, oeste),
            northeast: ml.LatLng(norte, este),
          ),
          left: 48,
          right: 48,
          top: 190,
          bottom: 270,
        ),
        duration: duracion,
      );
    } catch (_) {}
  }

  Future<void> trazar({bool forzar = false}) async {
    if (origen == null || destino == null || trazando) return;
    if (!forzar &&
        ultimaSolicitudRuta != null &&
        DateTime.now().difference(ultimaSolicitudRuta!) <
            const Duration(seconds: 20)) {
      return;
    }
    ultimaSolicitudRuta = DateTime.now();
    final g = ++generacion;
    final d = destino!;
    setState(() => trazando = true);
    try {
      final r = await servicio.trazar(origen!, d);
      if (!mounted || g != generacion) return;
      final nuevo = SeguimientoRuta(r);
      setState(() {
        ruta = r;
        seguimiento = nuevo;
        error = null;
        if (ultimaPosicion != null) {
          progreso = nuevo.actualizar(
            origen!,
            precision: ultimaPosicion!.accuracy,
            fecha: ultimaPosicion!.timestamp,
          );
        }
      });
      await pintarRuta();
      if (seguir) await centrar();
    } catch (e) {
      if (mounted && g == generacion) {
        setState(
          () => error = e is FormatException
              ? e.message
              : 'No se pudo calcular el recorrido. Vamos a volver a intentarlo.',
        );
      }
    } finally {
      if (mounted && g == generacion) setState(() => trazando = false);
    }
  }

  Future<void> confirmarDestino() async {
    final p = destino;
    if (p == null) {
      throw const FormatException('Mantené presionado el destino en el mapa.');
    }
    final g = generacion;
    await widget.negocio.fijarUbicacion(cliente.id, p.latitude, p.longitude);
    if (!mounted || g != generacion) return;
    setState(() {
      confirmado = true;
      seguir = true;
      ultimaSolicitudRuta = null;
    });
    await trazar();
  }

  void elegirDestino(ml.LatLng p) {
    generacion++;
    setState(() {
      destino = LatLng(p.latitude, p.longitude);
      confirmado = false;
      ruta = null;
      seguimiento = null;
      progreso = null;
      trazando = false;
      seguir = false;
      nombreDestino = 'Destino elegido en el mapa';
    });
    unawaited(pintarDestino());
    unawaited(pintarRuta());
  }

  Future<void> externo() async {
    if (destino == null) return;
    final uri = Uri(
      scheme: 'geo',
      path: '${destino!.latitude},${destino!.longitude}',
      queryParameters: {'q': '${destino!.latitude},${destino!.longitude}'},
    );
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication) &&
        mounted) {
      setState(() => error = 'No se pudo abrir el GPS externo.');
    }
  }

  IconData get iconoPaso {
    final paso = progreso?.paso;
    if (progreso?.llegado == true) return Icons.flag_rounded;
    if (paso?.giro == 'uturn') return Icons.u_turn_left_rounded;
    if (paso?.tipo == 'roundabout' || paso?.tipo == 'rotary') {
      return Icons.roundabout_right_rounded;
    }
    if (paso?.giro.contains('left') == true) return Icons.turn_left_rounded;
    if (paso?.giro.contains('right') == true) return Icons.turn_right_rounded;
    return Icons.straight_rounded;
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: widget.negocio,
    builder: (context, _) {
      final c = cliente;
      final nav = confirmado && ruta != null;
      final llegado = progreso?.llegado == true;
      final distancia = progreso?.restantes ?? ruta?.metros ?? 0;
      final segundos = progreso?.segundosRestantes ?? ruta?.segundos ?? 0;
      return Scaffold(
        body: LayoutBuilder(
          builder: (context, limits) {
            final ancho = limits.maxWidth > limits.maxHeight;
            final safe = MediaQuery.paddingOf(context);
            final panel = FichaDestinoNavegacion(
              nombre: c.nombre,
              direccion: confirmado
                  ? c.direccion
                  : (nombreDestino ?? c.direccion),
              pedido: c.pedido,
              eta: nav
                  ? (llegado
                        ? 'Llegaste'
                        : '${math.max(1, (segundos / 60).ceil())} min')
                  : '',
              distancia: nav ? distanciaNavegacion(distancia) : '',
              estado: confirmado
                  ? (nav
                        ? 'Llegada estimada · sin tránsito en vivo'
                        : origen == null
                        ? 'Activá el GPS para iniciar el recorrido.'
                        : 'Preparando recorrido…')
                  : 'Mantené presionado el mapa para ajustar el destino.',
              error: error,
              llegado: llegado,
              confirmando: !confirmado,
              textoAccion: confirmado
                  ? 'Registrar entrega'
                  : 'Confirmar destino',
              accionPrincipal: confirmado
                  ? () => abrir(
                      context,
                      Entrega(negocio: widget.negocio, cliente: c),
                    )
                  : confirmarDestino,
              cobrar: confirmado
                  ? () => abrir(
                      context,
                      Cobro(negocio: widget.negocio, cliente: c),
                    )
                  : null,
              opciones: PopupMenuButton<String>(
                tooltip: 'Opciones del recorrido',
                onSelected: (v) {
                  if (v == 'corregir') {
                    setState(() => confirmado = false);
                  } else if (v == 'gps') {
                    unawaited(activarGps());
                  } else if (v == 'ruta') {
                    unawaited(trazar(forzar: true));
                  } else if (v == 'externo') {
                    unawaited(externo());
                  }
                },
                itemBuilder: (_) => [
                  const PopupMenuItem(
                    value: 'gps',
                    child: Text('Volver a buscar GPS'),
                  ),
                  const PopupMenuItem(
                    value: 'corregir',
                    child: Text('Corregir destino'),
                  ),
                  if (confirmado)
                    const PopupMenuItem(
                      value: 'ruta',
                      child: Text('Recalcular recorrido'),
                    ),
                  if (destino != null)
                    const PopupMenuItem(
                      value: 'externo',
                      child: Text('Abrir GPS externo'),
                    ),
                ],
              ),
            );
            return Stack(
              children: [
                Positioned.fill(
                  child: ml.MapLibreMap(
                    styleString: 'assets/mapa_estilo.json',
                    initialCameraPosition: ml.CameraPosition(
                      target: punto(
                        destino ?? origen ?? const LatLng(-34.6, -58.4),
                      ),
                      zoom: 14,
                    ),
                    onMapCreated: (m) => mapa = m,
                    onStyleLoadedCallback: () => unawaited(cargarEstilo()),
                    locationSource: const ml.ManualLocationSource(),
                    myLocationEnabled: origen != null,
                    myLocationRenderMode: origen != null
                        ? ml.MyLocationRenderMode.gps
                        : ml.MyLocationRenderMode.normal,
                    myLocationStyle: const ml.MyLocationStyle(
                      fillColor: acento,
                      bearingColor: acento,
                      accuracyColor: acento,
                      pulseEnabled: false,
                    ),
                    compassEnabled: false,
                    attributionEnabled: true,
                    attributionButtonPosition:
                        ml.AttributionButtonPosition.bottomLeft,
                    attributionButtonMargins: math.Point<double>(
                      8,
                      ancho ? 12 : 260 + safe.bottom,
                    ),
                    onMapLongClick: (_, p) => elegirDestino(p),
                    onMapClick: (_, p) {
                      if (!confirmado) elegirDestino(p);
                    },
                    onCameraMoveStarted: (reason) {
                      if (reason == ml.CameraMoveReason.gesture && seguir) {
                        setState(() => seguir = false);
                      }
                    },
                    trackCameraPosition: false,
                  ),
                ),
                Positioned(
                  top: safe.top + 12,
                  left: 16,
                  right: ancho ? 352 : 16,
                  child: IndicacionNavegacion(
                    texto: llegado
                        ? 'Estás en el destino'
                        : nav
                        ? (progreso?.paso?.texto ?? 'Seguí el recorrido')
                        : origen == null
                        ? 'Buscando tu ubicación'
                        : 'Elegí el destino',
                    distancia: nav && !llegado
                        ? 'En ${distanciaNavegacion(progreso?.hastaPaso ?? distancia)}'
                        : '',
                    estado: !gpsVivo
                        ? 'Esperando señal GPS'
                        : ultimaPosicion!.accuracy > 35
                        ? 'GPS con poca precisión'
                        : 'GPS en vivo',
                    gpsActivo: gpsVivo && ultimaPosicion!.accuracy <= 35,
                    icono: iconoPaso,
                    recalculando: trazando || iniciando,
                    volver: () => Navigator.pop(context),
                  ),
                ),
                Positioned(
                  right: ancho ? 352 : 16,
                  top: safe.top + 190,
                  child: Column(
                    children: [
                      ControlMapa(
                        texto: 'Seguir mi ubicación',
                        icono: Icons.my_location_rounded,
                        activo: seguir,
                        accion: origen == null
                            ? () => unawaited(activarGps())
                            : () {
                                setState(() => seguir = true);
                                unawaited(centrar());
                              },
                      ),
                      ControlMapa(
                        texto: 'Ver recorrido completo',
                        icono: Icons.route_outlined,
                        accion: () => unawaited(verRecorrido()),
                      ),
                    ],
                  ),
                ),
                if (ancho)
                  Positioned(
                    top: safe.top + 12,
                    bottom: safe.bottom + 12,
                    right: 16,
                    width: 320,
                    child: SingleChildScrollView(child: panel),
                  )
                else
                  Positioned(
                    left: 16,
                    right: 16,
                    bottom: safe.bottom + 16,
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        maxHeight: limits.maxHeight * .43,
                      ),
                      child: SingleChildScrollView(child: panel),
                    ),
                  ),
              ],
            );
          },
        ),
      );
    },
  );
}
