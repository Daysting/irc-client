# Windows Client

This repository now includes a Windows-capable desktop client at `Windows/DaystingIRC.Windows`.

## Stack

- UI: Avalonia
- Runtime: .NET 7
- Transport: `TcpClient` + `SslStream`

## Current behavior

The Windows app includes these core workflows from the macOS client:

- locked connection target: `irc.daysting.com:6697`
- TLS-only connection flow
- alternate nickname fallback on `433`
- IRCv3 CAP + SASL (`PLAIN` and `EXTERNAL` negotiation)
- automatic NickServ identify
- optional delayed channel join until NickServ identify or timeout
- automatic `/OPER` login
- auto-join channel list
- server, channel, and private conversation tabs
- unread counts on inactive tabs
- channel topic display
- channel user list from `NAMES`, `JOIN`, `PART`, `QUIT`, `NICK`, and basic prefix mode updates
- slash command passthrough, `/me`, `/query`, `/close`, and Anope aliases (`/ns`, `/cs`, `/ms`, `/os`, `/hs`, `/bs`)
- profile and open-tab persistence in AppData

## Build

From the repository root:

```bash
cd Windows/DaystingIRC.Windows
dotnet build
```

Run locally:

```bash
dotnet run
```

## Installer wizard

This repository includes an NSIS-based installer definition at `Windows/Installer/DaystingIRC.Windows.nsi`.

Build the Windows setup wizard from the repository root:

```bash
./scripts/build_windows_installer.sh
```

That script:

- publishes the app for `win-x64`
- produces a self-contained single-file executable
- compiles an NSIS setup wizard
- writes the installer to `dist/windows/DaystingIRC-Windows-Setup-<version>.exe`

The installer:

- installs into `Program Files\Daysting IRC`
- creates Start Menu and desktop shortcuts
- registers an uninstaller with Windows

## Persistence

The Windows client stores its local state in:

- `%AppData%/DaystingIRC.Windows/profile.json`
- `%AppData%/DaystingIRC.Windows/session.json`

## Notes

- The Windows client is a desktop port, not a pixel-for-pixel clone of the SwiftUI app.
- Theme preset management and the large contextual command catalog from the macOS build have not been ported yet.
- The project builds cleanly with `dotnet build` in this repository.