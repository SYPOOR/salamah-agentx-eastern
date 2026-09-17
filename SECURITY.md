# Security

## Credentials

OpenAI and Roboflow provider keys belong only in server-side environment files. Never commit `.env`, filled device configuration, Xcode generated settings, signing material, database exports or build artifacts.

`.env.example` files contain configuration names only. `.env.device.example.json` contains blank gateway settings. Device gateway tokens are credentials too. Do not use a long-lived shared token in a publicly distributed application.

## Reporting an issue

Report suspected vulnerabilities privately to the repository owner through the access channel used for this submission. Do not include live keys, personal information or exploitable credentials in an issue or pull request.

## Deployment

Use HTTPS, controlled gateway access, token rotation and restricted provider credentials. The demonstration gateway applies authentication and request limits, but its in-memory limits are not a multi-instance production design.

The repository excludes local development logs, tunnel results and user-specific Xcode state. If a credential has been exposed elsewhere, rotate it at its provider; removing it from a repository is not revocation.
