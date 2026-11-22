"""Reproduce posiciones a través del GPS Android; no inyecta estado Flutter."""
import json
from pathlib import Path
import subprocess
import time
import urllib.request
import xml.etree.ElementTree as ET
from PIL import Image, ImageChops, ImageStat

out = Path('evidencia-gps')
out.mkdir(exist_ok=True)

def adb(*args):
    return subprocess.check_output(['adb', *args], text=True)

def assert_marker(name):
    image = Image.open(out / f'{name}.png').convert('RGB')
    x, y = image.width // 2, image.height // 2
    area = image.crop((x - 45, y - 45, x + 45, y + 45))
    pixels = sum(r < 35 and 40 < g < 75 and 55 < b < 95 for r, g, b in area.getdata())
    assert pixels > 25, 'La posición GPS no se dibujó en el centro del mapa'

def capture(name):
    with (out / f'{name}.png').open('wb') as file:
        subprocess.run(['adb', 'exec-out', 'screencap', '-p'], stdout=file, check=True)
    adb('shell', 'uiautomator', 'dump', '/sdcard/ventana.xml')
    xml = adb('shell', 'cat', '/sdcard/ventana.xml')
    (out / f'{name}.xml').write_text(xml)
    return xml

# Reducir carga de SwiftShader y evitar ANR del launcher ajeno a la app.
adb('shell', 'wm', 'size', '720x1440')
adb('shell', 'wm', 'density', '280')
adb('shell', 'pm', 'disable-user', '--user', '0', 'com.android.launcher3')
adb('shell', 'am', 'force-stop', 'com.android.launcher3')
adb('install', '-r', 'build/app/outputs/flutter-apk/app-debug.apk')
for permission in ['ACCESS_FINE_LOCATION', 'ACCESS_COARSE_LOCATION']:
    adb('shell', 'pm', 'grant', 'com.neaserisgod.mireparto', 'android.permission.' + permission)
adb('shell', 'settings', 'put', 'secure', 'location_mode', '3')
adb('emu', 'geo', 'fix', '-58.3816', '-34.6037')
adb('shell', 'am', 'start', '-n', 'com.neaserisgod.mireparto/.MainActivity')
url = ('https://routing.openstreetmap.de/routed-car/route/v1/driving/'
       '-58.3816,-34.6037;-58.3974,-34.5952?overview=full&geometries=geojson&steps=true')
request = urllib.request.Request(url, headers={'User-Agent': 'MiReparto-GPS-Test/0.3'})
try:
    with urllib.request.urlopen(request, timeout=30) as response:
        route = json.load(response)['routes'][0]
    points = route['geometry']['coordinates']
    for _ in range(25):
        adb('emu', 'geo', 'fix', str(points[0][0]), str(points[0][1]))
        time.sleep(2)
    before = capture('01-inicio')
    assert_marker('01-inicio')
    control = next(n for n in ET.fromstring(before).iter('node')
                   if n.get('content-desc') == 'Seguir mi ubicación')
    assert any(n.get('selected') == 'true' and n.get('bounds') == control.get('bounds')
               for n in ET.fromstring(before).iter('node')), 'El inicio desactivó el seguimiento GPS'
    assert 'GPS en vivo' in before, 'El GPS Android no llegó a Flutter'
    assert 'Registrar entrega' in before, 'No se abrió el flujo de reparto'
    # Avanzar sobre la primera mitad del recorrido con fixes nativos.
    for point in points[1:max(3, len(points) // 2)]:
        adb('emu', 'geo', 'fix', str(point[0]), str(point[1]))
        time.sleep(1.2)
    middle = capture('02-avance')
    assert_marker('02-avance')
    # Comparar el mapa mismo, sin tarjetas, barra de estado ni reloj.
    a = Image.open(out / '01-inicio.png').convert('RGB')
    b = Image.open(out / '02-avance.png').convert('RGB')
    region = (0, int(a.height * .4), int(a.width * .8), int(a.height * .63))
    delta = ImageChops.difference(a.crop(region), b.crop(region))
    cambio = sum(ImageStat.Stat(delta).mean)
    (out / 'render.json').write_text(json.dumps({'cambio_mapa': cambio}))
    assert cambio > 2, 'El mapa quedó congelado aunque avanzaron las indicaciones'
    for _ in range(5):
        adb('emu', 'geo', 'fix', str(points[-1][0]), str(points[-1][1]))
        time.sleep(2)
    final = capture('03-llegada')
    assert 'Llegaste' in final, 'No se detectó la llegada con dos fixes precisos'
    assert before != middle, 'El panel no cambió al avanzar'
finally:
    (out / 'logcat.txt').write_text(adb('logcat', '-d', '--pid=' + adb('shell', 'pidof', 'com.neaserisgod.mireparto').strip()))
