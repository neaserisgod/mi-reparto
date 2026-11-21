"""Compatibilidad con la salida de apksigner de Android Build Tools 36 y 37."""
import re

def certificado_correcto(salida, esperado):
    patron=r'^(?:Signer #\d+|V\d+(?:\.\d+)* Signer):? certificate SHA-256 digest:\s*([a-fA-F0-9]{64})\s*$'
    certificados=[]
    for linea in salida.splitlines():
        coincidencia=re.match(patron,linea.strip())
        if coincidencia:certificados.append(coincidencia.group(1).lower())
    return bool(certificados) and all(c==esperado.strip().lower() for c in certificados)
