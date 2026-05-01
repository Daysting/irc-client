# App Store Deployment Guide (macOS + iOS/iPadOS)

This project is prepared for Apple platform deployment with TLS-only IRC transport and shared SwiftUI code.

## 1. Generate Xcode Project

Use XcodeGen so both Apple targets are present:

```bash
xcodegen generate
open DaystingIRC.xcodeproj
```

Targets generated from `project.yml`:
- `DaystingIRC-macOS`
- `DaystingIRC-iOS` (iPhone + iPad)

## 2. Configure Signing

For each Apple target in Xcode:
- Set your `Team`
- Confirm unique bundle ID
- Enable `Automatically manage signing`

Suggested bundle IDs:
- macOS: `com.daysting.ircclient`
- iOS/iPadOS: `com.daysting.ircclient.ios`

## 3. Verify Security Settings

Current project config enforces:
- TLS-only IRC connection flow in app logic
- ATS default deny (`NSAllowsArbitraryLoads = NO`)

Before release:
- Confirm all server presets and production endpoints use TLS
- Keep port `6697` default for secure IRC

## 4. Build Validation

Recommended local checks:
- Build `DaystingIRC-macOS` in Release
- Build `DaystingIRC-iOS` in Release for both iPhone and iPad simulators/devices
- Test quick connect and custom TLS server connect
- Test operator login flow (`/OPER` automation/manual)
- Test Anope contextual actions
- Test theme font and color customization

## 5. Archive and Upload

For each target:
1. Product -> Archive
2. Validate App
3. Distribute App -> App Store Connect

## 6. App Store Connect Metadata

Prepare:
- Screenshots (macOS, iPhone, iPad)
- Privacy policy URL
- Support URL
- App description and keywords
- Export compliance answers (encryption usage)

## 7. Recommended Final Hardening

- Add reconnect/backoff behavior for unstable networks
- Add robust IRC line parser and flood protection
- Add integration tests for auth and command routing
- Add crash and analytics tooling as needed
