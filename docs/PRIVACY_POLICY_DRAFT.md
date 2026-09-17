# Privacy policy — publication draft

This draft must be completed by the publisher with its legal name, contact address, public URL, effective date, provider contracts and actual retention settings before publication.

SafetyLens AI uses the device camera for single-worker PPE checks and safety camera overlays. PPE processes selected raw BGRA video frames locally using Core ML and Apple Vision. PPE inference does not send camera frames to Roboflow or any server. Continuous scanning does not create image files or repeatedly encode JPEG.

The optional Voice Commands page starts a local camera preview. Speech input begins only after the microphone button is pressed. Apple's speech recognition supplies live text, attempting on-device recognition and potentially using Apple's online service when unavailable. The active mobile flow does not create a recording file or send audio to OpenAI for transcription. Pressing Stop submits the recognized text through the configured gateway for command processing. A clear visual request sends one camera frame for OpenAI image interpretation. This is separate from local PPE. Replies are sent for AI-generated speech. The proxy does not persist request audio, images or transcripts or log request bodies. Provider-side retention depends on the applicable account settings; store=false alone does not assert zero retention.

Voice transcripts, replies, analyzed-frame text, tasks, mission progress and cached briefs are stored in local SQLite. Leadership brief generation sends a bounded snapshot of recorded event summaries, task data and database counts to OpenAI. It is explicitly initiated with Refresh. The demo gateway uses an authenticated HTTPS Cloudflare tunnel to a proxy on the developer's Mac; a production deployment must establish the actual hosting, subprocessors and retention policy. The OpenAI API key is never embedded in the Flutter application.

Precise location and compass readings are used while the app is active for approximate zone monitoring. Coordinates may be attached to local safety events. Location is not sent to the inference API. Online map tile requests disclose the viewer's IP address and requested map area to the tile provider.

The application stores safety zones, settings and events in a local SQLite database. Optional event images are stored in the app's local support directory; snapshots default to off. Device-level backups may include app data depending on operating-system settings. Access tokens are stored using the platform's secure storage. No account, employee profile, face recognition or advertising SDK is implemented.

Users may disable event snapshots, alert sounds and vibration in Settings. Event history and saved snapshots can be deleted in Settings. Deleting a zone removes that zone from monitoring; historical events may still reference its ID. Device camera/location permissions can be revoked in system Settings.

The publisher must describe how to contact it for privacy requests, whether the application is distributed to children, applicable user rights, any off-device retention, international processing and subprocessors based on the actual deployment. These details are not established by this source-code MVP.
