# Apple TV beta

## App access and IRC server accounts

No account is needed to use DaystingIRC. You can connect to any IRC server that supports the app's required TLS connection; you are not limited to `irc.daysting.com`.

Each server owner determines that server's account requirements, account-creation process, and rules. Any SASL or NickServ account belongs to the IRC network, not to DaystingIRC.

`irc.daysting.com` does not require an account to participate. However, registering with its services is strongly recommended to protect your nickname and channel ownership. Registration is optional for participation.

The tvOS 17+ app uses the same IRC client, session model, and Anope action catalog as the shipping Mac and iPhone/iPad apps. Version 1.0 (1) is available through TestFlight for internal testing; it is not an App Store release.

## Build and run

Open `DaystingIRC-tvOS.xcodeproj` and select the shared `DaystingIRC-tvOS` scheme. Choose an Apple TV Simulator or a paired physical Apple TV, then Run. Automatic signing uses the existing development team; a physical device requires a registered Apple TV for development provisioning. The tvOS target now shares `com.daysting.ircclient.ios` with the iPhone/iPad App Store Connect record. Release archives use the `DaystingIRC tvOS App Store` distribution profile; Debug keeps automatic development signing.

The standalone project avoids regenerating the shipping project and its signing settings. Recreate only this TV project with `python3 scripts/generate_tvos_project.py` if its file list or build settings need to change. Swift source is shared from `Sources`.

## Chatting on Apple TV

**Chatting with the remote:**

1. Highlight **Message or /command**.
2. Press **Enter** to activate text entry.
3. Type your message or IRC command.
4. Press **Enter** again to send it.

This sequence is required when using the remote to type; highlighting the field alone does not start text entry.

## Current experience

- Connect to Daysting or another TLS IRC server; optional SASL, NickServ and OPER credentials.
- Select Server, channel, or private-message windows; unread counts and channel topic.
- Read chat, pause automatic scrolling, and choose a persistent TV text size.
- Native text entry supports remote input and a paired Bluetooth keyboard. The message field submits through Return; a visible Send button is also available.
- Select Actions to browse NickServ, ChanServ, MemoServ, OperServ, HostServ and BotServ commands. Long-press a window for the Anope shortcut.
- Select Users, then a nickname, for private messaging, WHOIS preparation, or Anope actions.
- Forms prefill the selected channel/nickname, mask secure values in previews, reject multiline/NUL input, and require an explicit Run Command action. The captured context stays with the form rather than following later selection changes.
- The IRC network remains responsible for permission checks. Guests can inspect responses in Server; changing server state requires the relevant IRC or NickServ/OperServ permissions.

## Validation

Simulator Debug and unsigned tvOS device Release builds passed during initial implementation. Command rendering tests cover every catalog action, required/optional values, secret masking, line-break rejection and literal placeholder input.

Run the command tests with:

```sh
swiftc -module-cache-path /private/tmp/daysting-swift-cache Sources/IRCModels.swift tests/AnopeCommandTests.swift -o /private/tmp/daysting-anope-tests
/private/tmp/daysting-anope-tests
```

## Physical Apple TV checklist

1. Connect to irc.daysting.com without credentials; verify Server responses, #general and disconnection/reconnection. For other servers, follow their account requirements.
2. Reach every control with Siri Remote. Test long-press, Back, list scrolling and focus restoration after forms.
3. Pair a Bluetooth keyboard in Apple TV Settings. Test message editing, Return, arrow navigation and switching between message entry and menus. Confirm a command sends once per submission.
4. Open user actions, confirm channel/nickname defaults, send a harmless help/info command and find its reply. Test NickServ identification on a dedicated test account without exposing its password in previews.
5. Pause chat scrolling and confirm incoming traffic does not move the reading position. Check readability on a real television.
6. Disconnect while a command form is open; Run must be disabled.

The tester reported that everything works in the TestFlight build and confirmed the remote text-entry sequence above. The checklist remains available for regression testing; the agent has not independently verified hardware behavior.

## Remaining release work

Runtime testing and layout polish, broader theme parity, DCC/file UI decisions, and App Store metadata/screenshots remain. The first TV build exposes Anope commands and ordinary chat; it does not yet duplicate every Mac control. No cross-device credential or preference synchronization was added. The tvOS platform is attached to the existing iPhone/iPad App Store Connect record for universal distribution. The existing macOS listing remains separate. TV icon and Top Shelf assets are packaged in `Resources/TVAssets.xcassets`; regenerate their required sizes with `python3 scripts/create_tvos_assets.py`.
