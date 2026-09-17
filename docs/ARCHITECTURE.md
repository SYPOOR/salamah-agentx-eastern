# Architecture

SafetyLens separates sensing, domain decisions, persistence and presentation. Riverpod exposes app state to Flutter screens. SQLite is the source of truth for saved zones, events, settings and tasks.

## Local PPE

```mermaid
flowchart LR
  Camera[Live BGRA camera stream] --> Gate[500 ms single-flight gate]
  Gate --> Native[Apple Vision and Core ML]
  Native --> PPE[PPE rules]
  PPE --> Risk[Risk engine]
  Risk --> Events[Event persistence]
  Events --> Dashboard[Dashboard queries]
```

The frame gate drops excess frames. Native inference runs off the UI thread. No still-picture loop or JPEG upload is needed for continuous PPE checks. A supported, assessable single-worker result is required to calculate compliance; no-person and multi-person scenes do not produce a fabricated pass.

Required PPE is configurable. Detection labels are normalized before assessment. Missing-equipment observations must persist before an event is created; debouncing prevents one continuous observation from flooding history. Optional event snapshots are a separate operation.

## Spatial awareness

Apple Maps provides native map interaction. Circle and polygon geometry is saved locally. Zone logic evaluates location against boundaries independently from rendering. GPS accuracy and reading age affect confidence in transitions.

ARKit renders nearby zone indicators using device tracking with geographic and heading estimates. It is an approximate spatial aid, not surveyed positioning or ARGeoTracking. Monitoring runs while the app is in the foreground.

## Assistant

The device Speech framework supplies partial Arabic transcription. A manual Stop submits text to the assistant flow. Clear visual requests or supported camera intents capture a single frame; negated camera commands are rejected. The gateway owns provider credentials and calls OpenAI for intent, image interpretation, optional briefs and synthesized speech.

Assistant image interpretation is distinct from local PPE inference. It does not overwrite model compliance results. The app stores confirmed reports and responses locally; no supervisor notification is implied by saving a hazard.

## Persistence and analytics

`SafetyRepository` stores core safety data. `LeadershipRepository` adds voice history, tasks, mission progress and cached briefs. Events are persisted before optional haptic, sound or notification feedback. A feedback failure must not discard the record.

Dashboard statistics come from stored event queries. Historical aggregates and current sensor risk represent different time scopes. Risk weights are MVP heuristics, not a validated industrial standard. Empty history is represented as missing measurements.

## Lifecycle

Camera and location resources are released when leaving the active view or entering the background. Generation checks prevent stale asynchronous results from updating a cancelled action. Cloud errors surface to the worker without synthesizing a successful result.

## Deployment boundaries

The iPhone runs PPE, spatial calculations and persistence. The optional gateway handles provider calls. The earlier `proxy/` Roboflow implementation is retained for reference but is not part of the current on-device scan path. A future helmet client can reuse domain decisions while replacing camera, display and positioning adapters.
