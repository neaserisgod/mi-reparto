import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';
import 'diseno.dart';
import 'negocio.dart';
import 'pantallas.dart' show Entrega, Cobro, abrir, dinero;

class DestinoMapa {
  const DestinoMapa(this.punto, this.nombre);
  final LatLng punto;
  final String nombre;
}

class RecorridoMapa {
  const RecorridoMapa(
    this.puntos,
    this.metros,
    this.segundos,
    this.indicaciones,
  );
  final List<LatLng> puntos;
  final double metros, segundos;
  final List<String> indicaciones;
}

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
                'MiReparto/0.2 (https://github.com/neaserisgod/mi-reparto)',
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
          headers: {'User-Agent': 'MiReparto/0.2'},
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
          'arrive' => 'Llegaste al destino',
          'roundabout' || 'rotary' => 'Tomá la rotonda',
          'turn' => 'Doblá $lado',
          'fork' => 'Mantenete $lado',
          'merge' => 'Incorporate $lado',
          _ => 'Continuá $lado',
        };
        pasos.add('$texto${calle.isEmpty ? '' : ' por $calle'}');
      }
    }
    return RecorridoMapa(
      puntos,
      (ruta['distance'] as num).toDouble(),
      (ruta['duration'] as num).toDouble(),
      pasos,
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

class _MapaRepartoState extends State<MapaReparto> {
  final mapa = MapController();
  final servicio = ServicioMapa();
  StreamSubscription<Position>? ubicacion;
  LatLng? origen, destino;
  RecorridoMapa? ruta;
  String? error, nombreDestino;
  bool ocupado = true, confirmado = false, listo = false, seguir = true;
  int generacion = 0;
  Cliente get cliente =>
      widget.negocio.clientes.firstWhere((c) => c.id == widget.clienteId);
  @override
  void initState() {
    super.initState();
    final c = cliente;
    if (c.latitud != null) {
      destino = LatLng(c.latitud!, c.longitud!);
      confirmado = true;
      nombreDestino = c.direccion;
    }
    iniciar();
  }

  @override
  void dispose() {
    generacion++;
    ubicacion?.cancel();
    servicio.cerrar();
    mapa.dispose();
    super.dispose();
  }

  Future<void> iniciar() async {
    setState(() {
      ocupado = true;
      error = null;
    });
    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        throw const FormatException(
          'Activá la ubicación del celular para ver tu posición. Igual podés elegir el destino en el mapa.',
        );
      }
      var permiso = await Geolocator.checkPermission();
      if (permiso == LocationPermission.denied) {
        permiso = await Geolocator.requestPermission();
      }
      if (permiso == LocationPermission.denied ||
          permiso == LocationPermission.deniedForever) {
        throw const FormatException(
          'La ubicación no está habilitada. Podés activar el permiso en Ajustes o elegir el destino en el mapa.',
        );
      }
      final p = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 20),
        ),
      );
      if (!mounted) return;
      setState(() => origen = LatLng(p.latitude, p.longitude));
      ubicacion =
          Geolocator.getPositionStream(
            locationSettings: const LocationSettings(
              accuracy: LocationAccuracy.high,
              distanceFilter: 10,
            ),
          ).listen(
            (p) {
              if (!mounted) return;
              setState(() => origen = LatLng(p.latitude, p.longitude));
              if (seguir && listo) mapa.move(origen!, mapa.camera.zoom);
            },
            onError: (_) {
              if (mounted) {
                setState(
                  () => error =
                      'Se perdió la señal GPS. La posición puede estar desactualizada.',
                );
              }
            },
          );
    } catch (e) {
      if (mounted) {
        setState(
          () => error = e is FormatException
              ? e.message
              : 'No se pudo obtener la ubicación. Podés elegir el destino en el mapa.',
        );
      }
    }
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
                'No encontramos esa dirección cerca tuyo. Tocá el lugar correcto en el mapa.',
          );
        }
      } catch (e) {
        if (mounted) {
          setState(
            () => error = e is FormatException
                ? e.message
                : 'No se pudo buscar la dirección. Tocá el destino en el mapa.',
          );
        }
      }
    }
    if (!mounted) return;
    setState(() => ocupado = false);
    encuadrar();
    if (confirmado && origen != null) await trazar();
  }

  void encuadrar() {
    if (!listo) return;
    if (origen != null && destino != null) {
      mapa.fitCamera(
        CameraFit.bounds(
          bounds: LatLngBounds.fromPoints([origen!, destino!]),
          padding: const EdgeInsets.all(48),
          maxZoom: 16,
        ),
      );
    } else if (destino != null || origen != null) {
      mapa.move(destino ?? origen!, 15);
    }
  }

  Future<void> trazar() async {
    if (origen == null || destino == null) return;
    final g = ++generacion;
    final d = destino!;
    setState(() {
      ocupado = true;
      error = null;
    });
    try {
      final r = await servicio.trazar(origen!, d);
      if (mounted && g == generacion) {
        setState(() => ruta = r);
        if (listo && r.puntos.length > 1) {
          mapa.fitCamera(
            CameraFit.bounds(
              bounds: LatLngBounds.fromPoints(r.puntos),
              padding: const EdgeInsets.all(36),
              maxZoom: 16,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted && g == generacion) {
        setState(
          () => error = e is FormatException
              ? e.message
              : 'No se pudo calcular el recorrido.',
        );
      }
    } finally {
      if (mounted && g == generacion) setState(() => ocupado = false);
    }
  }

  Future<void> confirmarDestino() async {
    if (destino == null) return;
    final seleccion = generacion;
    await widget.negocio.fijarUbicacion(
      cliente.id,
      destino!.latitude,
      destino!.longitude,
    );
    if (!mounted || seleccion != generacion) return;
    setState(() => confirmado = true);
    await trazar();
  }

  Future<void> externo() async {
    final d = destino;
    if (d == null) return;
    final uri = Uri.https('www.google.com', '/maps/dir/', {
      'api': '1',
      'destination': '${d.latitude},${d.longitude}',
      'travelmode': 'driving',
    });
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication) &&
        mounted) {
      setState(() => error = 'No se pudo abrir el GPS externo.');
    }
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: widget.negocio,
    builder: (context, _) {
      final c = cliente;
      return Scaffold(
        appBar: AppBar(
          title: Text(c.nombre),
          actions: [
            IconButton(
              tooltip: 'Mi ubicación',
              onPressed: origen == null
                  ? null
                  : () {
                      setState(() => seguir = true);
                      mapa.move(origen!, 16);
                    },
              icon: const Icon(Icons.my_location_rounded),
            ),
          ],
        ),
        body: SafeArea(
          top: false,
          child: LayoutBuilder(
            builder: (context, limites) {
              final mapaVista = Stack(
                children: [
                  FlutterMap(
                    mapController: mapa,
                    options: MapOptions(
                      initialCenter:
                          destino ?? origen ?? const LatLng(-34.6, -58.4),
                      initialZoom: 12,
                      onMapReady: () {
                        listo = true;
                        encuadrar();
                      },
                      onPositionChanged: (_, gesto) {
                        if (gesto) seguir = false;
                      },
                      onTap: (_, p) {
                        generacion++;
                        setState(() {
                          destino = p;
                          confirmado = false;
                          ruta = null;
                          ocupado = false;
                          nombreDestino = 'Ubicación elegida en el mapa';
                          seguir = false;
                        });
                      },
                    ),
                    children: [
                      TileLayer(
                        urlTemplate:
                            'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                        userAgentPackageName: 'com.neaserisgod.mireparto',
                      ),
                      if (ruta != null)
                        PolylineLayer(
                          polylines: [
                            Polyline(
                              points: ruta!.puntos,
                              color: acento,
                              strokeWidth: 6,
                              borderColor: Colors.white,
                              borderStrokeWidth: 2,
                            ),
                          ],
                        ),
                      MarkerLayer(
                        markers: [
                          if (origen != null)
                            Marker(
                              point: origen!,
                              width: 42,
                              height: 42,
                              child: Semantics(
                                label: 'Tu ubicación',
                                child: Icon(
                                  Icons.navigation_rounded,
                                  color: Color(0xFF175ED0),
                                  size: 36,
                                ),
                              ),
                            ),
                          if (destino != null)
                            Marker(
                              point: destino!,
                              width: 48,
                              height: 48,
                              child: Semantics(
                                label: 'Destino del cliente',
                                child: Icon(
                                  Icons.location_on_rounded,
                                  color: Color(0xFFAA3246),
                                  size: 46,
                                ),
                              ),
                            ),
                        ],
                      ),
                      RichAttributionWidget(
                        attributions: [
                          TextSourceAttribution(
                            'OpenStreetMap contributors',
                            onTap: () => launchUrl(
                              Uri.parse(
                                'https://www.openstreetmap.org/copyright',
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  if (ocupado)
                    const Positioned(
                      top: 16,
                      left: 16,
                      right: 16,
                      child: LinearProgressIndicator(),
                    ),
                  if (origen == null && !ocupado)
                    Positioned(
                      top: 16,
                      left: 16,
                      right: 16,
                      child: Material(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Text(
                            destino == null
                                ? 'Sin posición GPS. Tocá el destino en el mapa.'
                                : 'Mostrando el destino guardado. Activá el GPS para calcular el recorrido.',
                          ),
                        ),
                      ),
                    ),
                ],
              );
              final panel = ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  Text(
                    c.direccion.isEmpty
                        ? 'Cliente sin dirección escrita'
                        : c.direccion,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  if (error != null)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Text(
                        error!,
                        style: const TextStyle(color: Color(0xFFAA3246)),
                      ),
                    ),
                  if (!confirmado && destino != null) ...[
                    Text(
                      nombreDestino ?? 'Destino seleccionado',
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 8),
                    Accion(
                      'Confirmar destino',
                      confirmarDestino,
                      icono: Icons.location_on_outlined,
                    ),
                  ] else if (confirmado) ...[
                    if (ruta != null)
                      Text(
                        '${(ruta!.metros / 1000).toStringAsFixed(1)} km · ${(ruta!.segundos / 60).ceil()} min estimados',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    TextButton.icon(
                      onPressed: ocupado || origen == null ? null : trazar,
                      icon: const Icon(Icons.alt_route_rounded),
                      label: const Text('Actualizar recorrido'),
                    ),
                    if (ruta != null && ruta!.indicaciones.isNotEmpty)
                      ExpansionTile(
                        tilePadding: EdgeInsets.zero,
                        title: const Text('Indicaciones del recorrido'),
                        children: [
                          ...ruta!.indicaciones.map(
                            (p) => ListTile(
                              dense: true,
                              leading: const Icon(
                                Icons.subdirectory_arrow_right_rounded,
                              ),
                              title: Text(p),
                            ),
                          ),
                          const Padding(
                            padding: EdgeInsets.only(bottom: 12),
                            child: Text(
                              'Recorrido orientativo, sin tránsito en vivo ni navegación por voz.',
                            ),
                          ),
                        ],
                      ),
                    FilledButton.icon(
                      onPressed: () => abrir(
                        context,
                        Entrega(negocio: widget.negocio, cliente: c),
                      ),
                      icon: const Icon(Icons.local_shipping_outlined),
                      label: const Text('Registrar entrega'),
                    ),
                    const SizedBox(height: 8),
                    OutlinedButton.icon(
                      onPressed: () => abrir(
                        context,
                        Cobro(negocio: widget.negocio, cliente: c),
                      ),
                      icon: const Icon(Icons.payments_outlined),
                      label: Text(
                        'Cobrar · ${dinero(widget.negocio.saldo(c.id))}',
                      ),
                    ),
                    TextButton(
                      onPressed: externo,
                      child: const Text('Abrir GPS externo'),
                    ),
                    TextButton(
                      onPressed: () => setState(() {
                        confirmado = false;
                        ruta = null;
                        seguir = false;
                      }),
                      child: const Text('Corregir destino'),
                    ),
                  ],
                  if (!confirmado)
                    const Padding(
                      padding: EdgeInsets.only(top: 8),
                      child: Text(
                        'Tocá el mapa para ajustar el pin antes de confirmar. El destino queda guardado en este celular.',
                      ),
                    ),
                ],
              );
              return limites.maxWidth > limites.maxHeight
                  ? Row(
                      children: [
                        Expanded(child: mapaVista),
                        SizedBox(width: 320, child: panel),
                      ],
                    )
                  : Column(
                      children: [
                        Expanded(child: mapaVista),
                        SizedBox(height: limites.maxHeight * .45, child: panel),
                      ],
                    );
            },
          ),
        ),
      );
    },
  );
}
