import 'dart:convert';
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'dinero.dart';
import 'diseno.dart';
import 'negocio.dart';

const dias = [
  'Lunes',
  'Martes',
  'Miércoles',
  'Jueves',
  'Viernes',
  'Sábado',
  'Domingo',
];
String fecha(DateTime d) =>
    '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
String dinero(int n) =>
    '${n < 0 ? '-' : ''}${formatearARS((n.abs() ~/ 100) * 100, separado: true)}${n.abs() % 100 == 0 ? '' : ',${(n.abs() % 100).toString().padLeft(2, '0')}'}';
String campoDinero(int n) =>
    '${n ~/ 100}${n % 100 == 0 ? '' : ',${(n % 100).toString().padLeft(2, '0')}'}';
int monto(TextEditingController c, {bool permiteCero = true}) {
  final n = c.text.trim().isEmpty && permiteCero ? 0 : parsearARS(c.text);
  if (n < 0 || (!permiteCero && n == 0)) {
    throw ArgumentError(
      'Ingresá un importe ${permiteCero ? 'válido' : 'mayor a cero'}.',
    );
  }
  return n;
}

Future<void> abrir(BuildContext c, Widget w) =>
    Navigator.of(c).push(MaterialPageRoute<void>(builder: (_) => w));
Future<bool> confirmar(BuildContext c, String titulo, String texto) =>
    showDialog<bool>(
      context: c,
      builder: (c) => AlertDialog(
        title: Text(titulo),
        content: Text(texto),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c, false),
            child: const Text('Volver'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(c, true),
            child: const Text('Confirmar'),
          ),
        ],
      ),
    ).then((v) => v ?? false);
Widget titulo(String texto) => Padding(
  padding: const EdgeInsets.fromLTRB(0, 18, 0, 12),
  child: Text(
    texto,
    style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
  ),
);
Widget dato(String nombre, String valor, {Color? color}) => Padding(
  padding: const EdgeInsets.symmetric(vertical: 5),
  child: Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Expanded(
        child: Text(nombre, style: const TextStyle(color: tenue)),
      ),
      const SizedBox(width: 12),
      Flexible(
        child: Text(
          valor,
          textAlign: TextAlign.right,
          style: TextStyle(fontWeight: FontWeight.w700, color: color),
        ),
      ),
    ],
  ),
);
Widget vacio(String titulo, String ayuda) => Padding(
  padding: const EdgeInsets.symmetric(vertical: 40),
  child: Column(
    children: [
      const Icon(Icons.water_drop_outlined, size: 42, color: acento),
      const SizedBox(height: 16),
      Text(
        titulo,
        textAlign: TextAlign.center,
        style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
      ),
      const SizedBox(height: 8),
      Text(
        ayuda,
        textAlign: TextAlign.center,
        style: const TextStyle(color: tenue),
      ),
    ],
  ),
);
Widget campo(
  String label,
  TextEditingController controller, {
  bool numero = false,
  TextInputType? teclado,
  String? ayuda,
  ValueChanged<String>? cambio,
}) => Padding(
  padding: const EdgeInsets.only(bottom: 16),
  child: TextField(
    controller: controller,
    onChanged: cambio,
    keyboardType:
        teclado ??
        (numero
            ? const TextInputType.numberWithOptions(decimal: true)
            : TextInputType.text),
    textCapitalization: numero
        ? TextCapitalization.none
        : TextCapitalization.sentences,
    decoration: InputDecoration(
      labelText: label,
      helperText: ayuda,
      helperMaxLines: 3,
    ),
  ),
);

class Hoja extends StatelessWidget {
  const Hoja({
    super.key,
    required this.titulo,
    required this.children,
    required this.guardar,
    this.accion = 'Guardar',
  });
  final String titulo, accion;
  final List<Widget> children;
  final Future<void> Function() guardar;
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(titulo)),
    body: SafeArea(
      child: Column(
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(20),
              children: children,
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
            child: SizedBox(
              width: double.infinity,
              child: Accion(accion, guardar),
            ),
          ),
        ],
      ),
    ),
  );
}

class Inicio extends StatefulWidget {
  const Inicio({super.key, required this.negocio});
  final Negocio negocio;
  @override
  State<Inicio> createState() => _InicioState();
}

class _InicioState extends State<Inicio> {
  int tab = 0;
  int dia = DateTime.now().weekday;
  String buscar = '';
  final busqueda = TextEditingController();
  @override
  void dispose() {
    busqueda.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: widget.negocio,
    builder: (context, _) {
      final n = widget.negocio;
      final listado =
          n.clientes
              .where(
                (c) =>
                    (c.activo || tab == 2) &&
                    (tab != 0 || c.dia == dia) &&
                    (tab != 2 || n.saldo(c.id) != 0) &&
                    '${c.nombre} ${c.direccion} ${c.telefono}'
                        .toLowerCase()
                        .contains(buscar.toLowerCase()),
              )
              .toList()
            ..sort((a, b) => a.nombre.compareTo(b.nombre));
      final hoy = DateTime.now();
      final hoyMov = n.movimientos.where(
        (m) =>
            m.fecha.year == hoy.year &&
            m.fecha.month == hoy.month &&
            m.fecha.day == hoy.day,
      );
      return Scaffold(
        appBar: AppBar(
          title: Text(n.nombre),
          actions: [
            IconButton(
              tooltip: 'Ajustes y respaldos',
              onPressed: () => abrir(context, Ajustes(negocio: n)),
              icon: const Icon(Icons.tune_rounded),
            ),
          ],
        ),
        body: SafeArea(
          top: false,
          child: AnimatedSwitcher(
            duration: movimiento(context, 180),
            child: tab == 3
                ? Stock(key: const ValueKey('stock'), negocio: n)
                : ListView(
                    key: ValueKey(tab),
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 100),
                    children: [
                      Text(
                        ['Tu reparto', 'Tus clientes', 'Cuenta corriente'][tab],
                        style: Theme.of(context).textTheme.headlineLarge,
                      ),
                      const SizedBox(height: 6),
                      Text(
                        tab == 0
                            ? 'Bidones de 20 litros, parada por parada.'
                            : tab == 1
                            ? 'Cada cliente, con su precio y su historia.'
                            : 'Lo que te deben y los pagos a favor.',
                        style: const TextStyle(color: tenue),
                      ),
                      const SizedBox(height: 24),
                      if (tab == 0) ...[
                        Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: tinta,
                            borderRadius: BorderRadius.circular(22),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Antes de salir',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 19,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(height: 10),
                              Text(
                                '${listado.fold<int>(0, (a, c) => a + c.pedido)} bidones pedidos',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 28,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                '${n.llenos} llenos en stock',
                                style: const TextStyle(
                                  color: Color(0xFFBFE7ED),
                                ),
                              ),
                              const Divider(color: Color(0xFF386071)),
                              Text(
                                'Cobrado hoy: ${dinero(hoyMov.fold<int>(0, (a, m) => a + m.pago))}',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                        DropdownButtonFormField<int>(
                          initialValue: dia,
                          decoration: const InputDecoration(
                            labelText: 'Día de reparto',
                          ),
                          items: List.generate(
                            7,
                            (i) => DropdownMenuItem(
                              value: i + 1,
                              child: Text(dias[i]),
                            ),
                          ),
                          onChanged: (v) => setState(() => dia = v!),
                        ),
                        const SizedBox(height: 16),
                      ],
                      if (tab == 2) ...[
                        Papel(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Total por cobrar',
                                style: TextStyle(color: tenue),
                              ),
                              Text(
                                dinero(n.porCobrar),
                                style: Theme.of(
                                  context,
                                ).textTheme.headlineLarge,
                              ),
                              const SizedBox(height: 6),
                              const Text(
                                'Los saldos a favor se muestran por separado.',
                                style: TextStyle(color: tenue),
                              ),
                            ],
                          ),
                        ),
                      ],
                      TextField(
                        controller: busqueda,
                        onChanged: (v) => setState(() => buscar = v),
                        decoration: const InputDecoration(
                          labelText: 'Buscar cliente',
                          prefixIcon: Icon(Icons.search_rounded),
                        ),
                      ),
                      const SizedBox(height: 12),
                      if (listado.isEmpty)
                        vacio(
                          tab == 2
                              ? 'Las cuentas están al día'
                              : 'Todavía no hay clientes acá',
                          tab == 0
                              ? 'Agregá un cliente o elegí otro día de reparto.'
                              : 'Usá «Nuevo cliente» para empezar.',
                        ),
                      ...listado.map(
                        (c) => ClienteFila(
                          cliente: c,
                          negocio: n,
                          onTap: () => abrir(
                            context,
                            Detalle(clienteId: c.id, negocio: n),
                          ),
                        ),
                      ),
                    ],
                  ),
          ),
        ),
        floatingActionButton: tab == 1
            ? FloatingActionButton.extended(
                onPressed: () => abrir(context, EditorCliente(negocio: n)),
                icon: const Icon(Icons.add_rounded),
                label: const Text('Nuevo cliente'),
              )
            : null,
        bottomNavigationBar: BarraPropia(
          actual: tab,
          nombres: const ['Reparto', 'Clientes', 'Cuentas', 'Stock'],
          iconos: const [
            Icons.route_outlined,
            Icons.people_outline_rounded,
            Icons.receipt_long_outlined,
            Icons.inventory_2_outlined,
          ],
          cambiar: (i) => setState(() => tab = i),
        ),
      );
    },
  );
}

class ClienteFila extends StatelessWidget {
  const ClienteFila({
    super.key,
    required this.cliente,
    required this.negocio,
    required this.onTap,
  });
  final Cliente cliente;
  final Negocio negocio;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    final saldo = negocio.saldo(cliente.id);
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: const BorderSide(color: borde),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        cliente.nombre,
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    const Icon(Icons.chevron_right_rounded, color: tenue),
                  ],
                ),
                if (cliente.direccion.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(cliente.direccion, style: const TextStyle(color: tenue)),
                ],
                const SizedBox(height: 12),
                Wrap(
                  spacing: 12,
                  runSpacing: 6,
                  children: [
                    Text(
                      '${negocio.envases(cliente.id)} envases',
                      style: const TextStyle(
                        color: acento,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      saldo == 0
                          ? 'Al día'
                          : saldo > 0
                          ? 'Debe ${dinero(saldo)}'
                          : 'A favor ${dinero(-saldo)}',
                      style: TextStyle(
                        color: saldo > 0 ? const Color(0xFFAA3246) : tinta,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (cliente.pedido > 0)
                      Text(
                        'Llevar ${cliente.pedido}',
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class EditorCliente extends StatefulWidget {
  const EditorCliente({super.key, required this.negocio, this.cliente});
  final Negocio negocio;
  final Cliente? cliente;
  @override
  State<EditorCliente> createState() => _EditorClienteState();
}

class _EditorClienteState extends State<EditorCliente> {
  late final nombre = TextEditingController(text: widget.cliente?.nombre),
      direccion = TextEditingController(text: widget.cliente?.direccion),
      telefono = TextEditingController(text: widget.cliente?.telefono),
      precio = TextEditingController(
        text: campoDinero(widget.cliente?.precio ?? 750000),
      ),
      pedido = TextEditingController(text: '${widget.cliente?.pedido ?? 0}');
  late int dia = widget.cliente?.dia ?? DateTime.now().weekday;
  late bool activo = widget.cliente?.activo ?? true;
  bool mas = false;
  @override
  void dispose() {
    for (final c in [nombre, direccion, telefono, precio, pedido]) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Hoja(
    titulo: widget.cliente == null ? 'Nuevo cliente' : 'Editar cliente',
    children: [
      campo('Nombre *', nombre),
      campo('Dirección', direccion),
      TextButton.icon(
        onPressed: () => setState(() => mas = !mas),
        icon: Icon(mas ? Icons.remove_rounded : Icons.add_rounded),
        label: Text(mas ? 'Menos opciones' : 'Más opciones'),
      ),
      AnimatedSize(
        duration: movimiento(context),
        alignment: Alignment.topCenter,
        child: mas
            ? Column(
                children: [
                  const SizedBox(height: 12),
                  campo('Teléfono', telefono, teclado: TextInputType.phone),
                  campo('Precio por bidón *', precio, numero: true),
                  campo('Bidones a llevar', pedido, numero: true),
                  DropdownButtonFormField<int>(
                    initialValue: dia,
                    decoration: const InputDecoration(
                      labelText: 'Día de reparto',
                    ),
                    items: List.generate(
                      7,
                      (i) =>
                          DropdownMenuItem(value: i + 1, child: Text(dias[i])),
                    ),
                    onChanged: (v) => setState(() => dia = v!),
                  ),
                  if (widget.cliente != null)
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Cliente activo'),
                      value: activo,
                      onChanged: (v) => setState(() => activo = v),
                    ),
                ],
              )
            : const SizedBox(width: double.infinity),
      ),
    ],
    guardar: () async {
      if (nombre.text.trim().isEmpty) {
        throw ArgumentError('Escribí el nombre del cliente.');
      }
      final cantidad = int.tryParse(pedido.text.trim());
      if (cantidad == null || cantidad < 0 || cantidad > 100000) {
        throw ArgumentError('Revisá los bidones a llevar.');
      }
      await widget.negocio.guardarCliente(
        Cliente(
          id: widget.cliente?.id ?? widget.negocio.nuevoId(),
          nombre: nombre.text.trim(),
          direccion: direccion.text.trim(),
          telefono: telefono.text.trim(),
          precio: monto(precio, permiteCero: false),
          dia: dia,
          pedido: cantidad,
          activo: activo,
        ),
      );
      if (context.mounted) Navigator.pop(context);
    },
  );
}

class Detalle extends StatelessWidget {
  const Detalle({super.key, required this.clienteId, required this.negocio});
  final String clienteId;
  final Negocio negocio;
  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: negocio,
    builder: (context, _) {
      final encontrados = negocio.clientes.where((c) => c.id == clienteId);
      if (encontrados.isEmpty) {
        return Scaffold(
          appBar: AppBar(title: const Text('Cliente')),
          body: const Center(
            child: Text('El cliente ya no está en este respaldo.'),
          ),
        );
      }
      final c = encontrados.single;
      final saldo = negocio.saldo(c.id);
      final ms = negocio.movimientos
          .where((m) => m.cliente == c.id)
          .toList()
          .reversed
          .toList();
      return Scaffold(
        appBar: AppBar(
          title: Text(c.nombre),
          actions: [
            IconButton(
              tooltip: 'Editar cliente',
              onPressed: () =>
                  abrir(context, EditorCliente(negocio: negocio, cliente: c)),
              icon: const Icon(Icons.edit_outlined),
            ),
          ],
        ),
        body: SafeArea(
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              if (c.direccion.isNotEmpty)
                Text(c.direccion, style: const TextStyle(fontSize: 17)),
              if (c.telefono.isNotEmpty) SelectableText(c.telefono),
              const SizedBox(height: 12),
              Papel(
                child: Column(
                  children: [
                    dato(
                      saldo < 0 ? 'Saldo a favor' : 'Debe',
                      dinero(saldo.abs()),
                      color: saldo > 0 ? const Color(0xFFAA3246) : acento,
                    ),
                    dato('Envases en su poder', '${negocio.envases(c.id)}'),
                    dato('Precio por bidón', dinero(c.precio)),
                    dato('Reparto', dias[c.dia - 1]),
                    dato('Próximo pedido', '${c.pedido} bidones'),
                  ],
                ),
              ),
              if (c.activo) ...[
                FilledButton.icon(
                  onPressed: () =>
                      abrir(context, Entrega(negocio: negocio, cliente: c)),
                  icon: const Icon(Icons.local_shipping_outlined),
                  label: const Text('Registrar entrega'),
                ),
                const SizedBox(height: 10),
                TextButton.icon(
                  onPressed: () =>
                      abrir(context, Pedido(negocio: negocio, cliente: c)),
                  icon: const Icon(Icons.event_outlined),
                  label: const Text('Programar pedido'),
                ),
              ],
              OutlinedButton.icon(
                onPressed: () =>
                    abrir(context, Cobro(negocio: negocio, cliente: c)),
                icon: const Icon(Icons.payments_outlined),
                label: const Text('Registrar pago'),
              ),
              OutlinedButton.icon(
                onPressed: () async {
                  final texto =
                      '${negocio.nombre}\n${c.nombre}\n${fecha(DateTime.now())}\n${saldo < 0 ? 'Saldo a favor' : 'Saldo pendiente'}: ${dinero(saldo.abs())}\nEnvases: ${negocio.envases(c.id)}\n\n${ms.take(30).map((m) => '${fecha(m.fecha)} · ${m.tipo}${negocio.anulado(m) && m.anula == null ? ' (anulado)' : ''}\n${m.dejados} dejados / ${m.retirados} retirados · Cargo ${dinero(m.deuda)} · Pagó ${dinero(m.pago)}').join('\n\n')}';
                  final box = context.findRenderObject() as RenderBox?;
                  await SharePlus.instance.share(
                    ShareParams(
                      text: texto,
                      sharePositionOrigin: box == null
                          ? null
                          : box.localToGlobal(Offset.zero) & box.size,
                    ),
                  );
                },
                icon: const Icon(Icons.ios_share_rounded),
                label: const Text('Compartir cuenta'),
              ),
              titulo('Movimientos'),
              if (ms.isEmpty)
                const Text(
                  'Sin movimientos. Podés cargar el saldo y los envases que ya tenía el cliente.',
                ),
              if (ms.isEmpty)
                TextButton(
                  onPressed: () =>
                      abrir(context, Apertura(negocio: negocio, cliente: c)),
                  child: const Text('Cargar saldo y envases iniciales'),
                ),
              ...ms.map((m) => MovimientoFila(m: m, negocio: negocio)),
            ],
          ),
        ),
      );
    },
  );
}

class MovimientoFila extends StatelessWidget {
  const MovimientoFila({super.key, required this.m, required this.negocio});
  final Movimiento m;
  final Negocio negocio;
  @override
  Widget build(BuildContext context) => Papel(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                '${m.tipo}${negocio.anulado(m) && m.anula == null ? ' · Anulado' : ''}',
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            Text(fecha(m.fecha), style: const TextStyle(color: tenue)),
          ],
        ),
        if (m.tipo == 'Entrega') ...[
          const SizedBox(height: 8),
          Text('${m.dejados} dejados / ${m.retirados} vacíos retirados'),
          dato('Cargo', dinero(m.deuda)),
        ],
        if (m.pago != 0) dato('Pago · ${m.medio}', dinero(m.pago)),
        if (m.tipo == 'Saldo inicial') dato('Saldo', dinero(m.deuda)),
        if (m.tipo == 'Envases iniciales') dato('Envases', '${m.envases}'),
        if (m.llenos != 0 && m.cliente == null)
          dato('Llenos', '${m.llenos > 0 ? '+' : ''}${m.llenos}'),
        if (m.vacios != 0 && m.cliente == null)
          dato('Vacíos', '${m.vacios > 0 ? '+' : ''}${m.vacios}'),
        if (m.gasto != 0) dato('Gasto', dinero(m.gasto)),
        if (m.nota.isNotEmpty)
          Text(m.nota, style: const TextStyle(color: tenue)),
        if (!negocio.anulado(m))
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: () async {
                if (await confirmar(
                  context,
                  '¿Anular ${m.tipo.toLowerCase()}?',
                  'Se registra la anulación y se revierten los importes y envases. El original queda en el historial.',
                )) {
                  try {
                    await negocio.anular(m);
                  } catch (e) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            e is FormatException
                                ? e.message
                                : 'No se pudo anular. Revisá los movimientos posteriores.',
                          ),
                        ),
                      );
                    }
                  }
                }
              },
              child: const Text('Anular movimiento'),
            ),
          ),
      ],
    ),
  );
}

class Contador extends StatelessWidget {
  const Contador(this.texto, this.valor, this.cambiar, {super.key});
  final String texto;
  final int valor;
  final ValueChanged<int> cambiar;
  @override
  Widget build(BuildContext context) => Papel(
    padding: 12,
    child: Row(
      children: [
        Expanded(
          child: Text(
            texto,
            style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
          ),
        ),
        IconButton(
          tooltip: 'Restar $texto',
          onPressed: valor > 0 ? () => cambiar(valor - 1) : null,
          icon: const Icon(Icons.remove_circle_outline_rounded),
        ),
        Semantics(
          liveRegion: true,
          label: '$texto: $valor',
          child: ExcludeSemantics(
            child: AnimatedSwitcher(
              duration: movimiento(context, 150),
              child: Text(
                '$valor',
                key: ValueKey(valor),
                style: const TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        ),
        IconButton(
          tooltip: 'Sumar $texto',
          onPressed: valor < 999 ? () => cambiar(valor + 1) : null,
          icon: const Icon(Icons.add_circle_outline_rounded),
        ),
      ],
    ),
  );
}

class Entrega extends StatefulWidget {
  const Entrega({super.key, required this.negocio, required this.cliente});
  final Negocio negocio;
  final Cliente cliente;
  @override
  State<Entrega> createState() => _EntregaState();
}

class _EntregaState extends State<Entrega> {
  late int dejados = widget.cliente.pedido > 0 ? widget.cliente.pedido : 1;
  int retirados = 0;
  late final precio = TextEditingController(
    text: campoDinero(widget.cliente.precio),
  );
  final pago = TextEditingController(), nota = TextEditingController();
  String medio = 'Efectivo';
  bool mas = false;
  @override
  void dispose() {
    precio.dispose();
    pago.dispose();
    nota.dispose();
    super.dispose();
  }

  int get total {
    try {
      return dejados * monto(precio, permiteCero: false);
    } catch (_) {
      return 0;
    }
  }

  @override
  Widget build(BuildContext context) => Hoja(
    titulo: 'Entrega a ${widget.cliente.nombre}',
    accion: 'Guardar entrega',
    children: [
      Contador('Llenos que dejás', dejados, (v) => setState(() => dejados = v)),
      Contador(
        'Vacíos que retirás',
        retirados,
        (v) => setState(() => retirados = v),
      ),
      dato(
        'Tiene actualmente',
        '${widget.negocio.envases(widget.cliente.id)} envases',
      ),
      const SizedBox(height: 16),
      campo(
        'Precio por bidón',
        precio,
        numero: true,
        cambio: (_) => setState(() {}),
      ),
      Papel(
        color: const Color(0xFFE3F1F1),
        child: Column(
          children: [
            dato('Esta entrega', dinero(total)),
            dato(
              'Saldo anterior',
              dinero(widget.negocio.saldo(widget.cliente.id)),
            ),
          ],
        ),
      ),
      campo(
        'Paga ahora',
        pago,
        numero: true,
        ayuda: 'Dejá vacío si queda en cuenta corriente.',
        cambio: (_) => setState(() {}),
      ),
      Wrap(
        spacing: 8,
        children: [
          TextButton(
            onPressed: () => setState(() => pago.text = campoDinero(total)),
            child: const Text('Paga esta entrega'),
          ),
          TextButton(
            onPressed: () => setState(
              () => pago.text = campoDinero(
                (total + widget.negocio.saldo(widget.cliente.id)).clamp(
                  0,
                  10000000000000,
                ),
              ),
            ),
            child: const Text('Paga toda la cuenta'),
          ),
        ],
      ),
      Medio(valor: medio, cambiar: (v) => setState(() => medio = v)),
      TextButton.icon(
        onPressed: () => setState(() => mas = !mas),
        icon: const Icon(Icons.notes_rounded),
        label: const Text('Agregar nota'),
      ),
      AnimatedSize(
        duration: movimiento(context),
        child: mas
            ? campo('Nota', nota)
            : const SizedBox(width: double.infinity),
      ),
    ],
    guardar: () async {
      await widget.negocio.entregar(
        cliente: widget.cliente,
        dejados: dejados,
        retirados: retirados,
        precio: monto(precio, permiteCero: false),
        pago: monto(pago),
        medio: medio,
        nota: nota.text.trim(),
      );
      if (context.mounted) Navigator.pop(context);
    },
  );
}

class Medio extends StatelessWidget {
  const Medio({super.key, required this.valor, required this.cambiar});
  final String valor;
  final ValueChanged<String> cambiar;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 16),
    child: Wrap(
      spacing: 8,
      children: ['Efectivo', 'Transferencia']
          .map(
            (v) => ChoiceChip(
              label: Text(v),
              selected: valor == v,
              onSelected: (_) => cambiar(v),
              labelStyle: TextStyle(
                fontFamily: 'Figtree',
                color: valor == v ? Colors.white : tinta,
              ),
            ),
          )
          .toList(),
    ),
  );
}

class Cobro extends StatefulWidget {
  const Cobro({super.key, required this.negocio, required this.cliente});
  final Negocio negocio;
  final Cliente cliente;
  @override
  State<Cobro> createState() => _CobroState();
}

class _CobroState extends State<Cobro> {
  final pago = TextEditingController();
  String medio = 'Efectivo';
  @override
  void dispose() {
    pago.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Hoja(
    titulo: 'Pago de ${widget.cliente.nombre}',
    accion: 'Guardar pago',
    children: [
      Papel(
        child: dato(
          'Saldo de la cuenta',
          dinero(widget.negocio.saldo(widget.cliente.id)),
        ),
      ),
      campo(
        'Importe recibido *',
        pago,
        numero: true,
        ayuda: 'Si paga de más, queda saldo a favor.',
      ),
      Medio(valor: medio, cambiar: (v) => setState(() => medio = v)),
    ],
    guardar: () async {
      await widget.negocio.cobrar(
        widget.cliente,
        monto(pago, permiteCero: false),
        medio,
      );
      if (context.mounted) Navigator.pop(context);
    },
  );
}

class Pedido extends StatefulWidget {
  const Pedido({super.key, required this.negocio, required this.cliente});
  final Negocio negocio;
  final Cliente cliente;
  @override
  State<Pedido> createState() => _PedidoState();
}

class _PedidoState extends State<Pedido> {
  late int cantidad = widget.cliente.pedido;
  late int dia = widget.cliente.dia;
  @override
  Widget build(BuildContext context) => Hoja(
    titulo: 'Próximo reparto',
    children: [
      Text(
        widget.cliente.nombre,
        style: Theme.of(context).textTheme.titleLarge,
      ),
      const SizedBox(height: 20),
      Contador(
        'Bidones a llevar',
        cantidad,
        (v) => setState(() => cantidad = v),
      ),
      DropdownButtonFormField<int>(
        initialValue: dia,
        decoration: const InputDecoration(labelText: 'Día'),
        items: List.generate(
          7,
          (i) => DropdownMenuItem(value: i + 1, child: Text(dias[i])),
        ),
        onChanged: (v) => setState(() => dia = v!),
      ),
    ],
    guardar: () async {
      final c = widget.cliente;
      await widget.negocio.guardarCliente(
        Cliente(
          id: c.id,
          nombre: c.nombre,
          direccion: c.direccion,
          telefono: c.telefono,
          precio: c.precio,
          dia: dia,
          pedido: cantidad,
          activo: c.activo,
        ),
      );
      if (context.mounted) Navigator.pop(context);
    },
  );
}

class Apertura extends StatefulWidget {
  const Apertura({super.key, required this.negocio, required this.cliente});
  final Negocio negocio;
  final Cliente cliente;
  @override
  State<Apertura> createState() => _AperturaState();
}

class _AperturaState extends State<Apertura> {
  final saldo = TextEditingController(), envases = TextEditingController();
  bool favor = false;
  @override
  void dispose() {
    saldo.dispose();
    envases.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Hoja(
    titulo: 'Punto de partida',
    children: [
      const Text(
        'Cargá solo lo que ya debía y los envases que ya tenía. Esto no registra dinero cobrado ni una entrega nueva.',
      ),
      const SizedBox(height: 20),
      campo('Saldo inicial', saldo, numero: true),
      SwitchListTile(
        contentPadding: EdgeInsets.zero,
        title: const Text('Es saldo a favor del cliente'),
        value: favor,
        onChanged: (v) => setState(() => favor = v),
      ),
      campo('Envases que ya tiene', envases, numero: true),
    ],
    guardar: () async {
      await widget.negocio.abrirCuenta(
        widget.cliente,
        monto(saldo) * (favor ? -1 : 1),
        int.tryParse(envases.text.trim().isEmpty ? '0' : envases.text) ?? -1,
      );
      if (context.mounted) Navigator.pop(context);
    },
  );
}

class Stock extends StatelessWidget {
  const Stock({super.key, required this.negocio});
  final Negocio negocio;
  @override
  Widget build(BuildContext context) {
    final activos = negocio.movimientos
        .where((m) => m.cliente == null)
        .toList()
        .reversed
        .toList();
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
      children: [
        Text(
          'Stock y envasado',
          style: Theme.of(context).textTheme.headlineLarge,
        ),
        const SizedBox(height: 20),
        Papel(
          child: Column(
            children: [
              dato('Llenos disponibles', '${negocio.llenos}', color: acento),
              dato('Vacíos en planta', '${negocio.vacios}'),
              dato(
                'Envases con clientes',
                '${negocio.clientes.fold<int>(0, (a, c) => a + negocio.envases(c.id))}',
              ),
            ],
          ),
        ),
        FilledButton.icon(
          onPressed: () => abrir(
            context,
            MovimientoStock(negocio: negocio, tipo: 'Envasado'),
          ),
          icon: const Icon(Icons.water_drop_outlined),
          label: const Text('Registrar envasado'),
        ),
        const SizedBox(height: 10),
        OutlinedButton.icon(
          onPressed: () => abrir(
            context,
            MovimientoStock(negocio: negocio, tipo: 'Ingreso'),
          ),
          icon: const Icon(Icons.add_box_outlined),
          label: const Text('Ingresar stock'),
        ),
        const SizedBox(height: 10),
        OutlinedButton.icon(
          onPressed: () =>
              abrir(context, MovimientoStock(negocio: negocio, tipo: 'Gasto')),
          icon: const Icon(Icons.payments_outlined),
          label: const Text('Registrar gasto'),
        ),
        titulo('Actividad'),
        if (activos.isEmpty)
          const Text('Empezá ingresando los llenos y vacíos que tenés hoy.'),
        ...activos.map((m) => MovimientoFila(m: m, negocio: negocio)),
      ],
    );
  }
}

class MovimientoStock extends StatefulWidget {
  const MovimientoStock({super.key, required this.negocio, required this.tipo});
  final Negocio negocio;
  final String tipo;
  @override
  State<MovimientoStock> createState() => _MovimientoStockState();
}

class _MovimientoStockState extends State<MovimientoStock> {
  final llenos = TextEditingController(),
      vacios = TextEditingController(),
      costo = TextEditingController(),
      nota = TextEditingController();
  @override
  void dispose() {
    for (final c in [llenos, vacios, costo, nota]) {
      c.dispose();
    }
    super.dispose();
  }

  int cantidad(TextEditingController c) {
    final n = int.tryParse(c.text.trim().isEmpty ? '0' : c.text);
    if (n == null || n < 0 || n > 100000) {
      throw ArgumentError('Ingresá una cantidad entera válida.');
    }
    return n;
  }

  @override
  Widget build(BuildContext context) => Hoja(
    titulo: widget.tipo,
    children: [
      if (widget.tipo == 'Envasado') ...[
        Text(
          'Tenés ${widget.negocio.vacios} envases vacíos. Cada bidón envasado usa un vacío y suma un lleno.',
        ),
        const SizedBox(height: 20),
        campo('Bidones envasados *', llenos, numero: true),
      ] else if (widget.tipo == 'Ingreso') ...[
        const Text(
          'Para el stock inicial, compras o envases que entran a la planta.',
        ),
        const SizedBox(height: 20),
        campo('Llenos que ingresan', llenos, numero: true),
        campo('Vacíos que ingresan', vacios, numero: true),
      ],
      campo(
        widget.tipo == 'Gasto' ? 'Importe *' : 'Costo total (opcional)',
        costo,
        numero: true,
      ),
      campo(widget.tipo == 'Gasto' ? 'Concepto *' : 'Nota (opcional)', nota),
    ],
    guardar: () async {
      await widget.negocio.registrarStock(
        widget.tipo,
        llenos: cantidad(llenos),
        vacios: cantidad(vacios),
        costo: monto(costo, permiteCero: widget.tipo != 'Gasto'),
        nota: nota.text.trim(),
      );
      if (context.mounted) Navigator.pop(context);
    },
  );
}

class Ajustes extends StatefulWidget {
  const Ajustes({super.key, required this.negocio});
  final Negocio negocio;
  @override
  State<Ajustes> createState() => _AjustesState();
}

class _AjustesState extends State<Ajustes> {
  late final nombre = TextEditingController(text: widget.negocio.nombre);
  @override
  void dispose() {
    nombre.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Tu empresa')),
    body: SafeArea(
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          campo('Nombre de la empresa', nombre),
          Accion('Guardar nombre', () => widget.negocio.renombrar(nombre.text)),
          titulo('Respaldos'),
          const Text(
            'Los datos quedan en este celular. Exportá un respaldo con frecuencia y antes de cambiar de equipo.',
          ),
          const SizedBox(height: 16),
          Accion('Exportar respaldo', () async {
            final dir = await getTemporaryDirectory();
            final f = File(
              '${dir.path}/mi-reparto-${DateTime.now().millisecondsSinceEpoch}.json',
            );
            await f.writeAsString(widget.negocio.exportar(), flush: true);
            if (!context.mounted) return;
            final box = context.findRenderObject() as RenderBox?;
            await SharePlus.instance.share(
              ShareParams(
                files: [XFile(f.path)],
                sharePositionOrigin: box == null
                    ? null
                    : box.localToGlobal(Offset.zero) & box.size,
              ),
            );
          }, icono: Icons.ios_share_rounded),
          const SizedBox(height: 12),
          Accion('Importar respaldo', () async {
            final resultado = await FilePicker.pickFile(
              type: FileType.custom,
              allowedExtensions: ['json'],
            );
            if (resultado == null) return;
            final file = resultado;
            if ((await file.length() ?? 0) > 20 * 1024 * 1024) {
              throw const FormatException('El respaldo supera los 20 MB.');
            }
            final bytes = await file.readAsBytes();
            final texto = utf8.decode(bytes);
            final previo = Negocio.decodificar(texto);
            if (!context.mounted) return;
            if (await confirmar(
              context,
              '¿Importar respaldo?',
              'Reemplaza los datos actuales por ${previo.clientes.length} clientes y ${previo.movimientos.length} movimientos. Exportá primero si querés conservar los actuales.',
            )) {
              await widget.negocio.restaurar(texto);
              if (context.mounted) Navigator.pop(context);
            }
          }, icono: Icons.file_open_outlined),
          titulo('Clientes archivados'),
          ...widget.negocio.clientes
              .where((c) => !c.activo)
              .map(
                (c) => ListTile(
                  title: Text(c.nombre),
                  subtitle: const Text(
                    'El historial y la cuenta se conservan.',
                  ),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () => abrir(
                    context,
                    EditorCliente(negocio: widget.negocio, cliente: c),
                  ),
                ),
              ),
          titulo('Mi Reparto'),
          const Text(
            'Versión 0.1.0 · Bidones de 20 litros\nGestión interna. No emite comprobantes fiscales.',
            style: TextStyle(color: tenue),
          ),
        ],
      ),
    ),
  );
}
