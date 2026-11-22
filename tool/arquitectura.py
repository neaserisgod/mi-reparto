"""Evita distribuir ABIs sin el motor Flutter correspondiente."""
from zipfile import ZipFile


def verificar_arm64(archivo):
    with ZipFile(archivo) as apk:
        nombres = set(apk.namelist())
    abis = {p.split('/')[1] for p in nombres if p.startswith('lib/') and p.endswith('.so')}
    motor = {'lib/arm64-v8a/libflutter.so', 'lib/arm64-v8a/libapp.so'}
    if abis != {'arm64-v8a'} or not motor.issubset(nombres):
        raise ValueError('APK incompatible: se requiere solo ARM64 con su motor Flutter. No se publicó.')
