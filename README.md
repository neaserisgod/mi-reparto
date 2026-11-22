# Mi Reparto

App Android personal para reparto de bidones de agua de **20 litros**. Funciona sin conexión y sin cuenta. Separada de Mi Lavadero: tiene otro identificador Android y otros archivos de datos.

- Clientes: nombre, dirección, teléfono, día de reparto y precio particular.
- Alta rápida: nombre y dirección. El resto aparece en «Más opciones».
- Reparto por día y pedidos pendientes. Al entregar se descuenta lo efectivamente entregado del pedido.
- Cada entrega registra llenos dejados, vacíos retirados, precio y pago juntos.
- Cuenta corriente: pagos parciales, fiado y saldo a favor. Los envases se llevan por separado.
- Historial y anulaciones con reversión de importes y stock; sin borrar el original.
- Stock de llenos y vacíos, ingresos, envasado y gastos.
- Compartir el resumen de cuenta y exportar/importar respaldos JSON.

## Empezar

1. En Ajustes → Importar respaldo, elegí el archivo privado de clientes. El código público y el APK no incluyen datos personales.
2. Revisá los precios y cargá en cada cuenta el saldo y los envases iniciales si corresponde. No se dedujeron del PDF porque sus totales no coinciden.
3. En Stock → Ingresar stock, cargá los bidones llenos y vacíos que tenés.
4. Programá los pedidos o registrá directamente las entregas.

Los datos se guardan localmente con escritura temporal y reemplazo atómico. La app no sincroniza entre equipos. Exportá respaldos a un lugar seguro. Importar reemplaza los datos actuales y conserva además una copia local previa; exportá primero para tenerla fuera del dispositivo.

Esta versión lleva la operación comercial básica y el envasado por cantidades. No incluye facturación fiscal, procesamiento de pagos, varios usuarios ni control sanitario por lote.

## Desarrollo

Flutter 3.47.5 / Dart 3.12. Identificador Android `com.neaserisgod.mireparto`.

```sh
flutter pub get
dart format --output=none --set-exit-if-changed lib test
flutter analyze
flutter test
flutter build apk --debug
```

GitHub Actions verifica y publica el APK de prueba como artifact. Configurar `ANDROID_DEBUG_KEYSTORE` con el keystore en base64 permite conservar la firma. Sin ese secreto, las compilaciones de CI pueden tener distinta firma: respaldar los datos antes de reinstalar. El APK de prueba no es una publicación en Play Store.

## GPS dentro de la app

Desde un cliente, **Ir al cliente** abre un mapa real de OpenStreetMap dentro de Mi Reparto. Se pide ubicación solo al usar el mapa; no hay seguimiento en segundo plano. La dirección se busca priorizando la zona del GPS. Antes de guardar, confirmar o corregir el pin tocando el mapa. Ese destino queda en el respaldo del cliente y no hace falta buscarlo en cada visita.

El mapa vectorial usa MapLibre y OpenFreeMap, con una paleta propia. El GPS nativo de Android solicita posiciones cada segundo, sin esperar diez metros de movimiento; la frecuencia efectiva depende del teléfono y de la señal. La cámara sigue la posición y el rumbo, el recorrido pendiente se reduce al avanzar, las indicaciones cambian según la maniobra y dos posiciones precisas fuera de ruta disparan el recálculo. Al mover el mapa manualmente se suspende el seguimiento; el botón de ubicación lo retoma. La pantalla se mantiene encendida al navegar y el GPS se detiene al enviar la app al fondo. Muestra distancia y llegada estimada sin tránsito en vivo. Desde la misma pantalla se registra la entrega o el pago. «Abrir GPS externo» es opcional. Los mapas, las búsquedas y las rutas necesitan internet y usan servicios públicos de Nominatim y FOSSGIS/OSRM; pueden estar temporalmente indisponibles. No incluyen tránsito en vivo ni navegación por voz. La dirección se envía al geocodificador y las coordenadas al servicio de rutas; no se envían teléfonos, nombres ni cuentas. No se descargan mapas masivamente.

## Publicación y actualizaciones

Actions → **Publicar actualización Android** → **Run workflow** en `main`. El APK firmado se publica en el backend y las instalaciones lo detectan al abrir o volver a la app. Android pide confirmar la instalación. Sin cuentas ni abonos en la app. Documentación técnica y origen del sistema: [backend de actualizaciones](https://github.com/neaserisgod/mi-lavadero/tree/main/backend).

## Migración de APK de prueba

La compilación antigua 0.2.0+2 tiene otra firma. Android no permite actualizarla con el certificado estable: primero exportar un respaldo y guardarlo fuera de la app; después desinstalar la prueba, instalar el APK estable e importar el respaldo. Las siguientes versiones estables conservan la misma firma. El instalador explica los errores y permite retomar después de habilitar el permiso de instalación.

## Verificar GPS nativo

Actions → **Validar navegación en Android** compila un punto de entrada separado con un cliente ficticio en memoria. El emulador recibe posiciones mediante `adb emu geo fix`; guarda capturas al iniciar, avanzar y llegar, y comprueba el estado GPS y la llegada. Ese escenario no forma parte de la entrada del APK publicado. Las pruebas Dart verifican progreso, imprecisión, desvíos y llegada.
