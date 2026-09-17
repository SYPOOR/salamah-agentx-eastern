import os
import unittest
from unittest.mock import patch
os.environ.setdefault('SAFETYLENS_PROXY_TOKEN','test-device-token-never-use-in-production')
from app import app, SCHEMA, _times
from jsonschema import validate

class GatewayTests(unittest.TestCase):
    def setUp(self):
        self.client=app.test_client()
        self.headers={'Authorization':'Bearer '+os.environ['SAFETYLENS_PROXY_TOKEN']}
        _times.clear()
    def test_authentication_required(self):
        self.assertEqual(self.client.post('/intent',json={'transcript':'x'}).status_code,401)
    def test_explicit_frame_required(self):
        with patch('app.text_response') as model:
            result=self.client.post('/analyze',json={'image':'abc'},headers=self.headers)
            self.assertEqual(result.status_code,400)
            model.assert_not_called()
    def test_malformed_audio_and_image_do_not_call_openai(self):
        with patch('app.client') as model:
            self.assertEqual(self.client.post('/transcribe',headers=self.headers).status_code,400)
            self.assertEqual(self.client.post('/analyze',json={'explicit_capture':True,'image':'bm90LWpwZWc='},headers=self.headers).status_code,400)
            model.assert_not_called()
    def test_flags_are_derived_from_allowlist(self):
        import json
        decision={'intent':'safety_question','reply':'سلامة','severity':'info','create_event':True,'capture_frame':True,'event_type':'hazard_report'}
        with patch('app.text_response',return_value=json.dumps(decision)):
            r=self.client.post('/intent',json={'transcript':'معدات الوقاية؟'},headers=self.headers)
            self.assertEqual(r.status_code,200)
            result=r.get_json();validate(result,SCHEMA)
            self.assertFalse(result['capture_frame']);self.assertFalse(result['create_event'])
            self.assertEqual(result['event_type'],'none')
    def test_exceptions_never_leak_secrets(self):
        with patch('app.text_response',side_effect=RuntimeError('secret-value')):
            r=self.client.post('/intent',json={'transcript':'خطر'},headers=self.headers)
            self.assertEqual(r.status_code,503)
            self.assertNotIn('secret-value',r.get_data(as_text=True))

if __name__=='__main__':unittest.main()
