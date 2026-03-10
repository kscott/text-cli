# sms-cli

Swift CLI for sending iMessages and SMS via Messages.app.

## Build & run

```bash
sms setup   # build release binary and install to ~/bin
sms test    # build and run test suite
```

## Project structure

- `Sources/MessagesLib/PhoneNormalizer.swift` — pure phone normalization and contact resolution
- `Sources/MessagesCLI/main.swift` — CLI entry point: AppleScript send, CNContactStore
- `Tests/MessagesLibTests/main.swift` — custom test runner (no Xcode/XCTest required)
- `sms` — bash wrapper script, symlinked into `~/bin`

See [DEVELOPMENT.md](DEVELOPMENT.md) for coding conventions and patterns.

## Commands

```
sms send <contact> <message...>     # Send an iMessage or SMS
sms open [contact]                  # Open Messages.app
```

## Key decisions

- **Send only** — iMessage has no public read API; chat.db requires Full Disk Access and an undocumented schema — not the right tradeoff for a fire-and-forget tool
- **AppleScript for send** — no public Swift framework for sending iMessages; osascript via Messages.app is the standard approach and fast for a single message
- **MessagesLib separated from MessagesCLI** — phone normalization and matching are testable without permissions
- **Custom test runner** — works with CLT only, no full Xcode needed

## Permissions

- Contacts access — prompted at first run (CNContactStore)

## Adding a new command

1. Add the case to the `switch cmd` block in `main.swift`
2. Add it to `usage()`
3. Add it to the command table in `README.md` and `CLAUDE.md`
4. If the command introduces new matching logic, add it to `MessagesLib` with tests
