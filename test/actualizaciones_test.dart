import 'package:flutter_test/flutter_test.dart';
import 'package:mi_reparto/actualizaciones.dart';

void main() {
  Map<String, dynamic> datos() => {
    'app': 'mi-reparto',
    'package': 'com.neaserisgod.mireparto',
    'version': '1.0.0+1001',
    'build': 1001,
    'url': '$servidorActualizaciones/api/update/file?app=mi-reparto&build=1001',
    'sha256': 'a' * 64,
    'size': 100,
    'notes': 'Mejoras',
  };
  test('solo acepta el APK de esta app desde el servidor configurado', () {
    final j = datos();
    expect(
      VersionDisponible.desdeJson(
        j,
        'mi-reparto',
        'com.neaserisgod.mireparto',
      ).build,
      1001,
    );
    for (final cambio in [
      {'app': 'otra'},
      {'package': 'otro'},
      {'url': 'https://otro.example/app.apk'},
      {'sha256': 'invalido'},
      {'size': maximoApk + 1},
    ]) {
      expect(
        () => VersionDisponible.desdeJson(
          {...j, ...cambio},
          'mi-reparto',
          'com.neaserisgod.mireparto',
        ),
        throwsFormatException,
      );
    }
  });
}
