# Motion Storyline — Build & Distribution

Two practical paths to ship the macOS app from your website. Pick the one that matches your current setup.

## Without Apple Developer Account (unsigned/dev-signed)

- Outcome: DMG that users can download and run after a one-time Gatekeeper bypass. The DMG includes “First Run Guide.txt” with clear steps.
- When to use: You don’t have Developer ID yet, or you’re testing internally.

Build
```bash
# From project root
ALLOW_UNSIGNED_FALLBACK=1 bash Scripts/create_dmg.sh
```

What users will see
- macOS may warn that the app is from an unidentified developer.
- They can Right‑click → Open once, or use System Settings → Privacy & Security → Open Anyway.
- The DMG shows “First Run Guide.txt” with exact steps and explanation.

Tips
- Keep the bundle identifier consistent between builds to minimize repeated permission prompts.
- Optional: self‑sign with a local certificate for a stable code identity (Gatekeeper bypass still required).

Artifacts
- DMG: `dist/Motion Storyline.dmg`
- App in DMG staging: `dist/dmg/Motion Storyline.app`
- Guide included: `Docs/First-Run-Guide.txt`

## With Apple Developer Account (Developer ID + Notarization)

- Outcome: Users download and open the app normally without warnings.
- Prereqs: Developer ID Application cert, Team ID, Apple ID with app‑specific password.

Export with Developer ID
```bash
# Option A: set your team ID
export DEVELOPMENT_TEAM=YOUR_TEAM_ID

# Build DMG (script enforces Developer ID, no unsigned fallback unless you set ALLOW_UNSIGNED_FALLBACK)
bash Scripts/create_dmg.sh
```

Notarize and staple
```bash
export APPLE_ID="you@example.com"
export APP_PASSWORD="app-specific-password"   # from appleid.apple.com
export TEAM_ID="YOUR_TEAM_ID"
bash Scripts/notarize.sh
```

Verify
```bash
# Signature
codesign -dv --verbose=4 dist/export/"Motion Storyline.app"

# Gatekeeper (after notarization/stapling)
spctl -a -vvv --type exec dist/export/"Motion Storyline.app"
xcrun stapler validate dist/"Motion Storyline.dmg"
```

Notes
- The `create_dmg.sh` script auto-detects Team ID from the archive; you can also provide `DEVELOPMENT_TEAM`.
- If export fails, the script stops by default (to avoid shipping unsigned builds). Use `ALLOW_UNSIGNED_FALLBACK=1` only when you accept the Gatekeeper flow.

Essential Files
- `Scripts/create_dmg.sh` — Build and DMG packaging
- `Scripts/notarize.sh` — Apple notarization + stapling
- `Docs/First-Run-Guide.txt` — End‑user instructions for unsigned builds

Security
- Do not commit APP_PASSWORD, private keys, or signing profiles.
