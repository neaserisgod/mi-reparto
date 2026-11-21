import unittest
from firma import certificado_correcto

class FormatosApksigner(unittest.TestCase):
    def test_formato_android_36(self):
        self.assertTrue(certificado_correcto('Signer #1 certificate SHA-256 digest: '+'a'*64,'a'*64))
    def test_formato_android_37(self):
        self.assertTrue(certificado_correcto('V3.0 Signer: certificate SHA-256 digest: '+'a'*64,'a'*64))
    def test_varios_esquemas_con_misma_clave(self):
        texto='V2 Signer: certificate SHA-256 digest: '+'a'*64+'\nV3.1 Signer: certificate SHA-256 digest: '+'a'*64
        self.assertTrue(certificado_correcto(texto,'a'*64))
    def test_rechaza_clave_distinta_o_firmantes_mixtos(self):
        self.assertFalse(certificado_correcto('V3.0 Signer: certificate SHA-256 digest: '+'b'*64,'a'*64))
        self.assertFalse(certificado_correcto('Signer #1 certificate SHA-256 digest: '+'a'*64+'\nSigner #2 certificate SHA-256 digest: '+'b'*64,'a'*64))
    def test_sello_de_origen_no_reemplaza_firma_del_apk(self):
        self.assertFalse(certificado_correcto('Source Stamp certificate SHA-256 digest: '+'a'*64,'a'*64))
        self.assertFalse(certificado_correcto('', 'a'*64))
if __name__=='__main__':unittest.main()
