# DaystingIRC on iPad

## App access and IRC server accounts

No account is needed to use DaystingIRC. You can connect to any IRC server that supports the app's required TLS connection; you are not limited to `irc.daysting.com`.

Each server owner determines that server's account requirements, account-creation process, and rules. Any SASL or NickServ account belongs to the IRC network, not to DaystingIRC.

`irc.daysting.com` does not require an account to participate. However, registering with its services is strongly recommended to protect your nickname and channel ownership. Registration is optional for participation.

Open `DaystingIRC.xcodeproj` and choose the `DaystingIRC-iOS` scheme. The target supports iPad and iPhone on iOS/iPadOS 16 or later and uses bundle ID `com.daysting.ircclient.ios`. Development signing is configured for team AZ94QYXR6U; version is 1.4, build 1.

## Included

- Dedicated connection form with server presets, favorites, recent servers, profile validation, TLS, optional authentication, status, and cancellation.
- Wide iPad chat with channel users beside the conversation; compact windows use the Users sheet. Pane controls stack in compact widths.
- Theme Controls available before and after connecting, with a Done button, editable preview, and adjustable preview height.
- iPad multitasking enabled by removing the full-screen requirement; portrait and landscape declarations retained.
- Approved colorful icon packaged in every iPad/iPhone size as opaque PNGs. Regenerate with `python3 scripts/create_ios_icon.py` (Pillow required).
- Security-scoped access for imported theme files from Files providers.

## Running on an iPad

Connect and trust the iPad, select it as the Xcode run destination, enable Developer Mode on the device if requested, and press Run. Xcode may need to register the device and create a development provisioning profile. This is a development build, not a TestFlight or App Store release.

## Validation

The simulator Debug build and macOS regression build succeeded. The arm64 device Release build also succeeded with signing disabled. The user confirmed the app works in Simulator and on their connected iPad Pro. After the Windows pane was given a bounded 44-point control-row height, the user confirmed the corrected layout works and looks great.

Before distribution, verify landscape/portrait, narrow multitasking windows, software/hardware keyboards, connecting and cancelling, channel/private chat, user actions, theme preview resizing, and theme import/export on an iPad. IRC connections are not guaranteed to remain active while iPadOS suspends the app in the background.
