# Daysting IRC (macOS)

A native SwiftUI macOS IRC client starter configured for:

- Server: `irc.daysting.com`
- Port: `6697`
- TLS: enabled by default (minimum TLS 1.2)
- Anope shortcuts: MemoServ and OperServ commands

This client is locked to `irc.daysting.com:6697` with TLS enabled.

## Full Usage Guide

For complete step-by-step instructions, see `docs/USAGE.md`.

For Xcode launch and bug-testing workflow, see `docs/XCODE_DEBUGGING.md`.

## Features

- TLS connection via Apple Network framework (`NWConnection`)
- Basic IRC registration (`NICK`, `USER`) and channel auto-join
- IRCv3 CAP + SASL authentication (`PLAIN` and `EXTERNAL`)
- Optional NickServ fallback identify (`PRIVMSG NickServ :IDENTIFY ...`)
- Optional delayed channel join until NickServ identify confirmation
- Tabbed pane windows for `Server`, `Channel`, and `Private` conversations
- Contextual IRC command menus tied to the active pane type
- Right-side user list pane for active conversation context
- Clickable user list entries with quick actions (open private chat, WHOIS, mention)
- User list includes channel privilege status (owner/admin/op/half-op/voice/user)
- Contextual Anope Services menus by window type with popup input forms when parameters are required
- Operator command set that is blocked unless the session is logged in as server operator
- Unread message badges on pane tabs
- Close buttons for private/query tabs
- Middle-click close for private/query tabs
- "Close All Private Tabs" action in contextual command menu
- "Close Other Private Tabs" action in contextual command menu
- "Reopen Last Closed Private Tab" action in contextual command menu
- "Recently Closed Private Tabs" submenu for reopening a specific private tab
- Recently closed private-tab history persists across app restarts
- Pane session persists across app restarts (open tabs, selected tab, unread badges)
- Connection profile persists across app restarts (host, nick, channel, TLS/SASL/auth settings)
- Alternate nickname fallback when preferred nick is in use
- Automatic `/OPER` login from saved profile credentials
- Automatic `/NS IDENTIFY <password>` at connect when NickServ password is provided
- Automatic channel auto-join from saved channel list
- Inline profile validation hints for common configuration mistakes
- Field-level visual highlighting for invalid/incomplete profile inputs
- Inline hover tooltips and click popovers next to highlighted fields with field-specific fix guidance and fix examples
- One-click copy button in each validation popover example
- Customizable app appearance: global font family, font size, text color, and background color
- Server pane uses a terminal-style monospaced log font suitable for ASCII art
- Named theme presets: save, apply, delete, and reset appearance
- Theme preset import/export as JSON files
- Theme delete confirmation and import conflict strategy selection (Replace Existing Names or Keep Both)
- Theme controls are in a separate window opened from menu bar: `Theme > Theme Controls`
- PING/PONG keepalive handling
- Slash command support
- `/me` action command support
- Chat message rendering in readable format: `<username> message`
- Anope aliases:
  - `/ns <command>` -> `PRIVMSG NickServ :<command>`
  - `/cs <command>` -> `PRIVMSG ChanServ :<command>`
  - `/ms <command>` -> `PRIVMSG MemoServ :<command>`
  - `/os <command>` -> `PRIVMSG OperServ :<command>`
  - `/hs <command>` -> `PRIVMSG HostServ :<command>`
  - `/bs <command>` -> `PRIVMSG BotServ :<command>`

## Build and run

```bash
swift build
swift run
```

If you want to open this as an Xcode project:

```bash
open Package.swift
```

An explicit Xcode project is also included:

```bash
open DaystingIRC.xcodeproj
```

Or use the helper script:

```bash
./scripts/open_in_xcode.sh
```

## Usage

1. Launch app.
2. Server is fixed to `irc.daysting.com:6697` with TLS enabled (not editable).
3. Set nickname and channel.
4. Optional profile automation:
  - `Alt Nicks`: comma-separated fallbacks used when nickname is already in use.
  - `Auto Join Channels`: comma-separated channels to join/open after login.
  - `NickServ Password`: runs `/NS IDENTIFY <password>` at login.
  - `OPER Name` + `OPER Password`: runs `/OPER` at login.
5. Optional secure auth:
  - Enable `SASL` and choose mechanism:
    - `PLAIN`: fill `SASL Password` (plus optional `SASL User`).
    - `EXTERNAL`: uses your TLS client identity (if configured on your system/network).
  - Add `NickServ Password` if you want fallback identify behavior.
  - Optional: enable `Delay Join` to wait for NickServ identify success before joining channels.
  - If SASL is enabled but unavailable, the app continues and can still use NickServ.
6. Press Connect (`Cmd+K`).
  - Connect is disabled for critical profile errors (for example empty host or invalid primary channel format).
7. Send normal messages or IRC raw commands:
   - Normal text sends to your current channel.
  - Prefix with `/` for raw command passthrough (supports full IRC command usage, e.g. `/join #support`).
  - Use `/me <action>` for action messages.
  - Use Anope aliases like `/ns HELP`, `/cs HELP`, `/ms HELP`, `/os HELP`, `/hs HELP`, `/bs HELP`.
8. Use the `Windows` tab strip to switch between server, channel, and private panes.
9. The right-side `Users` pane shows users in the active channel.
10. Click a user to open a private chat tab immediately.
11. Right-click a user for quick actions: `Open Private Chat`, `WHOIS`, and `Mention`.
12. Open `Context Commands` from the active pane for command shortcuts relevant to that pane type.
13. Use `Anope Services` in contextual menus for service commands by service type.
14. If a service command needs parameters (for example NickServ Register), a popup form collects input and runs the command.
15. In the popup, enable `Advanced` to show a live command preview and include optional parameters only when filled.
16. Private/query tabs can be closed with the `x` button on the tab.
17. Private/query tabs can also be closed with middle-click on the tab.
18. Use `Close All Private Tabs` from `Context Commands` to clean up query tabs quickly.
19. Use `Close Other Private Tabs` to keep only the current private tab.
20. Use `Reopen Last Closed Private Tab` to restore the last query tab you closed.
21. Use `Recently Closed Private Tabs` to reopen a specific query tab from history.
22. Operator commands are enabled only after the server reports operator status (for example after successful `/OPER`).
23. Recently closed private-tab history is restored when the app starts.
24. Open pane layout, selected pane, and unread counts are restored when the app starts.
25. Connection profile settings are restored when the app starts.
26. Invalid fields are highlighted in red (blocking) or orange (warning) directly in the connection form.
27. Hover the warning icon next to a highlighted field to preview remediation guidance.
27. Click the warning icon to open a popover with the same guidance text.
28. Each popover includes a "Fix example" value pattern for quick correction.
29. Use the popover `Copy` button to copy the example pattern to your clipboard.
30. Open `Theme > Theme Controls` from the menu bar to manage all appearance options.
31. Optional: enable `Custom Theme` to personalize font family, font size, text color, and app background color.
32. Enter a theme name and click `Save Theme` to store your current appearance settings.
33. Saving with an existing theme name overwrites that theme.
34. Use `Saved Themes` + `Apply Theme` to switch presets.
35. Use `Delete Theme` to remove a preset and `Reset Theme` to restore defaults.
36. `Delete Theme` asks for confirmation before removing the preset.
37. Use `Export Themes` to write your presets to a JSON file.
38. `Import Themes` lets you choose conflict handling: `Replace Existing Names` or `Keep Both`.

## Security notes

- TLS transport is enabled by default and uses platform certificate validation.
- Minimum TLS version is set to TLS 1.2.
- For stricter policy (for example TLS 1.3 only or certificate pinning), extend `makeParameters` in `Sources/IRCClient.swift`.
- SASL PLAIN requires TLS, and this client defaults to TLS on port 6697.
- If `Delay Join` is enabled and NickServ confirmation is not seen, the app falls back to join after timeout.
- Saved profile values are stored locally in UserDefaults on your Mac.

## Next improvements

- Better IRC parser (prefix/command/params/tags)
- Channel list and private message tabs
- Persisted profiles and auto-reconnect
