import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';

class Cliente {
  const Cliente({
    required this.id,
    required this.nombre,
    this.direccion = '',
    this.telefono = '',
    this.precio = 750000,
    this.dia = 6,
    this.pedido = 0,
    this.activo = true,
  });
  final String id, nombre, direccion, telefono;
  final int precio, dia, pedido;
  final bool activo;
  Map<String, dynamic> toJson() => {
    'id': id,
    'nombre': nombre,
    'direccion': direccion,
    'telefono': telefono,
    'precio': precio,
    'dia': dia,
    'pedido': pedido,
    'activo': activo,
  };
  factory Cliente.fromJson(Map<String, dynamic> j) {
    final c = Cliente(
      id: j['id'] as String,
      nombre: j['nombre'] as String,
      direccion: j['direccion'] as String,
      telefono: j['telefono'] as String,
      precio: j['precio'] as int,
      dia: j['dia'] as int,
      pedido: j['pedido'] as int,
      activo: j['activo'] as bool,
    );
    if (c.id.isEmpty ||
        c.nombre.trim().isEmpty ||
        c.precio <= 0 ||
        c.precio > 10000000000000 ||
        c.dia < 1 ||
        c.dia > 7 ||
        c.pedido < 0) {
      throw const FormatException('Cliente inválido en el respaldo.');
    }
    return c;
  }
  Cliente conPedido(int n) => Cliente(
    id: id,
    nombre: nombre,
    direccion: direccion,
    telefono: telefono,
    precio: precio,
    dia: dia,
    pedido: n,
    activo: activo,
  );
}

class Movimiento {
  const Movimiento({
    required this.id,
    required this.fecha,
    required this.tipo,
    this.cliente,
    this.dejados = 0,
    this.pedidoDescontado = 0,
    this.retirados = 0,
    this.precio = 0,
    this.pago = 0,
    this.deuda = 0,
    this.envases = 0,
    this.llenos = 0,
    this.vacios = 0,
    this.gasto = 0,
    this.medio = 'Efectivo',
    this.nota = '',
    this.anula,
  });
  final String id, tipo, medio, nota;
  final String? cliente, anula;
  final DateTime fecha;
  final int pedidoDescontado;
  final int dejados,
      retirados,
      precio,
      pago,
      deuda,
      envases,
      llenos,
      vacios,
      gasto;
  Map<String, dynamic> toJson() => {
    'id': id,
    'fecha': fecha.toIso8601String(),
    'tipo': tipo,
    'cliente': cliente,
    'dejados': dejados,
    'pedidoDescontado': pedidoDescontado,
    'retirados': retirados,
    'precio': precio,
    'pago': pago,
    'deuda': deuda,
    'envases': envases,
    'llenos': llenos,
    'vacios': vacios,
    'gasto': gasto,
    'medio': medio,
    'nota': nota,
    'anula': anula,
  };
  factory Movimiento.fromJson(Map<String, dynamic> j) => Movimiento(
    id: j['id'] as String,
    fecha: DateTime.parse(j['fecha'] as String),
    tipo: j['tipo'] as String,
    cliente: j['cliente'] as String?,
    dejados: j['dejados'] as int,
    pedidoDescontado: (j['pedidoDescontado'] as int?) ?? 0,
    retirados: j['retirados'] as int,
    precio: j['precio'] as int,
    pago: j['pago'] as int,
    deuda: j['deuda'] as int,
    envases: j['envases'] as int,
    llenos: j['llenos'] as int,
    vacios: j['vacios'] as int,
    gasto: j['gasto'] as int,
    medio: j['medio'] as String,
    nota: j['nota'] as String,
    anula: j['anula'] as String?,
  );
}

class Negocio extends ChangeNotifier {
  Negocio({this.archivo});
  final File? archivo;
  List<Cliente> _clientes = [];
  List<Movimiento> _movimientos = [];
  List<Cliente> get clientes => List.unmodifiable(_clientes);
  List<Movimiento> get movimientos => List.unmodifiable(_movimientos);
  bool _ocupado = false;
  String nombre = 'Mi Reparto';
  static int _secuencia = 0;
  String nuevoId() =>
      '${DateTime.now().microsecondsSinceEpoch}-${_secuencia++}';
  int saldo(String id) => _movimientos
      .where((m) => m.cliente == id)
      .fold(0, (a, m) => a + m.deuda - m.pago);
  int envases(String id) => _movimientos
      .where((m) => m.cliente == id)
      .fold(0, (a, m) => a + m.envases);
  int get llenos => _movimientos.fold(0, (a, m) => a + m.llenos);
  int get vacios => _movimientos.fold(0, (a, m) => a + m.vacios);
  int get porCobrar =>
      _clientes.fold(0, (a, c) => a + (saldo(c.id) > 0 ? saldo(c.id) : 0));
  bool anulado(Movimiento m) =>
      m.anula != null || _movimientos.any((x) => x.anula == m.id);
  String exportar() => const JsonEncoder.withIndent('  ').convert({
    'app': 'mi-reparto',
    'version': 1,
    'nombre': nombre,
    'clientes': _clientes.map((c) => c.toJson()).toList(),
    'movimientos': _movimientos.map((m) => m.toJson()).toList(),
  });
  static Negocio decodificar(String texto) {
    try {
      final j = jsonDecode(texto) as Map<String, dynamic>;
      if (j['app'] != 'mi-reparto' || j['version'] != 1) {
        throw const FormatException('El respaldo no es de Mi Reparto.');
      }
      final n = Negocio();
      n.nombre = j['nombre'] as String;
      if (n.nombre.trim().isEmpty) {
        throw const FormatException('Falta el nombre.');
      }
      n._clientes = (j['clientes'] as List)
          .map((x) => Cliente.fromJson(Map<String, dynamic>.from(x as Map)))
          .toList();
      n._movimientos = (j['movimientos'] as List)
          .map((x) => Movimiento.fromJson(Map<String, dynamic>.from(x as Map)))
          .toList();
      n._validar();
      return n;
    } on FormatException {
      rethrow;
    } catch (_) {
      throw const FormatException('El respaldo está incompleto o dañado.');
    }
  }

  void _validar() {
    final ids = _clientes.map((c) => c.id).toSet();
    final mids = _movimientos.map((m) => m.id).toSet();
    if (ids.length != _clientes.length || mids.length != _movimientos.length) {
      throw const FormatException('Hay identificadores repetidos.');
    }
    final anulados = <String>{};
    for (final m in _movimientos) {
      if (m.id.isEmpty ||
          (m.cliente != null && !ids.contains(m.cliente)) ||
          ![
            'Entrega',
            'Cobro',
            'Saldo inicial',
            'Envases iniciales',
            'Ingreso',
            'Envasado',
            'Gasto',
            'Anulación',
          ].contains(m.tipo)) {
        throw const FormatException('Movimiento inválido.');
      }
      if ([
        m.dejados,
        m.retirados,
        m.precio,
        m.pago,
        m.deuda,
        m.envases,
        m.llenos,
        m.vacios,
        m.gasto,
      ].any((v) => v.abs() > 10000000000000)) {
        throw const FormatException('Importe fuera de rango.');
      }
      if (m.anula != null) {
        final originales = _movimientos.where(
          (x) => x.id == m.anula && x.anula == null,
        );
        if (originales.length != 1 || !anulados.add(m.anula!)) {
          throw const FormatException('Anulación inválida.');
        }
        final o = originales.single;
        if (m.tipo != 'Anulación' ||
            m.cliente != o.cliente ||
            m.deuda != -o.deuda ||
            m.pago != -o.pago ||
            m.envases != -o.envases ||
            m.llenos != -o.llenos ||
            m.vacios != -o.vacios ||
            m.gasto != -o.gasto) {
          throw const FormatException('Anulación inconsistente.');
        }
      } else {
        if (m.pago < 0 ||
            m.gasto < 0 ||
            m.precio < 0 ||
            m.dejados < 0 ||
            m.retirados < 0) {
          throw const FormatException('Cantidad inválida.');
        }
        if (m.tipo == 'Entrega' &&
            (m.cliente == null ||
                m.deuda != m.dejados * m.precio ||
                m.envases != m.dejados - m.retirados ||
                m.llenos != -m.dejados ||
                m.vacios != m.retirados)) {
          throw const FormatException('Entrega inconsistente.');
        }
      }
    }
    if (llenos < 0 || vacios < 0 || _clientes.any((c) => envases(c.id) < 0)) {
      throw const FormatException(
        'El movimiento dejaría envases o stock negativos.',
      );
    }
  }

  Future<void> cargar() async {
    if (archivo != null && await archivo!.exists()) {
      final n = decodificar(await archivo!.readAsString());
      _clientes = n._clientes;
      _movimientos = n._movimientos;
      nombre = n.nombre;
    }
  }

  Future<void> _cambiar(void Function() cambio) async {
    if (_ocupado) throw StateError('Esperá a que termine de guardarse.');
    _ocupado = true;
    final cs = List<Cliente>.of(_clientes),
        ms = List<Movimiento>.of(_movimientos);
    final anterior = nombre;
    try {
      cambio();
      _validar();
      if (archivo != null) {
        final temporal = File('${archivo!.path}.tmp');
        await temporal.writeAsString(exportar(), flush: true);
        await temporal.rename(archivo!.path);
      }
    } catch (_) {
      _clientes = cs;
      _movimientos = ms;
      nombre = anterior;
      rethrow;
    } finally {
      _ocupado = false;
    }
    notifyListeners();
  }

  Future<void> restaurar(String texto) async {
    final n = decodificar(texto);
    if (archivo != null && await archivo!.exists()) {
      await File(
        '${archivo!.path}.antes-de-importar',
      ).writeAsString(exportar(), flush: true);
    }
    await _cambiar(() {
      _clientes = n._clientes;
      _movimientos = n._movimientos;
      nombre = n.nombre;
    });
  }

  Future<void> guardarCliente(Cliente c) => _cambiar(() {
    Cliente.fromJson(c.toJson());
    final i = _clientes.indexWhere((x) => x.id == c.id);
    if (i < 0) {
      _clientes.add(c);
    } else {
      _clientes[i] = c;
    }
  });
  Future<void> renombrar(String texto) => _cambiar(
    () => nombre = texto.trim().isEmpty ? 'Mi Reparto' : texto.trim(),
  );
  Future<void> entregar({
    required Cliente cliente,
    required int dejados,
    required int retirados,
    required int precio,
    required int pago,
    required String medio,
    String nota = '',
  }) => _cambiar(() {
    if (!cliente.activo ||
        !_clientes.any((c) => c.id == cliente.id) ||
        dejados < 0 ||
        retirados < 0 ||
        precio <= 0 ||
        pago < 0 ||
        (dejados == 0 && retirados == 0)) {
      throw ArgumentError('Revisá las cantidades y el precio.');
    }
    if (dejados > llenos) {
      throw ArgumentError(
        'No hay suficientes bidones llenos. Registrá el stock o el envasado.',
      );
    }
    if (retirados > envases(cliente.id) + dejados) {
      throw ArgumentError(
        'No podés retirar más envases de los que tiene el cliente. Revisá su saldo inicial de envases.',
      );
    }
    _movimientos.add(
      Movimiento(
        id: nuevoId(),
        fecha: DateTime.now(),
        tipo: 'Entrega',
        cliente: cliente.id,
        dejados: dejados,
        pedidoDescontado: dejados.clamp(
          0,
          _clientes.firstWhere((c) => c.id == cliente.id).pedido,
        ),
        retirados: retirados,
        precio: precio,
        pago: pago,
        deuda: dejados * precio,
        envases: dejados - retirados,
        llenos: -dejados,
        vacios: retirados,
        medio: medio,
        nota: nota,
      ),
    );
    final i = _clientes.indexWhere((c) => c.id == cliente.id);
    final c = _clientes[i];
    _clientes[i] = c.conPedido((c.pedido - dejados).clamp(0, c.pedido));
  });
  Future<void> cobrar(Cliente c, int monto, String medio, {String nota = ''}) =>
      _cambiar(() {
        if (monto <= 0) throw ArgumentError('El pago debe ser mayor a cero.');
        _movimientos.add(
          Movimiento(
            id: nuevoId(),
            fecha: DateTime.now(),
            tipo: 'Cobro',
            cliente: c.id,
            pago: monto,
            medio: medio,
            nota: nota,
          ),
        );
      });
  Future<void> anular(Movimiento m) => _cambiar(() {
    if (anulado(m) || !_movimientos.any((x) => x.id == m.id)) {
      throw ArgumentError('Este movimiento ya fue anulado.');
    }
    _movimientos.add(
      Movimiento(
        id: nuevoId(),
        fecha: DateTime.now(),
        tipo: 'Anulación',
        cliente: m.cliente,
        pago: -m.pago,
        deuda: -m.deuda,
        envases: -m.envases,
        llenos: -m.llenos,
        vacios: -m.vacios,
        gasto: -m.gasto,
        anula: m.id,
        nota:
            'Anula ${m.tipo.toLowerCase()} del ${m.fecha.day}/${m.fecha.month}',
      ),
    );
    if (m.tipo == 'Entrega' && m.cliente != null) {
      final i = _clientes.indexWhere((c) => c.id == m.cliente);
      _clientes[i] = _clientes[i].conPedido(
        _clientes[i].pedido + m.pedidoDescontado,
      );
    }
  });
  Future<void> abrirCuenta(
    Cliente c,
    int saldoInicial,
    int cantidad,
  ) => _cambiar(() {
    if (_movimientos.any((m) => m.cliente == c.id) ||
        cantidad < 0 ||
        cantidad > 100000) {
      throw ArgumentError(
        'El saldo inicial solo se carga antes del primer movimiento. Revisá los envases.',
      );
    }
    if (saldoInicial == 0 && cantidad == 0) {
      throw ArgumentError('Ingresá un saldo o una cantidad de envases.');
    }
    if (saldoInicial != 0) {
      _movimientos.add(
        Movimiento(
          id: nuevoId(),
          fecha: DateTime.now(),
          tipo: 'Saldo inicial',
          cliente: c.id,
          deuda: saldoInicial,
        ),
      );
    }
    if (cantidad != 0) {
      _movimientos.add(
        Movimiento(
          id: nuevoId(),
          fecha: DateTime.now(),
          tipo: 'Envases iniciales',
          cliente: c.id,
          envases: cantidad,
        ),
      );
    }
  });
  Future<void> registrarStock(
    String tipo, {
    required int llenos,
    required int vacios,
    required int costo,
    required String nota,
  }) => _cambiar(() {
    if (llenos < 0 || vacios < 0 || costo < 0) {
      throw ArgumentError('Revisá las cantidades.');
    }
    switch (tipo) {
      case 'Ingreso':
        if (llenos + vacios == 0) {
          throw ArgumentError('Ingresá al menos un bidón.');
        }
        _movimientos.add(
          Movimiento(
            id: nuevoId(),
            fecha: DateTime.now(),
            tipo: tipo,
            llenos: llenos,
            vacios: vacios,
            gasto: costo,
            nota: nota,
          ),
        );
      case 'Envasado':
        if (llenos == 0 || llenos > this.vacios) {
          throw ArgumentError(
            'Revisá la cantidad: necesitás un vacío por cada lleno.',
          );
        }
        _movimientos.add(
          Movimiento(
            id: nuevoId(),
            fecha: DateTime.now(),
            tipo: tipo,
            llenos: llenos,
            vacios: -llenos,
            gasto: costo,
            nota: nota,
          ),
        );
      case 'Gasto':
        if (costo == 0 || nota.isEmpty) {
          throw ArgumentError('Ingresá el importe y el concepto del gasto.');
        }
        _movimientos.add(
          Movimiento(
            id: nuevoId(),
            fecha: DateTime.now(),
            tipo: tipo,
            gasto: costo,
            nota: nota,
          ),
        );
      default:
        throw ArgumentError('Tipo de movimiento inválido.');
    }
  });
}
