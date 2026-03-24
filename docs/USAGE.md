# Daysting IRC Usage Guide

This guide walks through daily use of the app from first launch to advanced features.

## 1) Launch and Connect

1. Build and run:

```bash
swift build
swift run
```

2. The server endpoint is fixed and not editable:
- Host: `irc.daysting.com`
- Port: `6697`
- TLS: enabled

3. Enter your nickname and primary channel (must start with `#`).

4. Click `Connect` (or press `Cmd+K`).

## 2) Required vs Optional Fields

Required to connect:
- `Channel` must start with `#`.

Optional but recommended:
- `Alt Nicks`: fallback nicknames used when your preferred nick is taken.
- `Auto Join Channels`: comma-separated channel list (must each start with `#`).

Validation behavior:
- Red highlight: blocking issue (Connect disabled).
- Orange highlight: warning (Connect still allowed).
- Warning icon: hover for hint, click for popover, and use `Copy` for example values.

## 3) Authentication Options

You can use one or more of these together.

### SASL

1. Toggle `SASL` on.
2. Choose mechanism:
- `PLAIN`: set `SASL Password` (and optional `SASL User`).
- `EXTERNAL`: uses your client TLS identity if available.

### NickServ fallback

1. Set `NickServ Account`.
2. Set `NickServ Password`.

### Delayed join

1. Enable `Delay Join`.
2. Set `NickServ Timeout` seconds.

This waits for NickServ identify success before joining channels; if no success is seen, it joins after timeout.

### OPER automation

1. Set `OPER Name`.
2. Set `OPER Password`.

Both are required for automatic `/OPER`.

## 4) Messaging and Commands

- Normal text sends a message to the active target.
- Slash commands send raw IRC commands, for example:
  - `/join #help`
  - `/whois nick`
- Action command:
  - `/me waves` sends an IRC ACTION message.

Anope aliases:
- `/ms HELP` sends to MemoServ.
- `/os HELP` sends to OperServ.

Shortcut buttons:
- Use `Anope Shortcuts` for common MemoServ and OperServ actions.

## 5) Tabs and Windows

Pane types:
- `Server`
- `Channel`
- `Private`

Behavior:
- Incoming channel/private traffic opens or routes to matching panes.
- Unread counts appear as badges on tabs.
- Private tabs can be closed with:
  - close button
  - middle click
  - context menu bulk actions

Context menu actions include:
- Close all private tabs
- Close other private tabs
- Reopen last closed private tab
- Recently closed private tabs

User list pane:
- The right-side `Users` pane shows users for the active channel.
- In private windows, it shows the peer nickname.
- Click a user to open/select a private conversation tab with that user.
- Right-click a user for quick actions:
  - `Open Private Chat`
  - `WHOIS` (prefills the command in input)
  - `Mention` (prefills `nick: ` in input)

Message display format:
- Standard chat messages are displayed as `<username> message`.
- Action messages display as `* username action`.

## 6) Operator-Aware Commands

The app tracks actual operator login state.

- Operator-only commands stay blocked until the server confirms operator status.
- Manual `/OPER` is still available when not yet operator.

## 7) Appearance Customization

Use `Custom Theme` to control app look.

Controls:
- Font family
- Font size
- Text color
- Background color

Note:
- The `Server` log pane always uses a terminal-style monospaced font for better ASCII art rendering.

Theme presets:
1. Enter a `Theme Name`.
2. Click `Save Theme`.
3. Select from `Saved Themes` and click `Apply Theme`.
4. Use `Delete Theme` to remove (with confirmation).
5. Use `Reset Theme` to restore defaults.

Save behavior:
- Saving with an existing name overwrites that theme.

## 8) Import and Export Themes

Export:
1. Click `Export Themes`.
2. Choose destination JSON file.

Import:
1. Click `Import Themes`.
2. Pick a JSON file.
3. Choose import strategy:
- `Replace Existing Names`: merge by name and overwrite matches.
- `Keep Both`: keep existing themes and add imported copies with unique names.

## 9) Persistence

The app restores these between launches:
- Connection profile settings
- Open panes and selected pane
- Unread counts
- Recently closed private tabs
- Saved theme presets

## 10) Troubleshooting

### Connect button is disabled

Check for red validation errors:
- Empty host
- Primary channel missing `#`

### Joined channels are missing

Check `Auto Join Channels` format:
- Must be comma-separated channel names starting with `#`.

### SASL is enabled but not working

- For `PLAIN`, ensure password is set.
- For `EXTERNAL`, ensure your TLS client identity is configured in your environment.

### Operator commands are blocked

- Confirm server has granted operator status after `/OPER`.

### Theme import says no valid themes

- Verify the file is JSON and contains an array of theme objects.

## 11) Recommended First-Time Setup

1. Set nick/channel.
2. Add one fallback nick.
3. Configure SASL and/or NickServ.
4. Configure OPER if needed.
5. Add auto-join channels.
6. Save your appearance as a named theme.
7. Export themes to keep a backup.

## 12) Xcode Bug Testing

For complete Xcode run/debug instructions, see `docs/XCODE_DEBUGGING.md`.
