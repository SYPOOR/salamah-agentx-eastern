# Roadmap

This roadmap separates implemented capabilities from future work. It is not a delivery-date commitment.

## Implemented

- [x] Live camera stream with throttled, on-device PPE inference.
- [x] Configurable required equipment and confidence threshold.
- [x] Circle and polygon zones on native iOS maps.
- [x] Foreground zone monitoring and approximate AR overlays.
- [x] SQLite event history and record-based dashboard.
- [x] Arabic voice input with live text and manual submission.
- [x] Single-frame visual assistance and spoken replies.
- [x] Local hazard reporting, tasks and guided progress.
- [x] Repository documentation and automated checks.

## Next: field validation

- [ ] Evaluate PPE against a representative, consented worksite dataset.
- [ ] Measure false positives, missed detections and latency by device.
- [ ] Evaluate microphone behavior in industrial background noise.
- [ ] Improve nearby-zone label placement and GPS uncertainty feedback.
- [ ] Document validation evidence for each distributed version.

## Production readiness

- [ ] Managed gateway deployment with device authentication and token rotation.
- [ ] Documented data retention and an operator-specific published privacy policy.
- [ ] Accessibility and long-session battery/thermal testing.
- [ ] Repeatable release checks covering real iPhone camera, audio and AR paths.

## Expansion

- [ ] Android inference and spatial-view validation.
- [ ] Indoor positioning evaluation.
- [ ] Optional organizational reporting backend.
- [ ] Smart-helmet camera, display and positioning adapters.
