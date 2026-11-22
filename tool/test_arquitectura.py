import tempfile
import unittest
from pathlib import Path
from zipfile import ZipFile
from arquitectura import verificar_arm64


class ArquitecturaTest(unittest.TestCase):
    def apk(self, nombres):
        carpeta = tempfile.TemporaryDirectory()
        self.addCleanup(carpeta.cleanup)
        path = Path(carpeta.name) / 'app.apk'
        with ZipFile(path, 'w') as zipfile:
            for nombre in nombres:
                zipfile.writestr(nombre, b'fixture')
        return path

    def test_flutter_arm64_completo(self):
        verificar_arm64(self.apk(['lib/arm64-v8a/libflutter.so', 'lib/arm64-v8a/libapp.so', 'lib/arm64-v8a/libmaplibre.so']))

    def test_rechaza_abi_que_no_puede_ejecutar_flutter(self):
        with self.assertRaises(ValueError):
            verificar_arm64(self.apk(['lib/arm64-v8a/libflutter.so', 'lib/arm64-v8a/libapp.so', 'lib/x86_64/libmaplibre.so']))

    def test_rechaza_motor_ausente(self):
        with self.assertRaises(ValueError):
            verificar_arm64(self.apk(['lib/arm64-v8a/libmaplibre.so']))
