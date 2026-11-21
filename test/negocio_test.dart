import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:mi_reparto/negocio.dart';

void main() {
  late Negocio n;
  const c = Cliente(id: 'c1', nombre: 'Cliente de prueba', pedido: 3);
  setUp(() async {
    n = Negocio();
    await n.guardarCliente(c);
    await n.registrarStock(
      'Ingreso',
      llenos: 10,
      vacios: 4,
      costo: 0,
      nota: 'Inicial',
    );
  });
  Future<void> entregar({
    int dejados = 2,
    int retirados = 1,
    int pago = 750000,
  }) => n.entregar(
    cliente: c,
    dejados: dejados,
    retirados: retirados,
    precio: 750000,
    pago: pago,
    medio: 'Transferencia',
  );
  test(
    'entrega calcula cuenta, stock, envases y pedido en un único movimiento',
    () async {
      await entregar();
      expect(n.saldo(c.id), 750000);
      expect(n.envases(c.id), 1);
      expect(n.llenos, 8);
      expect(n.vacios, 5);
      expect(n.clientes.single.pedido, 1);
    },
  );
  test('pagos parciales y saldo a favor no se confunden con envases', () async {
    await entregar();
    await n.cobrar(c, 250000, 'Efectivo');
    expect(n.saldo(c.id), 500000);
    await n.cobrar(c, 700000, 'Efectivo');
    expect(n.saldo(c.id), -200000);
    expect(n.envases(c.id), 1);
    expect(n.porCobrar, 0);
  });
  test('stock insuficiente y retiro excesivo no guardan cambios', () async {
    final antes = n.exportar();
    await expectLater(entregar(dejados: 11), throwsArgumentError);
    await expectLater(entregar(retirados: 3), throwsArgumentError);
    expect(n.exportar(), antes);
  });
  test('anulación revierte entrega y no puede repetirse', () async {
    await entregar();
    final m = n.movimientos.last;
    await n.anular(m);
    expect(n.saldo(c.id), 0);
    expect(n.envases(c.id), 0);
    expect(n.llenos, 10);
    expect(n.vacios, 4);
    expect(n.clientes.single.pedido, 3);
    await expectLater(n.anular(m), throwsArgumentError);
  });
  test('no se anula un ingreso utilizado si deja stock negativo', () async {
    final ingreso = n.movimientos.first;
    await entregar();
    final antes = n.exportar();
    await expectLater(n.anular(ingreso), throwsFormatException);
    expect(n.exportar(), antes);
  });
  test('envasar consume vacíos y suma llenos; no inventa envases', () async {
    await n.registrarStock(
      'Envasado',
      llenos: 3,
      vacios: 0,
      costo: 50000,
      nota: 'Turno',
    );
    expect(n.llenos, 13);
    expect(n.vacios, 1);
    final antes = n.exportar();
    await expectLater(
      n.registrarStock('Envasado', llenos: 2, vacios: 0, costo: 0, nota: ''),
      throwsArgumentError,
    );
    expect(n.exportar(), antes);
  });
  test(
    'respaldo conserva historial y rechaza duplicados sin perder datos',
    () async {
      await entregar();
      final texto = n.exportar();
      final nuevo = Negocio.decodificar(texto);
      expect(nuevo.exportar(), texto);
      final j = jsonDecode(texto) as Map<String, dynamic>;
      j['clientes'] = [...(j['clientes'] as List), ...(j['clientes'] as List)];
      await expectLater(n.restaurar(jsonEncode(j)), throwsFormatException);
      expect(n.exportar(), texto);
    },
  );
  test(
    'archivo persistente se vuelve a abrir y falla sin modificar memoria',
    () async {
      final dir = await Directory.systemTemp.createTemp('reparto-test');
      try {
        final f = File('${dir.path}/datos.json');
        final persistente = Negocio(archivo: f);
        await persistente.guardarCliente(c);
        final nuevo = Negocio(archivo: f);
        await nuevo.cargar();
        expect(nuevo.clientes.single.nombre, c.nombre);
        final fallido = Negocio(
          archivo: File('${dir.path}/no-existe/datos.json'),
        );
        await expectLater(
          fallido.guardarCliente(c),
          throwsA(isA<FileSystemException>()),
        );
        expect(fallido.clientes, isEmpty);
      } finally {
        await dir.delete(recursive: true);
      }
    },
  );
  test('saldo inicial y envases son separados de ingresos y ventas', () async {
    await n.abrirCuenta(c, -100000, 3);
    expect(n.saldo(c.id), -100000);
    expect(n.envases(c.id), 3);
    expect(n.movimientos.fold<int>(0, (a, m) => a + m.pago), 0);
    await expectLater(n.abrirCuenta(c, 1, 1), throwsArgumentError);
  });
  test('anular una entrega sin pedido no crea un pedido nuevo', () async {
    final c2 = Cliente(id: 'sin-pedido', nombre: 'Sin pedido');
    await n.guardarCliente(c2);
    await n.entregar(
      cliente: c2,
      dejados: 2,
      retirados: 0,
      precio: 750000,
      pago: 0,
      medio: 'Efectivo',
    );
    await n.anular(n.movimientos.last);
    expect(n.clientes.firstWhere((c) => c.id == c2.id).pedido, 0);
  });
}
