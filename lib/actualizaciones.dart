import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

const servidorActualizaciones =
    'https://apps-personales-actualizaciones.gtalovergamer.workers.dev';
const canalNativo = MethodChannel('app.personal/actualizaciones');
const maximoApk = 64 * 1024 * 1024;

class VersionDisponible {
  const VersionDisponible({
    required this.version,
    required this.build,
    required this.url,
    required this.sha256,
    required this.size,
    required this.notas,
  });
  final String version, sha256, notas;
  final int build, size;
  final Uri url;
  factory VersionDisponible.desdeJson(
    Map<String, dynamic> j,
    String app,
    String package,
  ) {
    final url = Uri.parse(j['url'] as String),
        base = Uri.parse(servidorActualizaciones);
    if (j['app'] != app ||
        j['package'] != package ||
        url.scheme != 'https' ||
        url.host != base.host ||
        url.path != '/api/update/file' ||
        url.queryParameters['app'] != app ||
        !RegExp(r'^\d+\.\d+\.\d+\+\d+$').hasMatch(j['version'] as String) ||
        !RegExp(r'^[a-f0-9]{64}$').hasMatch(j['sha256'] as String) ||
        (j['size'] as int) <= 0 ||
        (j['size'] as int) > maximoApk ||
        (j['build'] as int) < 1) {
      throw const FormatException('La actualización recibida no es válida.');
    }
    return VersionDisponible(
      version: j['version'] as String,
      build: j['build'] as int,
      url: url,
      sha256: j['sha256'] as String,
      size: j['size'] as int,
      notas: (j['notes'] as String?) ?? 'Mejoras y correcciones',
    );
  }
}

class Actualizador {
  static bool ocupado = false;
  static DateTime? ultimaConsulta;
  static Future<void> revisar(
    BuildContext context,
    String app, {
    bool manual = false,
  }) async {
    if (ocupado) return;
    if (!manual &&
        ultimaConsulta != null &&
        DateTime.now().difference(ultimaConsulta!) < const Duration(hours: 1)) {
      return;
    }
    ocupado = true;
    ultimaConsulta = DateTime.now();
    final client = http.Client();
    try {
      final info = await canalNativo.invokeMapMethod<String, dynamic>('info');
      if (info == null) {
        throw const FormatException(
          'No se pudo consultar la versión instalada.',
        );
      }
      final build = (info['build'] as num).toInt(),
          actual = '${info['version']}+$build';
      final res = await client
          .get(
            Uri.parse(
              '$servidorActualizaciones/api/update/latest.json',
            ).replace(queryParameters: {'app': app, 'version': actual}),
          )
          .timeout(const Duration(seconds: 12));
      if (res.statusCode != 200) {
        throw const FormatException(
          'No se pudo consultar actualizaciones. Probá cuando tengas conexión.',
        );
      }
      final j = jsonDecode(res.body) as Map<String, dynamic>;
      if (j['update'] != true) {
        if (manual && context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Tenés la última versión: $actual.')),
          );
        }
        return;
      }
      final v = VersionDisponible.desdeJson(j, app, info['package'] as String);
      if (v.build <= build) return;
      final dir = Directory('${(await getTemporaryDirectory()).path}/updates');
      await dir.create(recursive: true);
      final file = File('${dir.path}/$app-${v.build}.apk'),
          temporal = File('${dir.path}/$app-${v.build}.tmp');
      var valido = await file.exists() && await file.length() == v.size;
      if (valido) {
        valido =
            (await sha256.bind(file.openRead()).first).toString() == v.sha256;
      }
      if (!valido) {
        final response = await client
            .send(http.Request('GET', v.url))
            .timeout(const Duration(seconds: 20));
        if (response.statusCode != 200) {
          throw const FormatException('No se pudo descargar la actualización.');
        }
        final sink = temporal.openWrite();
        var recibidos = 0;
        try {
          await for (final chunk in response.stream.timeout(
            const Duration(seconds: 30),
          )) {
            recibidos += chunk.length;
            if (recibidos > v.size || recibidos > maximoApk) {
              throw const FormatException(
                'El tamaño de la actualización no coincide.',
              );
            }
            sink.add(chunk);
          }
        } finally {
          await sink.close();
        }
        if (recibidos != v.size ||
            (await sha256.bind(temporal.openRead()).first).toString() !=
                v.sha256) {
          await temporal.delete();
          throw const FormatException(
            'La descarga no pasó la verificación. Se descartó el archivo.',
          );
        }
        await temporal.rename(file.path);
      }
      if (!context.mounted || ModalRoute.of(context)?.isCurrent != true) return;
      final instalar = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Actualización lista'),
          content: Text(
            'Versión ${v.version}\n\n${v.notas}\n\nTus datos se conservan. Android te pedirá confirmar la instalación.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Más tarde'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Instalar'),
            ),
          ],
        ),
      );
      if (instalar == true) {
        final estado = await canalNativo.invokeMethod<String>('instalar', {
          'path': file.path,
        });
        if (estado == 'permiso' && context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Habilitá la instalación y volvé a «Buscar actualizaciones» para continuar.',
              ),
            ),
          );
        }
      }
    } catch (e) {
      if (manual && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              e is FormatException
                  ? e.message
                  : e is PlatformException
                  ? e.message ?? 'No se pudo actualizar.'
                  : 'No se pudo actualizar. Probá nuevamente cuando tengas conexión.',
            ),
          ),
        );
      }
    } finally {
      client.close();
      ocupado = false;
    }
  }
}

class ActualizacionesAutomaticas extends StatefulWidget {
  const ActualizacionesAutomaticas({
    super.key,
    required this.app,
    required this.child,
  });
  final String app;
  final Widget child;
  @override
  State<ActualizacionesAutomaticas> createState() =>
      _ActualizacionesAutomaticasState();
}

class _ActualizacionesAutomaticasState extends State<ActualizacionesAutomaticas>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) => consultar());
  }

  void consultar() {
    if (mounted) unawaited(Actualizador.revisar(context, widget.app));
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) consultar();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

class VersionInstalada extends StatefulWidget {
  const VersionInstalada({super.key});
  @override
  State<VersionInstalada> createState() => _VersionInstaladaState();
}

class _VersionInstaladaState extends State<VersionInstalada> {
  late final Future<Map<String, dynamic>?> info = canalNativo
      .invokeMapMethod<String, dynamic>('info')
      .catchError((Object _) => <String, dynamic>{});
  @override
  Widget build(BuildContext context) => FutureBuilder<Map<String, dynamic>?>(
    future: info,
    builder: (context, s) {
      final version = s.data?['version'], build = s.data?['build'];
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Text(
          version == null
              ? 'Versión de prueba'
              : 'Versión $version · Compilación $build',
          style: Theme.of(context).textTheme.bodySmall,
        ),
      );
    },
  );
}
