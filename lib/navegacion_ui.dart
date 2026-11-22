import 'package:flutter/material.dart';
import 'diseno.dart';

class IndicacionNavegacion extends StatelessWidget {
  const IndicacionNavegacion({
    super.key,
    required this.texto,
    required this.distancia,
    required this.estado,
    required this.icono,
    required this.volver,
    this.recalculando = false,
    this.gpsActivo = false,
  });
  final String texto, distancia, estado;
  final IconData icono;
  final VoidCallback volver;
  final bool recalculando, gpsActivo;
  @override
  Widget build(BuildContext context) => Material(
    color: Colors.white,
    elevation: 8,
    shadowColor: const Color(0x2412374B),
    borderRadius: BorderRadius.circular(24),
    clipBehavior: Clip.antiAlias,
    child: Padding(
      padding: const EdgeInsets.all(14),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              IconButton(
                tooltip: 'Volver al cliente',
                onPressed: volver,
                icon: const Icon(Icons.arrow_back_rounded),
              ),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  estado,
                  style: TextStyle(
                    color: gpsActivo ? acento : tenue,
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                  ),
                ),
              ),
              if (gpsActivo)
                const Icon(Icons.gps_fixed_rounded, color: acento, size: 17),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                width: 58,
                height: 64,
                decoration: BoxDecoration(
                  color: const Color(0xFFE4F2ED),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(icono, size: 38, color: acento),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (distancia.isNotEmpty)
                      Text(
                        distancia,
                        style: const TextStyle(
                          fontSize: 14,
                          color: tenue,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    Text(
                      texto,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 21,
                        height: 1.15,
                        fontWeight: FontWeight.w700,
                        color: tinta,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (recalculando) ...[
            const SizedBox(height: 12),
            const LinearProgressIndicator(minHeight: 3),
          ],
        ],
      ),
    ),
  );
}

class ControlMapa extends StatelessWidget {
  const ControlMapa({
    super.key,
    required this.texto,
    required this.icono,
    required this.accion,
    this.activo = false,
  });
  final String texto;
  final IconData icono;
  final VoidCallback? accion;
  final bool activo;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: Material(
      color: activo ? tinta : Colors.white,
      elevation: 4,
      shadowColor: const Color(0x2412374B),
      shape: const CircleBorder(),
      child: IconButton(
        tooltip: texto,
        onPressed: accion,
        style: IconButton.styleFrom(
          minimumSize: const Size(50, 50),
          foregroundColor: activo ? Colors.white : tinta,
        ),
        icon: Icon(icono),
      ),
    ),
  );
}

class FichaDestinoNavegacion extends StatelessWidget {
  const FichaDestinoNavegacion({
    super.key,
    required this.nombre,
    required this.direccion,
    required this.estado,
    required this.eta,
    required this.distancia,
    required this.accionPrincipal,
    required this.textoAccion,
    required this.opciones,
    this.cobrar,
    this.confirmando = false,
    this.pedido = 0,
    this.llegado = false,
    this.error,
  });
  final String nombre, direccion, estado, eta, distancia, textoAccion;
  final String? error;
  final int pedido;
  final bool confirmando, llegado;
  final Future<void> Function() accionPrincipal;
  final VoidCallback? cobrar;
  final Widget opciones;
  @override
  Widget build(BuildContext context) => Material(
    color: Colors.white,
    elevation: 10,
    shadowColor: const Color(0x3012374B),
    borderRadius: BorderRadius.circular(28),
    clipBehavior: Clip.antiAlias,
    child: Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 16, 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  nombre,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              if (pedido > 0)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 7,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE4F2ED),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    'Llevar $pedido',
                    style: const TextStyle(
                      color: acento,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              opciones,
            ],
          ),
          Text(
            direccion,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: tenue, fontSize: 14),
          ),
          const SizedBox(height: 12),
          if (eta.isNotEmpty)
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  eta,
                  style: TextStyle(
                    fontSize: 30,
                    fontWeight: FontWeight.w700,
                    color: llegado ? acento : tinta,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Text(
                      distancia,
                      style: const TextStyle(
                        fontSize: 17,
                        color: tenue,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          if (estado.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 3),
              child: Text(
                estado,
                style: const TextStyle(fontSize: 12, color: tenue),
              ),
            ),
          if (error != null)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Text(
                error!,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 13, color: Color(0xFFAA3246)),
              ),
            ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: Accion(
                  textoAccion,
                  accionPrincipal,
                  icono: confirmando
                      ? Icons.location_on_outlined
                      : Icons.local_shipping_outlined,
                ),
              ),
              if (cobrar != null) ...[
                const SizedBox(width: 10),
                OutlinedButton(
                  onPressed: cobrar,
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(54, 54),
                    padding: const EdgeInsets.all(14),
                  ),
                  child: const Icon(Icons.payments_outlined),
                ),
              ],
            ],
          ),
        ],
      ),
    ),
  );
}
