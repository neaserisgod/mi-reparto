# Diseño

Modo Operate. Uso durante el reparto, bajo luz exterior y con una mano. Controles de 48 dp, información legible, acciones con nombre y respuesta inmediata.

Paleta: tinta marina #123444, azul agua #006C86, papel #F3F8FA, blanco #FFFFFF, borde #D6E3E8, deuda #A53832. Figtree local, títulos semibold de 30, cuerpo de 16 y cifras tabulares. Navegación propia, filas de clientes y hoja de movimientos: sin componentes Android stock en la estructura principal. Bordes de 12/20 según jerarquía, sin degradados decorativos.

El reparto es una lista operativa; cada cliente muestra envases y saldo con palabras, además de color. Alta básica: nombre y dirección; precio, teléfono y día son opciones. La entrega se resume con dos contadores, precio y pago; la cuenta se calcula automáticamente.

Movimiento: cambio de pestaña por fundido de 180 ms; expansión de opciones de 220 ms; navegación lateral con fundido de 260 ms. Respetar desactivación de animaciones. Sin bucles, esperas artificiales ni entradas escalonadas en listas largas.

Fuentes consultadas: pbakaus/impeccable (Operate, craft floor), anthropics/skills (frontend-design), nextlevelbuilder/ui-ux-pro-max-skill (Flutter y accesibilidad), vercel-labs/agent-skills (Web Design Guidelines). Taste se revisó como referencia web; sus efectos promocionales no corresponden a esta herramienta nativa.
