# macOS connection and theme windows

- **File → Connect…** (Shift-Command-K) opens the independent connection window. It also opens on launch when disconnected and after a live connection closes. The chat transcript remains in the main window.
- The Connect window shares the saved identity/authentication profile with the chat. Presets, favorites, recent servers, TLS, validation, connection status, and cancellation remain available. A successful connection brings the chat forward and closes Connect.
- **Theme → Theme Controls** (Option-Command-T) opens the resizable appearance editor. Font and theme-name fields follow the window width. The upper settings panel scrolls; drag the horizontal divider to change the live text preview's height. Preview text is local to the view and is never sent to IRC.
- The dimensional blue-violet macOS icon uses the master artwork in `Resources/IconSource/macOS-master.png`, packaged by `scripts/create_macos_icon.py` (Python + Pillow). This updates the ten macOS asset-catalog sizes, the legacy iconset, and ICNS. The iOS artwork is unchanged.

## Build and run

Run `./script/build_and_run.sh` with Xcode installed. `--build` builds without launching; `--verify` launches and checks the process. The Codex Run action uses the same script.

When an outer execution sandbox prevents Swift's macro subprocess from creating its nested sandbox, use `DAYSTING_SWIFT_FLAGS=-disable-sandbox ./script/build_and_run.sh --build`. This only controls the compiler subprocess sandbox and does not change the application's sandbox entitlements.

## Validation

- Xcode 27 macOS Debug build passed, targeting macOS 13 or newer.
- Launched the built app and verified separate Connect and Theme Controls windows, editable preview text, and native splitter value changes through accessibility.
- No live IRC login or message was sent during UI verification. Saved authentication values were left untouched.
- The app is locally ad-hoc signed; this preview is not a notarized distribution release.
