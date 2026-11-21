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

Esta versión lleva la operación comercial básica y el envasado por cantidades. No incluye facturación fiscal, GPS, procesamiento de pagos, varios usuarios ni control sanitario por lote.

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
