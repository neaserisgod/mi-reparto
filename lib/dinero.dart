// Dinero en centavos enteros. El texto usa formato argentino; los cálculos redondean con enteros.

const int centavosPorPeso = 100;

String formatearARS(
  int centavos, {
  bool conSigno = true,
  bool separado = false,
}) {
  final negativo = centavos < 0;
  final absoluto = centavos.abs();
  final pesos = (absoluto + centavosPorPeso ~/ 2) ~/ centavosPorPeso;
  final signo = negativo ? '-' : '';
  final simbolo = conSigno ? (separado ? r'$ ' : r'$') : '';
  return '$signo$simbolo${_agruparMiles(pesos)}';
}

String _agruparMiles(int pesos) {
  final texto = pesos.toString();
  final buffer = StringBuffer();
  for (var i = 0; i < texto.length; i++) {
    final posicionDesdeElFinal = texto.length - i;
    if (i != 0 && posicionDesdeElFinal % 3 == 0) buffer.write('.');
    buffer.write(texto[i]);
  }
  return buffer.toString();
}

const int maximoMontoCentavos = 10000000000000;

final _soloDigitos = RegExp(r'^\d+$');
final _miles = RegExp(r'^\d{1,3}(\.\d{3})+$');

int parsearARS(String valor) {
  final original = valor;
  var limpio = valor.replaceAll(r'$', '').replaceAll(RegExp(r'\s'), '');
  var negativo = false;
  if (limpio.startsWith('-')) {
    negativo = true;
    limpio = limpio.substring(1);
  }
  Never invalido() => throw FormatException('Monto inválido: "$original"');
  if (limpio.isEmpty) invalido();

  String entera;
  String fraccion = '';
  final coma = limpio.indexOf(',');
  if (coma != -1) {
    if (limpio.indexOf(',', coma + 1) != -1) invalido();
    entera = limpio.substring(0, coma);
    fraccion = limpio.substring(coma + 1);
    if (entera.contains('.')) {
      if (!_miles.hasMatch(entera)) invalido();
      entera = entera.replaceAll('.', '');
    }
  } else if (_miles.hasMatch(limpio) && !limpio.startsWith('0.')) {
    entera = limpio.replaceAll('.', '');
  } else {
    final punto = limpio.indexOf('.');
    if (punto == -1) {
      entera = limpio;
    } else {
      if (limpio.indexOf('.', punto + 1) != -1) invalido();
      entera = limpio.substring(0, punto);
      fraccion = limpio.substring(punto + 1);
    }
  }

  if (entera.isEmpty && fraccion.isEmpty) invalido();
  if (entera.isEmpty) entera = '0';
  if (!_soloDigitos.hasMatch(entera)) invalido();
  if (fraccion.isNotEmpty && !_soloDigitos.hasMatch(fraccion)) invalido();
  if (entera.length > 14) invalido();

  final pesos = int.parse(entera);
  final dosDecimales = fraccion.padRight(2, '0');
  var centavos = int.parse(dosDecimales.substring(0, 2));
  if (dosDecimales.length > 2 && int.parse(dosDecimales[2]) >= 5) centavos += 1;

  final total = pesos * centavosPorPeso + centavos;
  if (total > maximoMontoCentavos) invalido();
  return negativo ? -total : total;
}

int redondearHaciaArriba(int centavos, int pasoCentavos) {
  return redondearFraccionHaciaArriba(centavos, 1, pasoCentavos);
}

int redondearFraccionHaciaArriba(int numerador, int denominador, int paso) {
  if (denominador <= 0) throw ArgumentError('denominador tiene que ser > 0');
  if (paso <= 0) throw ArgumentError('paso tiene que ser > 0');
  final unidades = _ceilDiv(numerador, denominador * paso);
  return unidades * paso;
}

int _ceilDiv(int a, int b) {
  final cociente = a ~/ b; // trunca hacia cero
  return a > 0 && a % b != 0 ? cociente + 1 : cociente;
}
