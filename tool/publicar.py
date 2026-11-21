"""Publicación autenticada por GitHub OIDC. Nunca imprime claves ni tokens."""
import base64, hashlib, json, os, sys, urllib.parse, urllib.request, urllib.error
from pathlib import Path
from datetime import datetime, timezone
BASE='https://apps-personales-actualizaciones.gtalovergamer.workers.dev'
APP=os.environ['APP_ID']
def token():
    uri=os.environ['ACTIONS_ID_TOKEN_REQUEST_URL']+'&audience='+urllib.parse.quote(BASE,safe='')
    req=urllib.request.Request(uri,headers={'Authorization':'Bearer '+os.environ['ACTIONS_ID_TOKEN_REQUEST_TOKEN']})
    with urllib.request.urlopen(req,timeout=30) as r:return json.load(r)['value']
def call(path,method='GET',data=None,headers=None):
    req=urllib.request.Request(BASE+path,method=method,data=data,headers={'Authorization':'Bearer '+token(),'User-Agent':'Mozilla/5.0 (compatible; PersonalAppsRelease/1.0)','Accept':'application/json',**(headers or {})})
    try:
        with urllib.request.urlopen(req,timeout=180) as r:return json.load(r)
    except urllib.error.HTTPError as error:
        print('Publicación: HTTP '+str(error.code)+' '+error.read(300).decode(errors='replace'))
        raise
if sys.argv[1]=='prepare':
    from cryptography.hazmat.primitives import serialization,hashes
    from cryptography.hazmat.primitives.serialization import pkcs12
    from cryptography import x509
    from cryptography.x509.oid import NameOID
    result=call('/api/ci/signing-key?app='+APP)
    key=serialization.load_der_private_key(base64.b64decode(result['privateKey'],validate=True),password=None)
    name=x509.Name([x509.NameAttribute(NameOID.COMMON_NAME,'Apps Personales')])
    cert=x509.CertificateBuilder().subject_name(name).issuer_name(name).public_key(key.public_key()).serial_number(2026112101).not_valid_before(datetime(2026,11,1,tzinfo=timezone.utc)).not_valid_after(datetime(2056,11,1,tzinfo=timezone.utc)).sign(key,hashes.SHA256())
    target=Path.home()/'.android'/'debug.keystore';target.parent.mkdir(parents=True,exist_ok=True)
    target.write_bytes(pkcs12.serialize_key_and_certificates(b'androiddebugkey',key,cert,None,serialization.BestAvailableEncryption(b'android')));target.chmod(0o600)
    print('Firma estable preparada. Certificado SHA256: '+cert.fingerprint(hashes.SHA256()).hex())
elif sys.argv[1]=='publish':
    file=Path('build/app/outputs/flutter-apk/app-release.apk');data=file.read_bytes()
    result=call('/api/ci/publish?'+urllib.parse.urlencode({'app':APP,'version':os.environ['APP_VERSION']}),'PUT',data,{'Content-Type':'application/vnd.android.package-archive','X-Apk-Sha256':hashlib.sha256(data).hexdigest(),'X-Release-Notes':urllib.parse.quote(os.environ.get('RELEASE_NOTES','Mejoras y correcciones'),safe='')})
    print(json.dumps(result,ensure_ascii=False))
