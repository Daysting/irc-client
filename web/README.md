# DaystingIRC Web

Browser client for DaystingIRC, with channel/private chat, user actions, raw IRC commands, connection feedback, light/dark themes, adjustable text, and the native app's 109-action Anope catalog.

## Live connection requirement

The front end is static. A browser cannot connect directly to IRC's TLS port. Point it at an IRC WebSocket server or the included relay. **irc.daysting.com does not yet have a WebSocket endpoint. Live chat with it will not work until the relay is deployed.** Offline preview is explicitly labeled and sends nothing.

The included relay connects only to the operator-configured host/port (default irc.daysting.com:6697), verifies its TLS certificate, and accepts only configured website origins. Browser input cannot select arbitrary upstream destinations. Do not disable certificate verification. The relay operator can see IRC traffic, just like other IRC gateways. The IRC server sees the relay's IP; configure server connection limits accordingly. Origin checks limit browser use but are not authentication against non-browser clients. Add edge abuse controls before broad public rollout.

## Install the relay on your server

Node.js 22+, pnpm, and a TLS reverse proxy are required. Copy the `web/` directory to `/opt/daysting-irc-web`, install locked dependencies with `pnpm install --frozen-lockfile --prod`, and create a dedicated unprivileged `daysting-relay` system account.

Create `/etc/daysting-irc-relay.env`:

```
IRC_HOST=irc.daysting.com
IRC_PORT=6697
BIND_HOST=127.0.0.1
PORT=8787
ALLOWED_ORIGINS=https://daysting.github.io
```

For a self-hosted frontend, replace ALLOWED_ORIGINS with its exact HTTPS origin (comma separated for multiple). Install the supplied systemd unit, then start it with `systemctl enable --now daysting-irc-relay`. Configure Caddy using `relay/Caddyfile.example`, with a real DNS name pointed at your server. Caddy must be installed and able to obtain a certificate. Expose HTTPS 443, not the loopback relay port. Use `wss://YOUR-RELAY-DOMAIN/irc` in the client. No server credentials are included or required for guest chat.

You may instead use the IRC daemon's native secure WebSocket listener. Supported frame format: text IRC lines; subprotocol text.ircv3.net or irc. See https://www.unrealircd.org/docs/WebSocket_support .

## Frontend and tests

Serve `dist/` from an HTTPS static server. The Sites deployment is owner-private by default. It is separate from the relay; Sites does not run the Node TCP relay.

```
pnpm install --frozen-lockfile
pnpm test
python3 -m http.server 8080 --directory dist --bind 127.0.0.1
```

No app account is required by the client. A private preview host may require its owner's sign-in. IRC server account rules are determined by each server owner. irc.daysting.com allows guest participation; registration is recommended for nickname/channel ownership protection.

Messages stay in tab memory (500 per conversation). Passwords are not persisted. Endpoint, nickname, channel, network label and appearance use localStorage. TLS traffic passes through the selected endpoint. NickServ authentication is available through Services after connecting; this first web version does not implement SASL, DCC, file transfers or background persistence. Closing the tab disconnects. Reloading loses transcript history.

Support: daysting@daysting.com · 763-334-6555 (business).

## GitHub Pages

The web client is published from `main` → `/docs`. Enable this in Settings → Pages → Deploy from a branch. The expected URL is https://daysting.github.io/irc-client/ . The Node relay cannot run on GitHub Pages.

Edit the client in `web/dist/`, then run `python3 web/sync-pages.py` from the repository root and commit the resulting docs assets together. Do not edit the generated docs files separately. This leaves the existing native-app guides intact. Pages redeploys when these files are pushed.
