"""Explicit opt-in paid API smoke test. Does not modify app data."""
import base64
import io
import json
from pathlib import Path
from app import app
import os

client=app.test_client()
headers={'Authorization':'Bearer '+os.environ['SAFETYLENS_PROXY_TOKEN']}
def post(path, **kwargs):
    r=client.post(path,headers=headers,**kwargs)
    if r.status_code!=200: raise RuntimeError(f'{path}: {r.status_code}, {r.get_json()}')
    return r

speech=post('/speech',json={'text':'يوجد خطر هنا، سجله.'}).data
assert len(speech)>1000
transcript=post('/transcribe',data={'audio':(io.BytesIO(speech),'command.mp3')},content_type='multipart/form-data').get_json()['transcript']
decision=post('/intent',json={'transcript':transcript}).get_json()
assert decision['intent']=='report_hazard',decision
print('PASS actual OpenAI TTS → STT → hazard intent',flush=True)
capture=post('/intent',json={'transcript':'ماذا أمامي؟'}).get_json()
assert capture['intent']=='capture_frame' and capture['capture_frame']
fixture=Path(__file__).parent.parent/'ios/RunnerTests/Fixtures/workers.jpg'
analysis=post('/analyze',json={'explicit_capture':True,'image':base64.b64encode(fixture.read_bytes()).decode()}).get_json()['reply']
assert len(analysis)>10
print('PASS actual OpenAI explicit image analysis (test fixture, not a live camera)',flush=True)
facts={'open_hazards':0,'critical_hazards':0,'tasks':0,'completed_tasks':0,'events_today':0,
       'voice_reports':0,'analyzed_frames':0,'recent_events':[],'recent_tasks':[],'period':'empty test database'}
brief=post('/brief',json={'facts':facts}).get_json()['reply']
print('PASS actual OpenAI empty-data brief:',brief,flush=True)
print('All real API smoke checks passed; no app records created.',flush=True)
