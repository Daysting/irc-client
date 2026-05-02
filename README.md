# Daysting IRC

A native IRC client for macOS, iOS, iPadOS, tvOS, and Windows.

**Default server:** `irc.daysting.com:6697` · TLS required (minimum TLS 1.2) · Anope services support

---

## Platforms

| Platform | Technology | Minimum OS |
|---|---|---|
| macOS | SwiftUI | macOS 13 |
| iOS / iPadOS | SwiftUI | iOS 16 |
| tvOS | SwiftUI | tvOS 17 |
| Windows | Avalonia (.NET) | Windows 10 |

---

## Getting Started

### macOS

**Requirements:** Xcode 15 or later, macOS 13+

1. Clone the repository.
2. Open the project in Xcode:
   ```bash
   open DaystingIRC.xcodeproj
   ```
3. Select the **DaystingIRC-macOS** scheme and **My Mac** destination.
4. Press **Cmd+R** to build and run.

Alternatively, build from the command line:
```bash
swift build
swift run
```

To regenerate the Xcode project after editing `project.yml`:
```bash
xcodegen generate
```

---

### iOS / iPadOS

**Requirements:** Xcode 15 or later, iOS 16+ device or simulator

1. Open `DaystingIRC.xcodeproj` in Xcode.
2. Select the **DaystingIRC-iOS** scheme.
3. Choose an iOS simulator or a connected device as the destination.
4. Press **Cmd+R** to build and run.

To run on a physical device you will need a development team set in the Signing & Capabilities tab.

---

### tvOS (Apple TV)

**Requirements:** Xcode 15 or later, tvOS 17+ Apple TV or simulator

1. Open `DaystingIRC.xcodeproj` in Xcode.
2. Select the **DaystingIRC-tvOS** scheme.
3. Choose an Apple TV simulator or a connected Apple TV as the destination.
4. Press **Cmd+R** to build and run.

**Remote navigation:**
- Use the Siri Remote (or any MFi gamepad) to navigate between fields and buttons.
- The on-screen keyboard appears automatically when a text field is focused — only if no hardware keyboard is connected.
- Connect a Bluetooth keyboard to type directly without the on-screen keyboard.
- Navigation buttons (Connect, Disconnect, channel tabs) are highlighted when focused so you can see which control is selected.

---

### Windows

**Requirements:** .NET 8 SDK, Windows 10 or later

1. Open a terminal and navigate to the `Windows/DaystingIRC.Windows` directory.
2. Build and run:
   ```powershell
   dotnet run
   ```
3. To build a standalone installer, run:
   ```bash
   ./scripts/build_windows_installer.sh
   ```
   This produces an NSIS installer in `Windows/Installer/`.

---

## Connecting to a Server

All platforms share the same connection flow:

1. **Host** — IRC server hostname (default: `irc.daysting.com`).
2. **Port** — Server port (default: `6697`).
3. **TLS** — Always on; TLS 1.2 minimum is enforced.
4. **Nickname** — Your preferred nick.
5. **Channel** — Primary channel to join on connect (must start with `#`).
6. Press **Connect** (keyboard shortcut: **Cmd+K** on macOS/iOS; select Connect button and press Select/Enter on tvOS).

**Validation:** Fields highlighted in red block connecting. Fields highlighted in orange are warnings only. Tap or hover the warning icon next to a field for guidance and a one-click copy example.

---

## Authentication

### SASL

1. Enable **SASL** in the connection profile.
2. Choose mechanism:
   - **PLAIN** — enter your `SASL Password` (and optionally `SASL User`).
   - **EXTERNAL** — uses your TLS client identity when available.

### NickServ

Set **NickServ Password** to automatically run `/NS IDENTIFY <password>` on connect.

### Delayed channel join

Enable **Delay Join** and set **NickServ Timeout** (seconds). The app waits for NickServ confirmation before joining channels, then falls back to joining after the timeout if no confirmation arrives.

### IRC Operator auto-login

Set **OPER Name** and **OPER Password** to automatically run `/OPER` on connect.

---

## Chatting

- Type a message and press **Return** / **Enter** to send to the active channel or query.
- Prefix with `/` to send raw IRC commands:
  - `/join #channel` — join a channel
  - `/part` — leave the current channel
  - `/whois nick` — look up a user
  - `/me <action>` — send an action message
- **Anope service aliases:**
  - `/ns <cmd>` → NickServ
  - `/cs <cmd>` → ChanServ
  - `/ms <cmd>` → MemoServ
  - `/os <cmd>` → OperServ
  - `/hs <cmd>` → HostServ
  - `/bs <cmd>` → BotServ

---

## Tabs and Panes

The interface uses a tab strip with three pane types:

| Pane | Description |
|---|---|
| **Server** | Raw server messages and connection log |
| **Channel** | Messages for a joined channel |
| **Private** | Direct messages with another user |

- Unread messages show a badge on the tab.
- Private/query tabs can be closed with the **×** button, middle-click, or via **Context Commands**.
- **Close All Private Tabs**, **Close Other Private Tabs**, **Reopen Last Closed Tab**, and a **Recently Closed** history are all available in the Context Commands menu.

---

## User List

The right-side **Users** panel shows channel members with their privilege status:

`~` Owner · `&` Admin · `@` Op · `%` Half-op · `+` Voice · (none) Regular

- **Click** a user to open a private chat tab.
- **Right-click** a user for quick actions: Open Private Chat, WHOIS, Mention, Op, Deop, Voice, Devoice.

---

## Anope Services Menus (macOS / iOS)

Right-click (or long-press on iOS) the active pane to open **Anope Services**. Menus are filtered by pane type. Commands that require parameters show a popup form with a live command preview.

Enable **Advanced** in the popup to include optional parameters and see the exact command that will be sent.

---

## Operator Commands

Operator-only commands are blocked until the server confirms operator status after `/OPER`. Manual `/OPER` is always available in the input field.

---

## Appearance / Themes (macOS / iOS)

Open **Theme > Theme Controls** from the menu bar (or the Theme Controls button on the connect screen) to customize:

- Font family and size
- Text color and background color
- Installed-font override (any system font by name)

**Presets:**
1. Enter a theme name and click **Save Theme**.
2. Select a saved theme and click **Apply Theme** to switch.
3. **Delete Theme** removes a preset (with confirmation).
4. **Reset Theme** restores the built-in defaults.

**Import / Export:**
- **Export Themes** — saves all presets to a JSON file.
- **Import Themes** — loads from a JSON file; choose **Replace Existing Names** or **Keep Both** for conflicts.

---

## Persistence

The app automatically restores between launches:
- Connection profile settings
- Open tabs and selected tab
- Unread counts
- Recently closed private-tab history
- Saved theme presets

---

## Security

- TLS is required for all connections; minimum TLS 1.2.
- SASL PLAIN only runs over TLS.
- Profile data is stored locally in UserDefaults (Apple platforms) / app settings (Windows).
- To enforce TLS 1.3 or add certificate pinning, extend `makeParameters` in `Sources/IRCClient.swift`.

---

## Troubleshooting

| Symptom | Fix |
|---|---|
| Connect button is disabled | Fix red-highlighted fields (empty host, channel missing `#`) |
| Joined channels not appearing | Check **Auto Join Channels** — must be comma-separated, each starting with `#` |
| SASL not working | For PLAIN ensure password is set; for EXTERNAL ensure TLS client identity is configured |
| Operator commands blocked | Server has not yet granted operator status — try `/OPER` manually |
| Theme import fails | Confirm the file is valid JSON containing an array of theme objects |
| tvOS keyboard keeps appearing | Connect a Bluetooth keyboard; the on-screen keyboard will not pop up when a hardware keyboard is connected |

---

## Further Reading

- [docs/USAGE.md](docs/USAGE.md) — detailed feature walkthrough
- [docs/XCODE_DEBUGGING.md](docs/XCODE_DEBUGGING.md) — Xcode run and debug workflow
- [docs/APP_STORE_DEPLOYMENT.md](docs/APP_STORE_DEPLOYMENT.md) — App Store submission steps

