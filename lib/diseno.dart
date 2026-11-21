import 'package:flutter/material.dart';

const tinta = Color(0xFF12374B),
    acento = Color(0xFF006E78),
    fondo = Color(0xFFF2F7F8),
    borde = Color(0xFFD4E1E5),
    tenue = Color(0xFF506773);
Duration movimiento(BuildContext context, [int ms = 220]) =>
    MediaQuery.disableAnimationsOf(context)
    ? Duration.zero
    : Duration(milliseconds: ms);
ThemeData tema({Color principal = acento}) => ThemeData(
  useMaterial3: true,
  fontFamily: 'Figtree',
  scaffoldBackgroundColor: fondo,
  colorScheme: ColorScheme.fromSeed(
    seedColor: principal,
    primary: principal,
    onPrimary: Colors.white,
    surface: Colors.white,
    onSurface: tinta,
    error: const Color(0xFFAA3246),
  ),
  textTheme: const TextTheme(
    headlineLarge: TextStyle(
      fontSize: 34,
      fontWeight: FontWeight.w700,
      letterSpacing: -1.1,
      color: tinta,
    ),
    headlineSmall: TextStyle(
      fontSize: 26,
      fontWeight: FontWeight.w700,
      letterSpacing: -.6,
      color: tinta,
    ),
    titleLarge: TextStyle(
      fontSize: 22,
      fontWeight: FontWeight.w700,
      color: tinta,
    ),
    titleMedium: TextStyle(
      fontSize: 17,
      fontWeight: FontWeight.w600,
      color: tinta,
    ),
    bodyLarge: TextStyle(fontSize: 16, height: 1.4, color: tinta),
    bodyMedium: TextStyle(fontSize: 14, height: 1.4, color: tinta),
    bodySmall: TextStyle(fontSize: 12, height: 1.4, color: tenue),
  ),
  appBarTheme: const AppBarTheme(
    backgroundColor: fondo,
    surfaceTintColor: Colors.transparent,
    foregroundColor: tinta,
    centerTitle: false,
    toolbarHeight: 72,
    titleTextStyle: TextStyle(
      fontFamily: 'Figtree',
      fontWeight: FontWeight.w700,
      fontSize: 23,
      color: tinta,
    ),
  ),
  inputDecorationTheme: InputDecorationTheme(
    filled: true,
    fillColor: Colors.white,
    contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
    labelStyle: const TextStyle(color: tenue),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: const BorderSide(color: borde),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: const BorderSide(color: borde),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: BorderSide(color: principal, width: 2),
    ),
  ),
  filledButtonTheme: FilledButtonThemeData(
    style: FilledButton.styleFrom(
      minimumSize: const Size(48, 54),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      textStyle: const TextStyle(
        fontFamily: 'Figtree',
        fontSize: 16,
        fontWeight: FontWeight.w700,
      ),
    ),
  ),
  outlinedButtonTheme: OutlinedButtonThemeData(
    style: OutlinedButton.styleFrom(
      minimumSize: const Size(48, 50),
      side: const BorderSide(color: borde),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
    ),
  ),
  textButtonTheme: TextButtonThemeData(
    style: TextButton.styleFrom(minimumSize: const Size(48, 48)),
  ),
  iconButtonTheme: IconButtonThemeData(
    style: IconButton.styleFrom(minimumSize: const Size(48, 48)),
  ),
  chipTheme: ChipThemeData(
    backgroundColor: const Color(0xFFE2EFF0),
    selectedColor: principal,
    labelStyle: const TextStyle(
      fontFamily: 'Figtree',
      fontSize: 14,
      color: tinta,
      fontWeight: FontWeight.w600,
    ),
    secondaryLabelStyle: const TextStyle(
      fontFamily: 'Figtree',
      fontSize: 14,
      color: Colors.white,
      fontWeight: FontWeight.w600,
    ),
    checkmarkColor: Colors.white,
    side: BorderSide.none,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
  ),
  dividerTheme: const DividerThemeData(color: borde, space: 24),
  snackBarTheme: SnackBarThemeData(
    behavior: SnackBarBehavior.floating,
    backgroundColor: tinta,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
  ),
  dialogTheme: DialogThemeData(
    backgroundColor: Colors.white,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
  ),
  floatingActionButtonTheme: FloatingActionButtonThemeData(
    backgroundColor: principal,
    foregroundColor: Colors.white,
    elevation: 4,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
  ),
  pageTransitionsTheme: const PageTransitionsTheme(
    builders: {
      TargetPlatform.android: Transicion(),
      TargetPlatform.iOS: Transicion(),
      TargetPlatform.linux: Transicion(),
      TargetPlatform.macOS: Transicion(),
      TargetPlatform.windows: Transicion(),
    },
  ),
);

class Transicion extends PageTransitionsBuilder {
  const Transicion();
  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    if (MediaQuery.disableAnimationsOf(context)) return child;
    final curva = CurvedAnimation(
      parent: animation,
      curve: Curves.easeOutCubic,
      reverseCurve: Curves.easeInCubic,
    );
    return FadeTransition(
      opacity: curva,
      child: SlideTransition(
        position: Tween(
          begin: const Offset(.045, 0),
          end: Offset.zero,
        ).animate(curva),
        child: child,
      ),
    );
  }
}

class BarraPropia extends StatelessWidget {
  const BarraPropia({
    super.key,
    required this.actual,
    required this.nombres,
    required this.iconos,
    required this.cambiar,
  });
  final int actual;
  final List<String> nombres;
  final List<IconData> iconos;
  final ValueChanged<int> cambiar;
  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: const BoxDecoration(
      color: Colors.white,
      border: Border(top: BorderSide(color: borde)),
    ),
    child: SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
        child: Row(
          children: List.generate(
            nombres.length,
            (i) => Expanded(
              child: Semantics(
                selected: actual == i,
                child: TextButton(
                  onPressed: () => cambiar(i),
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      vertical: 8,
                      horizontal: 2,
                    ),
                    foregroundColor: actual == i
                        ? Theme.of(context).colorScheme.primary
                        : tenue,
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      AnimatedContainer(
                        duration: movimiento(context, 180),
                        curve: Curves.easeOutCubic,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 18,
                          vertical: 5,
                        ),
                        decoration: BoxDecoration(
                          color: actual == i
                              ? Theme.of(
                                  context,
                                ).colorScheme.primary.withValues(alpha: .1)
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(iconos[i], size: 23),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        nombres[i],
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: actual == i
                              ? FontWeight.w700
                              : FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

class Papel extends StatelessWidget {
  const Papel({super.key, required this.child, this.color, this.padding = 20});
  final Widget child;
  final Color? color;
  final double padding;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: Material(
      color: color ?? Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: const BorderSide(color: borde),
      ),
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: EdgeInsets.all(padding),
        child: SizedBox(width: double.infinity, child: child),
      ),
    ),
  );
}

class Accion extends StatefulWidget {
  const Accion(
    this.texto,
    this.accion, {
    super.key,
    this.icono = Icons.check_rounded,
  });
  final String texto;
  final Future<void> Function() accion;
  final IconData icono;
  @override
  State<Accion> createState() => _AccionState();
}

class _AccionState extends State<Accion> {
  bool ocupado = false;
  @override
  Widget build(BuildContext context) => FilledButton.icon(
    onPressed: ocupado
        ? null
        : () async {
            setState(() => ocupado = true);
            try {
              await widget.accion();
            } catch (e) {
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      e is ArgumentError
                          ? '${e.message}'
                          : e is FormatException
                          ? e.message
                          : 'No se pudo guardar. Volvé a intentarlo.',
                    ),
                  ),
                );
              }
            } finally {
              if (mounted) setState(() => ocupado = false);
            }
          },
    icon: ocupado
        ? const SizedBox.square(
            dimension: 18,
            child: CircularProgressIndicator(strokeWidth: 2),
          )
        : Icon(widget.icono),
    label: Text(ocupado ? 'Guardando…' : widget.texto),
  );
}
