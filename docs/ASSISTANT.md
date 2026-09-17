# Voice assistant setup

The assistant adds live speech input, one-frame visual analysis, text and spoken replies, hazard reports and record-based briefs. It is optional: local PPE, zones and SQLite records operate independently.

## Gateway

```sh
cd ai_proxy
python3 -m venv .venv
.venv/bin/pip install -r requirements.txt
cp .env.example .env
chmod 600 .env
```

Set `OPENAI_API_KEY` and a strong, randomly generated `SAFETYLENS_PROXY_TOKEN` in the local `.env`. Choose a model available to your API account through `OPENAI_MODEL`. The current configured default is `gpt-5.6-sol`; speech generation uses `gpt-4o-mini-tts` and the `onyx` voice.

```sh
.venv/bin/python app.py
```

The gateway listens on `127.0.0.1:8788`. Expose it through an authenticated HTTPS deployment. For a temporary development session, a tunnel can be used:

```sh
cloudflared tunnel --url http://127.0.0.1:8788 --no-autoupdate
```

A temporary tunnel requires the host and both processes to remain running. Do not treat it as permanent hosting.

## Connect the app

Open Voice Commands → connection settings. Enter the HTTPS gateway URL and its device token. **Do not enter the OpenAI API key.** The app stores these settings using secure storage.

For a local demonstration build only, copy `.env.device.example.json` to `.env.device.json`, fill its gateway URL/token and run:

```sh
flutter build ios --release --dart-define-from-file=.env.device.json
```

The filled file is ignored by Git. A token compiled into a mobile binary can be extracted; production distribution requires appropriate device authentication, token rotation and a managed gateway.

## Interaction

1. Opening Voice Commands starts a local camera preview.
2. Press the microphone and allow Microphone and Speech Recognition permissions.
3. Speak in Arabic. Partial transcription appears while speaking.
4. Press Stop to submit. Application silence detection does not submit the command.
5. For a visual request, one fresh frame is encoded in memory and sent for analysis. Responses appear as text and generated speech.

Example requests: `ماذا أمامي؟`, `وش تشوف قدامي؟`, `صف المشهد`, `التقط صورة`, `يوجد خطر هنا، سجله`.

Apple speech recognition attempts on-device recognition; a fallback may use Apple's online service when local recognition is unavailable. The active mobile flow does not create an audio recording file or upload audio to the gateway's transcription route. That route remains available for development smoke tests.

Hazard reports are saved in a SQLite transaction before confirmation. The dashboard uses database counts; optional brief generation summarizes an explicitly requested snapshot of those records. It does not populate KPI cards with generated numbers.

## Check the gateway

```sh
cd ai_proxy
.venv/bin/python -m unittest discover
```

`smoke_test.py` makes real, billable provider requests using local credentials. A generated-audio smoke test does not validate the physical iPhone microphone.
