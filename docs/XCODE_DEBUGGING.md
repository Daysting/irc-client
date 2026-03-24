# Xcode Bug-Testing Guide

This project is already an executable macOS SwiftUI app and can run directly in Xcode from the Swift Package.

## 1) Open in Xcode

Option A:

```bash
open Package.swift
```

Option B (generated Xcode project):

```bash
open DaystingIRC.xcodeproj
```

Option C:

```bash
./scripts/open_in_xcode.sh
```

## 2) Select the Correct Run Target

1. In Xcode, choose the scheme `DaystingIRC`.
2. Choose destination `My Mac`.
3. Build and run with `Cmd+R`.

If the scheme is missing:
1. Product > Scheme > Manage Schemes...
2. Confirm `DaystingIRC` exists and is checked.

## 3) Debug Workflow (for bug testing)

1. Set breakpoints in files like:
- `Sources/IRCClient.swift` for protocol/network flow
- `Sources/IRCViewModel.swift` for app state and routing
- `Sources/ContentView.swift` for UI behavior

2. Run with `Cmd+R`.
3. When a breakpoint hits, inspect:
- Variables view
- LLDB console
- Call stack

Useful LLDB commands:

```lldb
po line
po config
po activeWindow
```

## 4) Recommended Breakpoint Locations

- `IRCClient.handleProtocolLine(...)` to inspect incoming server lines
- `IRCViewModel.handleIncomingLine(...)` to inspect pane routing
- `IRCViewModel.executeContextCommand(...)` for command execution/gating
- `IRCViewModel.importThemesData(...)` for theme import behavior

## 5) Diagnostics in Xcode

Use the Debug area tabs:
- CPU and memory gauges
- Network activity
- Console logs

For UI/state bugs, keep the app running and interact with:
- Connection/auth fields
- Tabs and context commands
- Theme save/import/export actions

## 6) Clean Repro Between Runs

If you need a clean state during bug testing:

1. Use in-app reset controls where available:
- `Reset Theme`
- clear profile fields you want to re-test

2. Disconnect and reconnect to restart IRC session flows.

3. If needed, clean Xcode artifacts:
- Product > Clean Build Folder
- quit and reopen Xcode

## 7) Build/Test from Terminal (optional)

```bash
swift build
```

This is useful for quick compile validation before launching Xcode.

## 8) Common Issues

### App does not launch

- Confirm destination is `My Mac`.
- Confirm scheme is `DaystingIRC`.
- Reopen package with `open Package.swift`.

### Breakpoints not hit

- Verify breakpoint is solid blue (enabled).
- Ensure you are running Debug configuration.
- Clean build folder: Product > Clean Build Folder.

### Scheme disappeared after reopening

- Reopen package with `open Package.swift`.
- Re-enable shared scheme in Manage Schemes.
