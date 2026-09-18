# Contributing

Keep changes focused on the field workflow: observe, assess, warn, record and review.

## Working on a change

1. Open an issue describing the observed problem or proposed outcome. Avoid including credentials, precise worksite coordinates or identifiable incident records.
2. Create a descriptive branch, for example `fix/camera-resume` or `feature/zone-editor`.
3. Make a focused change and update documentation where behavior changes.
4. Run the relevant checks and open a pull request with the problem, resulting behavior and validation evidence.

```sh
flutter analyze
flutter test
python -m unittest discover -s ai_proxy
node --test proxy/test/proxy.test.mjs
```

Install the relevant dependencies before running these commands. Python gateway tests do not require a live provider key.

## Review expectations

Business rules belong in services or domain code rather than widgets. Persist an event before claiming it was saved. Preserve cancellation and camera lifecycle behavior. Clearly separate unknown observations from passing checks. Never use generated values to populate measured dashboard statistics.

Camera, microphone, Core ML and AR changes need physical-device validation in addition to automated tests. Record the device model, OS version and test outcome, without publishing device identifiers or private images.

## Secrets and model changes

Use local ignored configuration files and blank examples. Do not attach database dumps, build artifacts, provider keys or gateway tokens. Model changes must document provenance, conversion settings, limitations and applicable licenses.

## Commits

Write short, concrete commit subjects describing the change. Keep changes reviewable and link an issue when one exists.
